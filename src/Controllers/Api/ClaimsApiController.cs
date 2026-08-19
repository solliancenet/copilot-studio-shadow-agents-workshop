using HalcourtMutual.Models;
using HalcourtMutual.Models.Api;
using HalcourtMutual.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HalcourtMutual.Controllers.Api;

/// <summary>
/// Claim lookup, first notice of loss, and claim-status transitions. Every operation is gated by
/// an Entra app role: reads and first-notice-of-loss require <c>Claims.Read</c>; the status write
/// requires <c>Claims.Write</c>. The Foundry triage agent's identity holds only <c>Claims.Read</c>,
/// so a status write from the agent is refused at the RBAC layer (401) — not by prompt wording.
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
    [Authorize(Roles = ApiRoles.Read)]
    [ProducesResponseType(typeof(IEnumerable<ClaimResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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
    [Authorize(Roles = ApiRoles.Read)]
    [ProducesResponseType(typeof(ClaimResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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
    [Authorize(Roles = ApiRoles.Read)]
    [ProducesResponseType(typeof(ClaimCreatedResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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

    /// <summary>
    /// Transitions a claim to a decided status (<c>Approved</c> or <c>Denied</c>). This is the only
    /// mutation that changes an adjuster's decision, so it is gated behind the <c>Claims.Write</c>
    /// app role. The triage agent is deliberately not granted that role: this endpoint is the
    /// hard stop that proves the agent brief-only boundary in identity, not in prose.
    /// </summary>
    /// <param name="claimNumber">Claim number to transition, e.g. <c>CLM-2026-00841</c>.</param>
    /// <param name="request">The decision: the new status (Approved/Denied) and optional rationale.</param>
    [HttpPut("{claimNumber}/status")]
    [Authorize(Roles = ApiRoles.Write)]
    [ProducesResponseType(typeof(ClaimResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<ClaimResponse> UpdateStatus(string claimNumber, [FromBody] UpdateClaimStatusRequest request)
    {
        if (request.NewStatus is not (ClaimStatus.Approved or ClaimStatus.Denied))
        {
            ModelState.AddModelError(nameof(request.NewStatus),
                "A claim decision must transition the claim to Approved or Denied.");
            return ValidationProblem(ModelState);
        }

        var claim = _claims.UpdateStatus(claimNumber, request.NewStatus, request.Rationale?.Trim());

        return claim is null
            ? NotFound()
            : Ok(ClaimResponse.From(claim.Policy?.PolicyNumber ?? "", claim));
    }
}
