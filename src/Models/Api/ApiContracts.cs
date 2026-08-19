using System.ComponentModel.DataAnnotations;

namespace HalcourtMutual.Models.Api;

/// <summary>
/// Entra app-role names exposed by the member API, and required by the API controllers. These
/// strings must match the app roles defined on the API's app registration (see
/// <c>infra/</c> and the Entra setup) — they arrive in the <c>roles</c> claim of the caller's token.
/// </summary>
public static class ApiRoles
{
    /// <summary>Read the estate: claims, policies, premium history, policyholders, and file a claim.</summary>
    public const string Read = "Claims.Read";

    /// <summary>Decide a claim (transition to Approved/Denied). Not granted to the triage agent.</summary>
    public const string Write = "Claims.Write";
}

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

/// <summary>Body of a PUT to <c>/api/claims/{claimNumber}/status</c>: an adjuster's decision.</summary>
public class UpdateClaimStatusRequest
{
    /// <summary>The decided status to move the claim to. Must be <c>Approved</c> or <c>Denied</c>.</summary>
    [Required]
    public ClaimStatus NewStatus { get; set; }

    /// <summary>Optional free-text rationale recorded with the decision.</summary>
    [StringLength(1000)]
    public string? Rationale { get; set; }
}

/// <summary>Result of filing a claim: the claim number the member should quote from now on.</summary>
public record ClaimCreatedResponse(
    string ClaimNumber,
    string PolicyNumber,
    ClaimStatus Status,
    DateTime FiledOn);
