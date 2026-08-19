using HalcourtMutual.Models.Api;
using HalcourtMutual.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HalcourtMutual.Controllers.Api;

/// <summary>
/// Member lookup for the servicing channels. Reads require the Entra <c>Claims.Read</c> app role;
/// the token is validated against the API's app registration. Nothing here should be pointed at
/// real policyholder data — it is a demonstration estate.
/// </summary>
[ApiController]
[Route("api/policyholders")]
[Produces("application/json")]
[Authorize(Roles = ApiRoles.Read)]
public class PolicyholdersApiController : ControllerBase
{
    private readonly PolicyService _policies;

    public PolicyholdersApiController(PolicyService policies)
    {
        _policies = policies;
    }

    /// <summary>Gets a policyholder by member id.</summary>
    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(PolicyholderResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public ActionResult<PolicyholderResponse> GetById(long id)
    {
        var policyholder = _policies.GetPolicyholder(id);

        return policyholder is null
            ? NotFound()
            : Ok(PolicyholderResponse.From(policyholder));
    }
}
