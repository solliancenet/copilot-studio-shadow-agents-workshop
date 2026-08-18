using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
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

/// <summary>A single tool or knowledge call the agent made while preparing a briefing.</summary>
public record TriageToolCall(string Type, string? Name, string? Status);

/// <summary>The rendered result of a triage briefing run.</summary>
public record TriageBriefing(
    string Markdown,
    IReadOnlyList<TriageToolCall> ToolCalls,
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
public class ClaimsTriageAgentService
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

        var toolCalls = new List<TriageToolCall>();
        var text = new StringBuilder();
        var citationCount = 0;

        if (root.TryGetProperty("output", out var output) && output.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in output.EnumerateArray())
            {
                var type = item.TryGetProperty("type", out var t) ? t.GetString() : null;

                if (type == "message")
                {
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
                }
                else if (type is not null)
                {
                    // openapi_call, openapi_call_output, file_search_call, function_call, etc.
                    var name = item.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var status = item.TryGetProperty("status", out var s) ? s.GetString() : null;
                    toolCalls.Add(new TriageToolCall(type, name, status));
                }
            }
        }

        return new TriageBriefing(text.ToString(), toolCalls, citationCount);
    }
}
