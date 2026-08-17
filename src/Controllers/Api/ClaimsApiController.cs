using MeridianMutual.Models.Api;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers.Api;

/// <summary>
/// Claim lookup and first notice of loss. No authentication — see
/// <see cref="PolicyholdersApiController"/>.
/// </summary>
[ApiController]
[Route("api/claims")]
[Produces("application/json")]
public class ClaimsApiController : ControllerBase
{
    private readonly PolicyService _policies;
    private readonly ClaimService _claims;

    public ClaimsApiController(PolicyService policies, ClaimService claims)
    {
        _policies = policies;
        _claims = claims;
    }

    /// <summary>Lists the claims filed against a policy, newest first.</summary>
    /// <param name="policyNumber">Policy number, e.g. <c>MM-AUTO-004417</c>.</param>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<ClaimResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<IEnumerable<ClaimResponse>> GetByPolicy([FromQuery] string policyNumber)
    {
        var policy = _policies.GetByPolicyNumber(policyNumber);

        if (policy is null)
        {
            return NotFound();
        }

        return Ok(_claims.GetClaims(policy.Id)
            .Select(claim => ClaimResponse.From(policy.PolicyNumber, claim)));
    }

    /// <summary>Gets a single claim by its claim number.</summary>
    /// <param name="claimNumber">Claim number, e.g. <c>CLM-2026-00841</c>.</param>
    [HttpGet("{claimNumber}")]
    [ProducesResponseType(typeof(ClaimResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<ClaimResponse> GetByClaimNumber(string claimNumber)
    {
        var claim = _claims.GetByClaimNumber(claimNumber);

        return claim is null
            ? NotFound()
            : Ok(ClaimResponse.From(claim.Policy?.PolicyNumber ?? "", claim));
    }

    /// <summary>Files a new claim against a policy and returns the new claim number.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(ClaimCreatedResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public ActionResult<ClaimCreatedResponse> Create([FromBody] NewClaimRequest request)
    {
        var policy = _policies.GetByPolicyNumber(request.PolicyNumber);

        if (policy is null)
        {
            ModelState.AddModelError(nameof(request.PolicyNumber), "No policy with that number.");
            return ValidationProblem(ModelState);
        }

        var claimNumber = _claims.CreateClaim(policy.Id, request.Amount, request.Description.Trim());
        var claim = _claims.GetByClaimNumber(claimNumber)!;

        return CreatedAtAction(
            nameof(GetByClaimNumber),
            new { claimNumber },
            new ClaimCreatedResponse(claimNumber, policy.PolicyNumber, claim.Status, claim.FiledOn));
    }
}
