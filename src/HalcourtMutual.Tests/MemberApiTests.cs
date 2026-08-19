using System.Net;
using System.Net.Http.Json;
using HalcourtMutual.Models;
using HalcourtMutual.Models.Api;
using Xunit;

namespace HalcourtMutual.Tests;

/// <summary>
/// The member API is the surface an external caller talks to, so it is asserted through real
/// HTTP requests rather than against the services directly.
/// </summary>
public class MemberApiTests : IClassFixture<MemberApiFactory>
{
    private const string AutoPolicy = "MM-AUTO-004417";
    private const string HomePolicy = "MM-HOME-002289";

    private readonly HttpClient _client;

    public MemberApiTests(MemberApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Policyholder_is_served_by_id()
    {
        var member = await _client.GetFromJsonAsync<PolicyholderResponse>(
            "/api/policyholders/1", MemberApiFactory.Json);

        Assert.NotNull(member);
        Assert.Equal(1, member!.Id);
        Assert.NotEmpty(member.Name);
        Assert.Contains("@", member.Email);
    }

    [Fact]
    public async Task Unknown_policyholder_is_not_found()
    {
        var response = await _client.GetAsync("/api/policyholders/9999");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Policies_are_listed_for_a_member()
    {
        var policies = await _client.GetFromJsonAsync<List<PolicyResponse>>(
            "/api/policies?policyholderId=1", MemberApiFactory.Json);

        Assert.NotNull(policies);
        Assert.Equal(2, policies!.Count);
        Assert.Contains(policies, p => p.PolicyNumber == AutoPolicy && p.Type == PolicyType.Auto);
        Assert.Contains(policies, p => p.PolicyNumber == HomePolicy && p.Type == PolicyType.Home);
    }

    [Fact]
    public async Task Policy_is_served_by_policy_number()
    {
        var policy = await _client.GetFromJsonAsync<PolicyResponse>(
            $"/api/policies/{AutoPolicy}", MemberApiFactory.Json);

        Assert.NotNull(policy);
        Assert.Equal(AutoPolicy, policy!.PolicyNumber);
        Assert.Equal(PolicyStatus.Active, policy.Status);
        Assert.True(policy.MonthlyPremium > 0);
    }

    [Fact]
    public async Task Premium_payments_include_the_current_month()
    {
        var payments = await _client.GetFromJsonAsync<List<PremiumPaymentResponse>>(
            $"/api/policies/{AutoPolicy}/premium-payments", MemberApiFactory.Json);

        var today = DateTime.Today;

        Assert.NotNull(payments);
        Assert.NotEmpty(payments!);
        Assert.All(payments!, p => Assert.Equal(AutoPolicy, p.PolicyNumber));
        Assert.Contains(payments!, p =>
            p.PaidOn.Year == today.Year && p.PaidOn.Month == today.Month && p.Status == PaymentStatus.Cleared);
    }

    [Fact]
    public async Task Premium_payments_for_an_unknown_policy_are_not_found()
    {
        var response = await _client.GetAsync("/api/policies/MM-AUTO-000000/premium-payments");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Claims_are_listed_for_a_policy()
    {
        var claims = await _client.GetFromJsonAsync<List<ClaimResponse>>(
            $"/api/claims?policyNumber={AutoPolicy}", MemberApiFactory.Json);

        Assert.NotNull(claims);
        Assert.NotEmpty(claims!);
        Assert.All(claims!, c => Assert.Equal(AutoPolicy, c.PolicyNumber));
    }

    [Fact]
    public async Task Claim_is_served_by_claim_number()
    {
        var claim = await _client.GetFromJsonAsync<ClaimResponse>(
            $"/api/claims/CLM-{DateTime.Today.Year}-00841", MemberApiFactory.Json);

        Assert.NotNull(claim);
        Assert.Equal(ClaimStatus.UnderReview, claim!.Status);
        Assert.Equal(AutoPolicy, claim.PolicyNumber);
    }

    [Fact]
    public async Task Filing_a_claim_returns_a_claim_number_that_can_be_fetched()
    {
        var response = await _client.PostAsJsonAsync("/api/claims", new
        {
            policyNumber = HomePolicy,
            amount = 1875.25m,
            description = "Storm damage to the garage roof; tarped pending repair."
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var created = await response.Content.ReadFromJsonAsync<ClaimCreatedResponse>(MemberApiFactory.Json);

        Assert.NotNull(created);
        Assert.StartsWith($"CLM-{DateTime.Today.Year}-", created!.ClaimNumber);
        Assert.Equal(ClaimStatus.Open, created.Status);
        Assert.Equal(HomePolicy, created.PolicyNumber);

        var fetched = await _client.GetFromJsonAsync<ClaimResponse>(
            $"/api/claims/{created.ClaimNumber}", MemberApiFactory.Json);

        Assert.NotNull(fetched);
        Assert.Equal(1875.25m, fetched!.Amount);
        Assert.Equal(HomePolicy, fetched.PolicyNumber);
    }

    [Fact]
    public async Task Filing_a_claim_against_an_unknown_policy_is_rejected()
    {
        var response = await _client.PostAsJsonAsync("/api/claims", new
        {
            policyNumber = "MM-AUTO-000000",
            amount = 500m,
            description = "Claim against a policy that does not exist."
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task The_openapi_document_is_served()
    {
        var response = await _client.GetAsync("/swagger/v1/swagger.json");
        var document = await response.Content.ReadAsStringAsync();

        response.EnsureSuccessStatusCode();
        Assert.Contains("/api/policies/{policyNumber}/premium-payments", document);
        Assert.Contains("Halcourt Mutual Member API", document);
    }
}
