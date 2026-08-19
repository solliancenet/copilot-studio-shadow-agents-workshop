namespace HalcourtMutual.Models;

/// <summary>The lines of business the portal covers.</summary>
public enum PolicyType
{
    Auto,
    Home,
    Life
}

/// <summary>Whether the policy is in force. A lapsed policy still shows its history.</summary>
public enum PolicyStatus
{
    Active,
    Lapsed
}

public class Policy
{
    public long Id { get; set; }

    /// <summary>Customer-facing identifier, e.g. <c>MM-AUTO-004417</c>.</summary>
    public string PolicyNumber { get; set; } = "";

    public long PolicyholderId { get; set; }

    public Policyholder? Policyholder { get; set; }

    public PolicyType Type { get; set; }

    public PolicyStatus Status { get; set; }

    public decimal MonthlyPremium { get; set; }

    public DateTime EffectiveDate { get; set; }

    public DateTime RenewalDate { get; set; }

    /// <summary>Plain-language summary of what the policy covers.</summary>
    public string CoverageSummary { get; set; } = "";

    public List<PremiumPayment> PremiumPayments { get; set; } = new();

    public List<Claim> Claims { get; set; } = new();
}
