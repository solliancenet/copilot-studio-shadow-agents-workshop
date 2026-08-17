using MeridianMutual.Models;
using MeridianMutual.Services;
using Xunit;

namespace MeridianMutual.Tests;

public class PolicyServiceTests : IClassFixture<EstateFixture>
{
    private readonly EstateFixture _fixture;

    public PolicyServiceTests(EstateFixture fixture)
    {
        _fixture = fixture;
    }

    private PolicyService CreateService() => new(_fixture.CreateContext());

    [Fact]
    public void Policies_are_listed_for_the_member_who_holds_them()
    {
        var service = CreateService();
        var member = service.GetSignedInPolicyholder();

        Assert.NotNull(member);

        var policies = service.GetByPolicyholder(member!.Id);

        Assert.Equal(2, policies.Count);
        Assert.Contains(policies, p => p.Type == PolicyType.Auto);
        Assert.Contains(policies, p => p.Type == PolicyType.Home);
        Assert.All(policies, p => Assert.Equal(member.Id, p.PolicyholderId));
    }

    [Fact]
    public void Policy_is_found_by_policy_number()
    {
        var policy = CreateService().GetByPolicyNumber("MM-AUTO-004417");

        Assert.NotNull(policy);
        Assert.Equal(PolicyType.Auto, policy!.Type);
        Assert.Equal(PolicyStatus.Active, policy.Status);
        Assert.NotEmpty(policy.CoverageSummary);
    }

    [Fact]
    public void Unknown_policy_number_returns_nothing()
    {
        Assert.Null(CreateService().GetByPolicyNumber("MM-AUTO-000000"));
    }

    [Fact]
    public void Renewal_date_is_in_the_future()
    {
        var policy = CreateService().GetByPolicyNumber("MM-HOME-002289");

        Assert.NotNull(policy);
        Assert.True(policy!.RenewalDate >= DateTime.Today);
    }
}
