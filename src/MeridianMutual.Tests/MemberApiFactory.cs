using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Formatters;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using JsonOptions = Microsoft.AspNetCore.Mvc.JsonOptions;

namespace MeridianMutual.Tests;

/// <summary>
/// Boots the portal in-process against a throwaway SQLite file, so the member API is exercised
/// end to end — routing, model binding, serialisation and the seeded data set.
/// </summary>
public class MemberApiFactory : WebApplicationFactory<Program>
{
    private readonly string _databasePath =
        Path.Combine(Path.GetTempPath(), $"meridianmutual-api-{Guid.NewGuid():N}.db");

    /// <summary>Matches the enum-as-name serialisation the app is configured with.</summary>
    public static JsonSerializerOptions Json { get; } = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() }
    };

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");

        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:MeridianMutualDb"] = $"Data Source={_databasePath}"
            }));

        builder.ConfigureTestServices(services =>
        {
            services.AddOptions<MvcOptions>().PostConfigure<IOptions<JsonOptions>>(ReplaceJsonOutputFormatter);

            // The deployed estate wires Entra JWT bearer, but there is no identity provider in the
            // test host. Supply a scheme that authenticates every request with both app roles, so
            // the API's [Authorize] gates are satisfied and the tests exercise app behaviour, not
            // the RBAC layer (that boundary is proven live against the deployed API).
            services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
        });
    }

    /// <summary>Authenticates every request as an adjuster holding both Claims.Read and Claims.Write.</summary>
    private sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        public const string SchemeName = "Test";

        public TestAuthHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder)
            : base(options, logger, encoder)
        {
        }

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var identity = new ClaimsIdentity(SchemeName, ClaimTypes.Name, ClaimTypes.Role);
            identity.AddClaim(new Claim(ClaimTypes.Name, "test-adjuster"));
            identity.AddClaim(new Claim(ClaimTypes.Role, "Claims.Read"));
            identity.AddClaim(new Claim(ClaimTypes.Role, "Claims.Write"));

            var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }

    /// <summary>
    /// Swaps MVC's JSON output formatter for one that writes to the response stream.
    ///
    /// TestServer's response <c>PipeWriter</c> does not implement <c>UnflushedBytes</c>, which
    /// the serialiser requires when the net8.0 test host rolls forward onto a newer shared
    /// runtime. It is a hosting-shim limitation, not app behaviour: over Kestrel the app uses
    /// its normal formatter. Everything else in the pipeline is left untouched.
    /// </summary>
    private static void ReplaceJsonOutputFormatter(MvcOptions mvc, IOptions<JsonOptions> json)
    {
        for (var i = 0; i < mvc.OutputFormatters.Count; i++)
        {
            if (mvc.OutputFormatters[i] is SystemTextJsonOutputFormatter)
            {
                mvc.OutputFormatters[i] = new StreamJsonOutputFormatter(json.Value.JsonSerializerOptions);
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (!disposing)
        {
            return;
        }

        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();

        foreach (var path in new[] { _databasePath, $"{_databasePath}-wal", $"{_databasePath}-shm" })
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }

    private sealed class StreamJsonOutputFormatter : TextOutputFormatter
    {
        private readonly JsonSerializerOptions _options;

        public StreamJsonOutputFormatter(JsonSerializerOptions options)
        {
            _options = options;

            SupportedEncodings.Add(Encoding.UTF8);
            SupportedMediaTypes.Add("application/json");
            SupportedMediaTypes.Add("text/json");
            SupportedMediaTypes.Add("application/*+json");
        }

        public override Task WriteResponseBodyAsync(OutputFormatterWriteContext context, Encoding selectedEncoding)
        {
            var httpContext = context.HttpContext;
            var objectType = context.Object?.GetType() ?? context.ObjectType ?? typeof(object);

            return JsonSerializer.SerializeAsync(
                httpContext.Response.Body, context.Object, objectType, _options, httpContext.RequestAborted);
        }
    }
}
