using MeridianMutual.Models;
using MeridianMutual.Services;
using Xunit;

namespace MeridianMutual.Tests;

/// <summary>
/// "Did my premium clear?" is the question the member portal is asked most, so the payment
/// history has to be ordered and statused the way the servicing desk expects.
/// </summary>
public class PremiumServiceTests : IClassFixture<EstateFixture>
{
    private readonly EstateFixture _fixture;

    public PremiumServiceTests(EstateFixture fixture)
    {
        _fixture = fixture;
    }

    private (PolicyService Policies, PremiumService Premiums) CreateServices()
    {
        var db = _fixture.CreateContext();
        return (new PolicyService(db), new PremiumService(db));
    }

    [Fact]
    public void Payments_are_returned_newest_first()
    {
        var (policies, premiums) = CreateServices();
        var policy = policies.GetByPolicyNumber("MM-AUTO-004417")!;

        var payments = premiums.GetPayments(policy.Id);

        Assert.NotEmpty(payments);
        Assert.Equal(
            payments.OrderByDescending(p => p.PaidOn).Select(p => p.PaidOn),
            payments.Select(p => p.PaidOn));
    }

    [Fact]
    public void The_current_billing_month_is_covered()
    {
        var (policies, premiums) = CreateServices();
        var policy = policies.GetByPolicyNumber("MM-AUTO-004417")!;
        var today = DateTime.Today;

        var thisMonth = premiums.GetPayments(policy.Id)
            .SingleOrDefault(p => p.PaidOn.Year == today.Year && p.PaidOn.Month == today.Month);

        Assert.NotNull(thisMonth);
        Assert.Equal(policy.MonthlyPremium, thisMonth!.Amount);
        Assert.Equal(PaymentStatus.Cleared, thisMonth.Status);
    }

    [Fact]
    public void A_returned_payment_is_kept_alongside_the_retry_that_cleared()
    {
        var (policies, premiums) = CreateServices();
        var policy = policies.GetByPolicyNumber("MM-HOME-002289")!;

        var payments = premiums.GetPayments(policy.Id);

        Assert.Contains(payments, p => p.Status == PaymentStatus.Returned);
        Assert.Contains(payments, p => p.Status == PaymentStatus.Cleared);
    }

    [Fact]
    public void Payments_belong_only_to_the_policy_asked_for()
    {
        var (policies, premiums) = CreateServices();
        var auto = policies.GetByPolicyNumber("MM-AUTO-004417")!;

        Assert.All(premiums.GetPayments(auto.Id), p => Assert.Equal(auto.Id, p.PolicyId));
    }
}
