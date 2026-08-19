using System.Globalization;
using HalcourtMutual.Data;
using HalcourtMutual.Models;
using Microsoft.EntityFrameworkCore;

namespace HalcourtMutual.Services;

public class ClaimService
{
    private readonly HalcourtMutualDbContext _db;
    private readonly ILogger<ClaimService> _logger;

    public ClaimService(HalcourtMutualDbContext db, ILogger<ClaimService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>
    /// The triage queue: claims that still need an adjuster — anything Open or UnderReview —
    /// with policy and policyholder context loaded, newest filing first. Read straight from the
    /// app's own data layer, not the member API.
    /// </summary>
    public List<Claim> GetTriageQueue() =>
        _db.Claims
            .Include(c => c.Policy!)
                .ThenInclude(p => p.Policyholder)
            .Where(c => c.Status == ClaimStatus.Open || c.Status == ClaimStatus.UnderReview)
            .OrderByDescending(c => c.FiledOn)
            .ToList();

    /// <summary>A single claim with its policy and policyholder context, for the adjuster view.</summary>
    public Claim? GetForAdjuster(string claimNumber) =>
        _db.Claims
            .Include(c => c.Policy!)
                .ThenInclude(p => p.Policyholder)
            .FirstOrDefault(c => c.ClaimNumber == claimNumber);

    /// <summary>Claims filed against a policy, newest first.</summary>
    public List<Claim> GetClaims(long policyId) =>
        _db.Claims
            .Where(c => c.PolicyId == policyId)
            .OrderByDescending(c => c.FiledOn)
            .ToList();

    public Claim? GetByClaimNumber(string claimNumber) =>
        _db.Claims
            .Include(c => c.Policy)
            .FirstOrDefault(c => c.ClaimNumber == claimNumber);

    /// <summary>
    /// Files a new claim against a policy and returns the claim number the member should quote.
    /// New claims start in <see cref="ClaimStatus.Open"/> until an adjuster picks them up.
    /// </summary>
    public string CreateClaim(long policyId, decimal amount, string description)
    {
        // Unspecified kind, so the date a caller gets back from POST /api/claims is byte-for-byte
        // the one it gets when it reads the claim again.
        var filedOn = DateTime.SpecifyKind(DateTime.Today, DateTimeKind.Unspecified);

        var claim = new Claim
        {
            ClaimNumber = NextClaimNumber(filedOn.Year),
            PolicyId = policyId,
            Status = ClaimStatus.Open,
            Amount = amount,
            FiledOn = filedOn,
            Description = description
        };

        _db.Claims.Add(claim);
        _db.SaveChanges();

        _logger.LogInformation("Filed claim {ClaimNumber} for {Amount} against policy {PolicyId}.",
            claim.ClaimNumber, claim.Amount, policyId);

        return claim.ClaimNumber;
    }

    /// <summary>
    /// Transitions a claim to a decided status and records the rationale in the log. Returns the
    /// updated claim (with policy context loaded) or <c>null</c> if no claim has that number.
    /// This is the write behind <c>PUT /api/claims/{claimNumber}/status</c>.
    /// </summary>
    public Claim? UpdateStatus(string claimNumber, ClaimStatus newStatus, string? rationale)
    {
        var claim = _db.Claims
            .Include(c => c.Policy)
            .FirstOrDefault(c => c.ClaimNumber == claimNumber);

        if (claim is null)
        {
            return null;
        }

        var previousStatus = claim.Status;
        claim.Status = newStatus;
        _db.SaveChanges();

        _logger.LogInformation(
            "Transitioned claim {ClaimNumber} from {PreviousStatus} to {NewStatus}. Rationale: {Rationale}",
            claim.ClaimNumber, previousStatus, newStatus, rationale ?? "(none)");

        return claim;
    }

    /// <summary>
    /// Claim numbers run <c>CLM-{year}-{sequence}</c>, with the sequence continuing from the
    /// highest one already issued this year.
    /// </summary>
    private string NextClaimNumber(int year)
    {
        var prefix = $"CLM-{year}-";

        var highest = _db.Claims
            .Where(c => c.ClaimNumber.StartsWith(prefix))
            .Select(c => c.ClaimNumber)
            .AsEnumerable()
            .Select(number => int.TryParse(number[prefix.Length..], NumberStyles.None, CultureInfo.InvariantCulture, out var sequence)
                ? sequence
                : 0)
            .DefaultIfEmpty(0)
            .Max();

        return $"{prefix}{highest + 1:D5}";
    }
}
