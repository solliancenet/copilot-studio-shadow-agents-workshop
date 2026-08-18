using System.Text.Json.Serialization;
using MeridianMutual.Data;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Entra JWT bearer for the /api/* member API. This is what makes the agent's least privilege
// PROVABLE: the API validates the caller's Entra token and enforces the app roles Claims.Read /
// Claims.Write. A caller (the Foundry agent's managed identity) that holds only Claims.Read is
// stopped at the RBAC layer — 401 — when it attempts a write, regardless of what a prompt says.
//
// Enforcement is wired only when AzureAd:ClientId is configured (i.e. in the deployed estate).
// Locally and in the test host there is no AzureAd config, the JWT scheme is absent, and a test
// authentication handler supplies the principal instead. The [Authorize] attributes on the API
// controllers are unconditional; only the identity provider behind them changes.
var apiAuthConfigured = !string.IsNullOrWhiteSpace(builder.Configuration["AzureAd:ClientId"]);
if (apiAuthConfigured)
{
    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

    // App roles arrive in the "roles" claim of an application (client-credentials / managed
    // identity) token; map that claim so [Authorize(Roles = "Claims.Read|Claims.Write")] matches.
    // PostConfigure so this wins over Microsoft.Identity.Web's own options setup, and log the
    // calling identity + granted roles on every validated token — that trace is the evidence that
    // the agent's least privilege is enforced by identity, not by prompt.
    builder.Services.PostConfigure<JwtBearerOptions>(
        JwtBearerDefaults.AuthenticationScheme,
        options =>
        {
            // App roles ("roles" claim) are mapped inbound to the standard ClaimTypes.Role, which
            // is the default RoleClaimType — so [Authorize(Roles = "Claims.Read|Claims.Write")]
            // matches without overriding RoleClaimType. (Overriding it to "roles" would break the
            // match, because the claim no longer exists under that short name after mapping.)

            // Accept every App ID URI registered for this app: the base api://<clientId> and the
            // agent-scoped api://<clientId>/agent. The agent-scoped URI is a distinct token
            // audience (resource), which the Foundry managed identity requests independently — it
            // is also what lets a freshly-assigned app role take effect without waiting out the
            // managed-identity token cache on the base audience.
            var clientId = builder.Configuration["AzureAd:ClientId"];
            options.TokenValidationParameters.ValidAudiences = new[]
            {
                $"api://{clientId}",
                $"api://{clientId}/agent",
                clientId!,
            };

            var existing = options.Events ??= new JwtBearerEvents();
            var priorValidated = existing.OnTokenValidated;
            existing.OnTokenValidated = async context =>
            {
                if (priorValidated is not null)
                {
                    await priorValidated(context);
                }

                var logger = context.HttpContext.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("MeridianMutual.Api.Auth");
                var principal = context.Principal;
                var appId = principal?.FindFirst("azp")?.Value
                    ?? principal?.FindFirst("appid")?.Value;
                var roles = string.Join(",",
                    principal?.FindAll(System.Security.Claims.ClaimTypes.Role).Select(c => c.Value) ?? []);
                logger.LogInformation(
                    "API token validated for {Path}: appid={AppId} roles=[{Roles}]",
                    context.HttpContext.Request.Path, appId ?? "(none)",
                    string.IsNullOrEmpty(roles) ? "(none)" : roles);
            };
        });
}

builder.Services.AddAuthorization();

builder.Services.AddControllersWithViews()
    .AddJsonOptions(options =>
    {
        // Policy type, policy status, payment method and claim status read as names, not ordinals.
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// OpenAPI: the member API is meant to be called by things other than this portal, so the
// contract is published at /swagger (UI) and /swagger/v1/swagger.json (document).
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Meridian Mutual Member API",
        Version = "v1",
        Description =
            "Policy, premium and claim lookup for Meridian Mutual members. "
            + "Demonstration estate: the API is unauthenticated and serves seeded data only."
    });

    var xmlDocumentation = Path.Combine(AppContext.BaseDirectory, "MeridianMutual.xml");
    if (File.Exists(xmlDocumentation))
    {
        options.IncludeXmlComments(xmlDocumentation);
    }
});

builder.Services.AddDbContext<MeridianMutualDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("MeridianMutualDb")
        ?? "Data Source=meridianmutual.db"));

builder.Services.AddScoped<PolicyService>();
builder.Services.AddScoped<PremiumService>();
builder.Services.AddScoped<ClaimService>();

// Foundry Claims-Triage agent. Connection settings (project endpoint + agent name) come from
// configuration / environment — no secrets; the app authenticates with its managed identity.
var triageOptions = builder.Configuration.GetSection(ClaimsTriageAgentOptions.SectionName)
    .Get<ClaimsTriageAgentOptions>() ?? new ClaimsTriageAgentOptions();
builder.Services.AddSingleton(triageOptions);
builder.Services.AddHttpClient<ClaimsTriageAgentService>(client =>
{
    // A briefing run makes several tool calls server-side; give it room.
    client.Timeout = TimeSpan.FromMinutes(3);
});

var app = builder.Build();

// Bring the schema up to date on start-up, then load the demonstration data set.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<MeridianMutualDbContext>();
    db.Database.Migrate();
    PolicySeeder.Seed(db);
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Served in every environment: the API contract is part of what this demo estate exposes.
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "Meridian Mutual Member API v1");
    options.DocumentTitle = "Meridian Mutual Member API";
});

app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

/// <summary>Exposed so the test project can drive the app through WebApplicationFactory.</summary>
public partial class Program;
