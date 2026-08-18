using MeridianMutual.Models.Api;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers.Api;

/// <summary>
/// Policy and premium lookup for the servicing channels. Every read requires the Entra
/// <c>Claims.Read</c> app role — see <see cref="PolicyholdersApiController"/>.
/// </summary>
[ApiController]
[Route("api/policies")]
[Produces("application/json")]
[Authorize(Roles = ApiRoles.Read)]
public class PoliciesApiController : ControllerBase
{
    private readonly PolicyService _policies;
    private readonly PremiumService _premiums;

    public PoliciesApiController(PolicyService policies, PremiumService premiums)
    {
        _policies = policies;
        _premiums = premiums;
    }

    /// <summary>Lists the policies held by a member.</summary>
    /// <param name="policyholderId">Member id to list policies for.</param>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<PolicyResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<IEnumerable<PolicyResponse>> GetByPolicyholder([FromQuery] long policyholderId)
    {
        if (_policies.GetPolicyholder(policyholderId) is null)
        {
            return NotFound();
        }

        return Ok(_policies.GetByPolicyholder(policyholderId).Select(PolicyResponse.From));
    }

    /// <summary>Gets a single policy by its policy number.</summary>
    /// <param name="policyNumber">Policy number, e.g. <c>MM-AUTO-004417</c>.</param>
    [HttpGet("{policyNumber}")]
    [ProducesResponseType(typeof(PolicyResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<PolicyResponse> GetByPolicyNumber(string policyNumber)
    {
        var policy = _policies.GetByPolicyNumber(policyNumber);

        return policy is null
            ? NotFound()
            : Ok(PolicyResponse.From(policy));
    }

    /// <summary>
    /// Lists the premium payments recorded against a policy, newest first — the record behind
    /// "did my premium clear this month?".
    /// </summary>
    /// <param name="policyNumber">Policy number, e.g. <c>MM-AUTO-004417</c>.</param>
    [HttpGet("{policyNumber}/premium-payments")]
    [ProducesResponseType(typeof(IEnumerable<PremiumPaymentResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<IEnumerable<PremiumPaymentResponse>> GetPremiumPayments(string policyNumber)
    {
        var policy = _policies.GetByPolicyNumber(policyNumber);

        if (policy is null)
        {
            return NotFound();
        }

        return Ok(_premiums.GetPayments(policy.Id)
            .Select(payment => PremiumPaymentResponse.From(policy.PolicyNumber, payment)));
    }
}
