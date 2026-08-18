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

        // Additional book so the triage queue reads like a real adjuster's worklist. Dana
        // Whitfield above is left untouched (still the single-policyholder demo member, and
        // CLM-2026-00841 remains the only claim on its policy — "no prior claims").
        SeedAdditionalQueue(db, today, thisMonth);
    }

    /// <summary>
    /// Two more policyholders with active policies and open/under-review claims, so the triage
    /// queue has several rows. Kept deliberately separate from the primary demo member.
    /// </summary>
    private static void SeedAdditionalQueue(MeridianMutualDbContext db, DateTime today, DateTime thisMonth)
    {
        var reyes = new Policyholder
        {
            Name = "Marcus Reyes",
            Email = "marcus.reyes@example.com",
            MemberSince = new DateTime(2018, 3, 1)
        };
        var nadella = new Policyholder
        {
            Name = "Priya Nadella",
            Email = "priya.nadella@example.com",
            MemberSince = new DateTime(2021, 11, 1)
        };

        db.Policyholders.AddRange(reyes, nadella);
        db.SaveChanges();

        var reyesAuto = new Policy
        {
            PolicyNumber = "MM-AUTO-005522",
            PolicyholderId = reyes.Id,
            Type = PolicyType.Auto,
            Status = PolicyStatus.Active,
            MonthlyPremium = 142.75m,
            EffectiveDate = new DateTime(2018, 3, 1),
            RenewalDate = NextAnniversary(new DateTime(2018, 3, 1), today),
            CoverageSummary =
                "2022 Toyota RAV4. Liability 100/300, $500 collision deductible, "
                + "$250 comprehensive deductible, glass coverage included."
        };

        var nadellaHome = new Policy
        {
            PolicyNumber = "MM-HOME-003310",
            PolicyholderId = nadella.Id,
            Type = PolicyType.Home,
            Status = PolicyStatus.Active,
            MonthlyPremium = 108.90m,
            EffectiveDate = new DateTime(2021, 11, 1),
            RenewalDate = NextAnniversary(new DateTime(2021, 11, 1), today),
            CoverageSummary =
                "Single-family dwelling, 2,240 sq ft. Dwelling limit $488,000, personal property "
                + "$244,000, $1,000 all-peril deductible, water backup endorsement."
        };

        var nadellaAuto = new Policy
        {
            PolicyNumber = "MM-AUTO-006140",
            PolicyholderId = nadella.Id,
            Type = PolicyType.Auto,
            Status = PolicyStatus.Active,
            MonthlyPremium = 119.30m,
            EffectiveDate = new DateTime(2022, 5, 15),
            RenewalDate = NextAnniversary(new DateTime(2022, 5, 15), today),
            CoverageSummary =
                "2020 Honda CR-V. Liability 100/300, $500 collision deductible, "
                + "$250 comprehensive deductible, rental reimbursement included."
        };

        db.Policies.AddRange(reyesAuto, nadellaHome, nadellaAuto);
        db.SaveChanges();

        // A little premium history so the agent's standing lookup has something to read. Note the
        // returned payment on nadellaHome preceding its claim — a standing flag for triage.
        db.PremiumPayments.AddRange(
            Payment(reyesAuto.Id, thisMonth.AddMonths(-2).AddDays(5), reyesAuto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(reyesAuto.Id, thisMonth.AddMonths(-1).AddDays(5), reyesAuto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(reyesAuto.Id, thisMonth.AddDays(5), reyesAuto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(nadellaHome.Id, thisMonth.AddMonths(-2).AddDays(8), nadellaHome.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Cleared),
            Payment(nadellaHome.Id, thisMonth.AddMonths(-1).AddDays(8), nadellaHome.MonthlyPremium, PaymentMethod.BankTransfer, PaymentStatus.Returned),
            Payment(nadellaHome.Id, thisMonth.AddDays(8), nadellaHome.MonthlyPremium, PaymentMethod.Card, PaymentStatus.Cleared),
            Payment(nadellaAuto.Id, thisMonth.AddMonths(-1).AddDays(2), nadellaAuto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared),
            Payment(nadellaAuto.Id, thisMonth.AddDays(2), nadellaAuto.MonthlyPremium, PaymentMethod.AutoPay, PaymentStatus.Cleared));

        db.Claims.AddRange(
            new Claim
            {
                ClaimNumber = $"CLM-{today.Year}-00842",
                PolicyId = reyesAuto.Id,
                Status = ClaimStatus.UnderReview,
                Amount = 1180.00m,
                FiledOn = today.AddDays(-12),
                Description = "Hail damage to the hood and roof panel during a storm; multiple dents. "
                    + "Photos submitted, no glass breakage reported."
            },
            new Claim
            {
                ClaimNumber = $"CLM-{today.Year}-00843",
                PolicyId = nadellaHome.Id,
                Status = ClaimStatus.Open,
                Amount = 3620.00m,
                FiledOn = today.AddDays(-4),
                Description = "Water backup from a blocked drain flooded the finished basement. "
                    + "Mitigation vendor on site; itemized estimate pending."
            },
            new Claim
            {
                ClaimNumber = $"CLM-{today.Year}-00844",
                PolicyId = nadellaAuto.Id,
                Status = ClaimStatus.Open,
                Amount = 640.00m,
                FiledOn = today.AddDays(-1),
                Description = "Cracked windshield from highway debris. No other damage reported."
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
