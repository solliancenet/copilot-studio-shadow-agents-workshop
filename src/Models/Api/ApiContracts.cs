using System.ComponentModel.DataAnnotations;

namespace MeridianMutual.Models.Api;

/// <summary>A member of the mutual.</summary>
public record PolicyholderResponse(
    long Id,
    string Name,
    string Email,
    DateTime MemberSince)
{
    public static PolicyholderResponse From(Policyholder policyholder) =>
        new(policyholder.Id, policyholder.Name, policyholder.Email, policyholder.MemberSince);
}

/// <summary>A policy as returned by the member API.</summary>
public record PolicyResponse(
    string PolicyNumber,
    long PolicyholderId,
    PolicyType Type,
    PolicyStatus Status,
    decimal MonthlyPremium,
    DateTime EffectiveDate,
    DateTime RenewalDate,
    string CoverageSummary)
{
    public static PolicyResponse From(Policy policy) =>
        new(policy.PolicyNumber,
            policy.PolicyholderId,
            policy.Type,
            policy.Status,
            policy.MonthlyPremium,
            policy.EffectiveDate,
            policy.RenewalDate,
            policy.CoverageSummary);
}

/// <summary>One premium payment against a policy.</summary>
public record PremiumPaymentResponse(
    string PolicyNumber,
    DateTime PaidOn,
    decimal Amount,
    PaymentMethod Method,
    PaymentStatus Status)
{
    public static PremiumPaymentResponse From(string policyNumber, PremiumPayment payment) =>
        new(policyNumber, payment.PaidOn, payment.Amount, payment.Method, payment.Status);
}

/// <summary>A claim as returned by the member API.</summary>
public record ClaimResponse(
    string ClaimNumber,
    string PolicyNumber,
    ClaimStatus Status,
    decimal Amount,
    DateTime FiledOn,
    string Description)
{
    public static ClaimResponse From(string policyNumber, Claim claim) =>
        new(claim.ClaimNumber, policyNumber, claim.Status, claim.Amount, claim.FiledOn, claim.Description);
}

/// <summary>Body of a POST to <c>/api/claims</c>.</summary>
public class NewClaimRequest
{
    /// <summary>The policy the claim is filed against, e.g. <c>MM-AUTO-004417</c>.</summary>
    [Required]
    public string PolicyNumber { get; set; } = "";

    /// <summary>Amount claimed, in dollars.</summary>
    [Range(0.01, 1_000_000, ErrorMessage = "Enter a claim amount between $0.01 and $1,000,000.00.")]
    public decimal Amount { get; set; }

    /// <summary>What happened, in the member's own words.</summary>
    [Required]
    [StringLength(1000, MinimumLength = 10)]
    public string Description { get; set; } = "";
}

/// <summary>Result of filing a claim: the claim number the member should quote from now on.</summary>
public record ClaimCreatedResponse(
    string ClaimNumber,
    string PolicyNumber,
    ClaimStatus Status,
    DateTime FiledOn);
