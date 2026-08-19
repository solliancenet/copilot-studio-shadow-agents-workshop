namespace HalcourtMutual.Models;

/// <summary>Where a claim sits in the adjusting workflow.</summary>
public enum ClaimStatus
{
    Open,
    UnderReview,
    Approved,
    Denied
}

public class Claim
{
    public long Id { get; set; }

    /// <summary>Customer-facing identifier, e.g. <c>CLM-2026-00841</c>.</summary>
    public string ClaimNumber { get; set; } = "";

    public long PolicyId { get; set; }

    public Policy? Policy { get; set; }

    public ClaimStatus Status { get; set; }

    public decimal Amount { get; set; }

    public DateTime FiledOn { get; set; }

    public string Description { get; set; } = "";
}
