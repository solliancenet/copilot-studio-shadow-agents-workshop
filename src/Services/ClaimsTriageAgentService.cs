using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Azure.Core;
using Azure.Identity;

namespace MeridianMutual.Services;

/// <summary>
/// Binds the Foundry connection settings (project endpoint + agent name) from configuration.
/// Everything here comes from appsettings/env — there are no secrets, the app authenticates to
/// Foundry with its managed identity via <see cref="DefaultAzureCredential"/>.
/// </summary>
public class ClaimsTriageAgentOptions
{
    public const string SectionName = "Foundry";

    /// <summary>
    /// The Foundry project endpoint, e.g.
    /// <c>https://aif-xxxx.services.ai.azure.com/api/projects/proj-xxxx</c>.
    /// </summary>
    public string ProjectEndpoint { get; set; } = "";

    /// <summary>The new-API prompt agent to invoke, e.g. <c>Claims-Triage</c>.</summary>
    public string AgentName { get; set; } = "Claims-Triage";

    /// <summary>
    /// Data-plane token scope for the Foundry OpenAI-compatible endpoint. Matches the scope the
    /// azure-ai-projects SDK uses for <c>get_openai_client()</c>.
    /// </summary>
    public string TokenScope { get; set; } = "https://ai.azure.com/.default";

    public bool IsConfigured => !string.IsNullOrWhiteSpace(ProjectEndpoint);
}

/// <summary>
/// One readable step in the agent's audit trail: what it did, in plain language, plus the raw
/// tool/endpoint or document reference behind it. Ordered as the agent performed them.
/// </summary>
public record TriageTraceStep(
    string Kind,          // "api" (OpenAPI/tool call) | "search" (file-search grounding) | "other"
    string Title,         // plain-language action, e.g. "Looked up policy MM-AUTO-004417"
    string? Detail,       // what it fetched, e.g. "coverage limits & deductibles"
    string? Reference,    // raw endpoint operationId or "doc.md §3.2" for the mono/citation line
    string? Status);

/// <summary>The rendered result of a triage briefing run.</summary>
public record TriageBriefing(
    string Markdown,
    IReadOnlyList<TriageTraceStep> Steps,
    int CitationCount);

/// <summary>
/// Calls the Foundry "Claims-Triage" prompt agent through the Responses API, referencing the agent
/// by name (<c>agent_reference</c>). This is the .NET equivalent of the working Python kit in
/// <c>foundry/create_new_agent.py</c>:
/// <code>
/// openai.responses.create(input=..., extra_body={"agent_reference": {"name": ..., "type": "agent_reference"}})
/// </code>
/// The azure-ai-projects .NET SDK does not (as of this build) expose the prompt-agent + Responses
/// surface, so we call the data-plane REST endpoint directly with <see cref="HttpClient"/> and an
/// Entra token from <see cref="DefaultAzureCredential"/>. // [verify] revisit if the .NET SDK adds
/// first-class prompt-agent support.
///
/// Endpoint (derived from the SDK's get_openai_client base_url, which appends "/openai/v1"):
///   POST {ProjectEndpoint}/openai/v1/responses
/// Token scope: https://ai.azure.com/.default
/// </summary>
public partial class ClaimsTriageAgentService
{
    private readonly HttpClient _http;
    private readonly ClaimsTriageAgentOptions _options;
    private readonly ILogger<ClaimsTriageAgentService> _logger;
    private readonly TokenCredential _credential;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public ClaimsTriageAgentService(
        HttpClient http,
        ClaimsTriageAgentOptions options,
        ILogger<ClaimsTriageAgentService> logger)
    {
        _http = http;
        _options = options;
        _logger = logger;

        // In Azure, the container app runs with a user-assigned managed identity; AZURE_CLIENT_ID
        // selects it. Locally, this falls through to the developer's az login. Either way no secret.
        _credential = new DefaultAzureCredential();
    }

    public bool IsConfigured => _options.IsConfigured;

    /// <summary>
    /// Runs a triage briefing for a claim number and returns the markdown briefing plus the
    /// tool/knowledge call trace.
    /// </summary>
    public async Task<TriageBriefing> GenerateBriefingAsync(
        string claimNumber,
        CancellationToken cancellationToken = default)
    {
        if (!_options.IsConfigured)
        {
            throw new InvalidOperationException(
                "The Foundry project endpoint is not configured. Set Foundry:ProjectEndpoint.");
        }

        var token = await _credential.GetTokenAsync(
            new TokenRequestContext(new[] { _options.TokenScope }),
            cancellationToken);

        var requestBody = new
        {
            input = $"Prepare a triage briefing for claim {claimNumber}",
            agent_reference = new { name = _options.AgentName, type = "agent_reference" }
        };

        var url = $"{_options.ProjectEndpoint.TrimEnd('/')}/openai/v1/responses";

        using var request = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(
                JsonSerializer.Serialize(requestBody, JsonOptions),
                Encoding.UTF8,
                "application/json")
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);

        _logger.LogInformation(
            "Requesting triage briefing for {ClaimNumber} from agent {AgentName}.",
            claimNumber, _options.AgentName);

        using var response = await _http.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Foundry Responses call failed ({StatusCode}): {Body}",
                (int)response.StatusCode, payload);
            throw new HttpRequestException(
                $"Foundry returned {(int)response.StatusCode} {response.ReasonPhrase}.");
        }

        return ParseBriefing(payload);
    }

    private static TriageBriefing ParseBriefing(string payload)
    {
        using var doc = JsonDocument.Parse(payload);
        var root = doc.RootElement;

        var steps = new List<TriageTraceStep>();
        var text = new StringBuilder();
        var citationCount = 0;

        if (root.TryGetProperty("output", out var output) && output.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in output.EnumerateArray())
            {
                var type = item.TryGetProperty("type", out var t) ? t.GetString() : null;
                var status = item.TryGetProperty("status", out var s) ? s.GetString() : null;

                switch (type)
                {
                    case "message":
                        if (item.TryGetProperty("content", out var content) &&
                            content.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var part in content.EnumerateArray())
                            {
                                if (part.TryGetProperty("type", out var pt) &&
                                    pt.GetString() == "output_text" &&
                                    part.TryGetProperty("text", out var txt))
                                {
                                    text.Append(txt.GetString());
                                }

                                if (part.TryGetProperty("annotations", out var ann) &&
                                    ann.ValueKind == JsonValueKind.Array)
                                {
                                    citationCount += ann.GetArrayLength();
                                }
                            }
                        }
                        break;

                    // OpenAPI tool call against the app's read-only /api surface.
                    case "openapi_call":
                    case "function_call":
                    case "custom_tool_call":
                        var opName = item.TryGetProperty("name", out var n) ? n.GetString() : null;
                        var args = item.TryGetProperty("arguments", out var a) ? a.GetString() : null;
                        steps.Add(DescribeApiCall(opName, args, status));
                        break;

                    // File-search grounding against the policy/handbook knowledge docs.
                    case "file_search_call":
                        steps.Add(DescribeFileSearch(item, status));
                        break;

                    // Skip the paired *_output items — they carry the raw response, already
                    // summarized by the call step above.
                    case "openapi_call_output":
                    case "function_call_output":
                        break;

                    default:
                        if (type is not null)
                        {
                            steps.Add(new TriageTraceStep("other", Humanize(type), null, type, status));
                        }
                        break;
                }
            }
        }

        return new TriageBriefing(text.ToString(), steps, citationCount);
    }

    /// <summary>
    /// Turns an OpenAPI/function tool call into a plain-language "what it fetched" step. The
    /// operationIds follow the create_new_agent.py convention: <c>{method}_{path_slug}</c>.
    /// </summary>
    private static TriageTraceStep DescribeApiCall(string? opName, string? argsJson, string? status)
    {
        var op = opName ?? "";
        var policyNumber = ExtractArg(argsJson, "policyNumber");
        var claimNumber = ExtractArg(argsJson, "claimNumber");
        var reference = opName;

        string title;
        string? detail;

        if (op.Contains("premium", StringComparison.OrdinalIgnoreCase))
        {
            title = policyNumber is not null
                ? $"Pulled premium payment history for {policyNumber}"
                : "Pulled premium payment history";
            detail = "billing standing — cleared / returned payments";
        }
        else if (op.Contains("policyholder", StringComparison.OrdinalIgnoreCase))
        {
            title = "Looked up the policyholder";
            detail = "member profile & tenure";
        }
        else if (op.Contains("polic", StringComparison.OrdinalIgnoreCase))
        {
            title = policyNumber is not null
                ? $"Looked up policy {policyNumber}"
                : "Looked up the policy record";
            detail = "coverage lines, limits & deductibles";
        }
        else if (op.Contains("claim", StringComparison.OrdinalIgnoreCase))
        {
            // A single-claim GET reads the claim; a list GET is the prior-claims scan.
            if (claimNumber is not null)
            {
                title = $"Retrieved claim {claimNumber}";
                detail = "loss description, amount & status";
            }
            else
            {
                title = "Retrieved prior claims on the policy";
                detail = "claims history / anomaly context";
            }
        }
        else
        {
            title = opName is not null ? $"Called {opName}" : "Called a tool";
            detail = argsJson is not null && argsJson.Length > 2 ? "with " + Compact(argsJson) : null;
        }

        return new TriageTraceStep("api", title, detail, reference, status);
    }

    /// <summary>
    /// Turns a file-search grounding call into a step naming the document(s) and, when the cited
    /// text exposes a section marker (e.g. "§3.2"), the section.
    /// </summary>
    private static TriageTraceStep DescribeFileSearch(JsonElement item, string? status)
    {
        var docs = new List<string>();
        var sections = new HashSet<string>();
        var queryText = new List<string>();

        if (item.TryGetProperty("queries", out var queries) && queries.ValueKind == JsonValueKind.Array)
        {
            foreach (var q in queries.EnumerateArray())
            {
                if (q.GetString() is { Length: > 0 } qs)
                {
                    queryText.Add(qs);
                }
            }
        }

        if (item.TryGetProperty("results", out var results) && results.ValueKind == JsonValueKind.Array)
        {
            foreach (var r in results.EnumerateArray())
            {
                var file = r.TryGetProperty("filename", out var f) ? f.GetString()
                    : r.TryGetProperty("file_name", out var f2) ? f2.GetString() : null;
                if (file is { Length: > 0 } && !docs.Contains(file))
                {
                    docs.Add(file);
                }

                if (r.TryGetProperty("text", out var rt) && rt.GetString() is { } body)
                {
                    foreach (Match m in SectionMarker().Matches(body))
                    {
                        sections.Add(m.Value);
                    }
                }
            }
        }

        var reference = docs.Count > 0
            ? (sections.Count > 0
                ? $"{string.Join(", ", docs)} {string.Join(", ", sections)}"
                : string.Join(", ", docs))
            : "knowledge base";

        var detail = queryText.Count > 0
            ? "query: “" + string.Join("; ", queryText) + "”"
            : "policy declarations & claims-handling guide";

        return new TriageTraceStep(
            "search",
            "Grounded the coverage call in policy documents",
            detail,
            reference,
            status);
    }

    private static string? ExtractArg(string? argsJson, string name)
    {
        if (string.IsNullOrWhiteSpace(argsJson))
        {
            return null;
        }

        try
        {
            using var doc = JsonDocument.Parse(argsJson);
            if (doc.RootElement.ValueKind == JsonValueKind.Object &&
                doc.RootElement.TryGetProperty(name, out var v))
            {
                return v.ValueKind == JsonValueKind.String ? v.GetString() : v.ToString();
            }
        }
        catch (JsonException)
        {
            // Arguments were not JSON we could read; fall through.
        }

        return null;
    }

    private static string Compact(string s) =>
        s.Length <= 80 ? s : s[..77] + "…";

    private static string Humanize(string type) =>
        char.ToUpperInvariant(type[0]) + type[1..].Replace('_', ' ');

    [GeneratedRegex(@"§\s?\d+(?:\.\d+)*")]
    private static partial Regex SectionMarker();
}
