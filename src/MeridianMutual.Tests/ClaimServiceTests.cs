using MeridianMutual.Models;
using MeridianMutual.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace MeridianMutual.Tests;

public class ClaimServiceTests : IClassFixture<EstateFixture>
{
    private readonly EstateFixture _fixture;

    public ClaimServiceTests(EstateFixture fixture)
    {
        _fixture = fixture;
    }

    private (PolicyService Policies, ClaimService Claims) CreateServices()
    {
        var db = _fixture.CreateContext();
        return (new PolicyService(db), new ClaimService(db, NullLogger<ClaimService>.Instance));
    }

    [Fact]
    public void The_seeded_claim_is_found_by_claim_number()
    {
        var (_, claims) = CreateServices();

        var claim = claims.GetByClaimNumber($"CLM-{DateTime.Today.Year}-00841");

        Assert.NotNull(claim);
        Assert.Equal(ClaimStatus.UnderReview, claim!.Status);
        Assert.Equal(2350.00m, claim.Amount);
        Assert.Equal("MM-AUTO-004417", claim.Policy?.PolicyNumber);
    }

    [Fact]
    public void Filing_a_claim_returns_a_claim_number_that_can_be_looked_up()
    {
        var (policies, claims) = CreateServices();
        var policy = policies.GetByPolicyNumber("MM-HOME-002289")!;

        var claimNumber = claims.CreateClaim(policy.Id, 1425.50m, "Water damage in the utility room after a supply line failed.");

        var filed = claims.GetByClaimNumber(claimNumber);

        Assert.StartsWith($"CLM-{DateTime.Today.Year}-", claimNumber);
        Assert.NotNull(filed);
        Assert.Equal(ClaimStatus.Open, filed!.Status);
        Assert.Equal(1425.50m, filed.Amount);
        Assert.Equal(policy.Id, filed.PolicyId);
        Assert.Equal(DateTime.Today, filed.FiledOn);
    }

    [Fact]
    public void Claim_numbers_do_not_repeat()
    {
        var (policies, claims) = CreateServices();
        var policy = policies.GetByPolicyNumber("MM-AUTO-004417")!;

        var first = claims.CreateClaim(policy.Id, 310.00m, "Windshield chip from highway debris.");
        var second = claims.CreateClaim(policy.Id, 780.00m, "Hail damage to the roof panel and hood.");

        Assert.NotEqual(first, second);
    }

    [Fact]
    public void Claims_are_listed_against_the_policy_they_were_filed_on()
    {
        var (policies, claims) = CreateServices();
        var auto = policies.GetByPolicyNumber("MM-AUTO-004417")!;

        var filed = claims.GetClaims(auto.Id);

        Assert.NotEmpty(filed);
        Assert.All(filed, c => Assert.Equal(auto.Id, c.PolicyId));
        Assert.Equal(
            filed.OrderByDescending(c => c.FiledOn).Select(c => c.ClaimNumber),
            filed.Select(c => c.ClaimNumber));
    }
}
