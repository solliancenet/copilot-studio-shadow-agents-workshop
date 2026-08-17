using System.Text.Json.Serialization;
using MeridianMutual.Data;
using MeridianMutual.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

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

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

/// <summary>Exposed so the test project can drive the app through WebApplicationFactory.</summary>
public partial class Program;
