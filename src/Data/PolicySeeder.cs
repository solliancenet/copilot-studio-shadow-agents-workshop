using MeridianMutual.Models;

namespace MeridianMutual.Data;

/// <summary>
/// Loads the demonstration data set. The member portal is a pilot workload, so it ships with a
/// single demonstration policyholder rather than connecting to the policy administration system.
/// Dates are anchored to today so the seeded book always includes the current billing month.
/// </summary>
public static class PolicySeeder
{
    public static void Seed(MeridianMutualDbContext db)
    {
        if (db.Policyholders.Any())
        {
            return;
        }

        var today = DateTime.Today;
        var thisMonth = new DateTime(today.Year, today.Month, 1);

        var member = new Policyholder
        {
            Name = "Dana Whitfield",
            Email = "dana.whitfield@example.com",
            MemberSince = new DateTime(2014, 6, 1)
        };

        db.Policyholders.Add(member);
        db.SaveChanges();

        var auto = new Policy
        {
            PolicyNumber = "MM-AUTO-004417",
            PolicyholderId = member.Id,
            Type = PolicyType.Auto,
            Status = PolicyStatus.Active,
            MonthlyPremium = 128.40m,
            EffectiveDate = new DateTime(2019, 4, 1),
            RenewalDate = NextAnniversary(new DateTime(2019, 4, 1), today),
            CoverageSummary =
                "2019 Subaru Outback. Liability 100/300, $500 collision deductible, "
                + "$250 comprehensive deductible, rental reimbursement included."
        };

        var home = new Policy
        {
            PolicyNumber = "MM-HOME-002289",
            PolicyholderId = member.Id,
            Type = PolicyType.Home,
            Status = PolicyStatus.Active,
            MonthlyPremium = 96.15m,
            EffectiveDate = new DateTime(2016, 9, 15),
            RenewalDate = NextAnniversary(new DateTime(2016, 9, 15), today),
            CoverageSummary =
                "Single-family dwelling, 1,860 sq ft. Dwelling limit $412,000, personal property "
                + "$206,000, $1,000 all-peril deductible, water backup endorsement."
        };

        db.Policies.AddRange(auto, home);
        db.SaveChanges();

        // Four billing months each, ending with the month the demo is being run in: the auto
        // premium has already cleared, the home premium is still in flight.
        db.PremiumPayments.AddRange(
            Payment(auto.Id, thisMonth.AddMonths(-3).AddDays(3), auto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(auto.Id, thisMonth.AddMonths(-2).AddDays(3), auto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(auto.Id, thisMonth.AddMonths(-1).AddDays(3), auto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(auto.Id, thisMonth.AddDays(3), auto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(home.Id, thisMonth.AddMonths(-3).AddDays(11), home.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Cleared),
            Payment(home.Id, thisMonth.AddMonths(-2).AddDays(11), home.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Returned),
            Payment(home.Id, thisMonth.AddMonths(-2).AddDays(19), home.MonthlyPremium, PaymentMethod.Card, PaymentStatus.Cleared),
            Payment(home.Id, thisMonth.AddMonths(-1).AddDays(11), home.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Cleared),
            Payment(home.Id, thisMonth.AddDays(11), home.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Pending));

        db.Claims.Add(new Claim
        {
            ClaimNumber = $"CLM-{today.Year}-00841",
            PolicyId = auto.Id,
            Status = ClaimStatus.UnderReview,
            Amount = 2350.00m,
            FiledOn = today.AddDays(-38),
            Description = "Rear bumper and tailgate damage from a parking-lot collision. "
                + "Repair estimate from Weller Auto Body is on file; adjuster inspection completed."
        });

        db.SaveChanges();
    }

    private static PremiumPayment Payment(
        long policyId,
        DateTime paidOn,
        decimal amount,
        PaymentMethod method,
        PaymentStatus status) =>
        new()
        {
            PolicyId = policyId,
            PaidOn = paidOn,
            Amount = amount,
            Method = method,
            Status = status
        };

    /// <summary>The next policy anniversary on or after <paramref name="asOf"/>.</summary>
    private static DateTime NextAnniversary(DateTime effectiveDate, DateTime asOf)
    {
        var anniversary = new DateTime(asOf.Year, effectiveDate.Month, effectiveDate.Day);
        return anniversary < asOf ? anniversary.AddYears(1) : anniversary;
    }
}
