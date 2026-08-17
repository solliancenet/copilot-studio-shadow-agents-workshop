using MeridianMutual.Models.Api;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers.Api;

/// <summary>
/// Member lookup for the servicing channels.
///
/// The member API carries no authentication: this is a self-contained demo estate, and the
/// endpoints are deliberately reachable by any caller that can see the host. Nothing here
/// should be pointed at real policyholder data.
/// </summary>
[ApiController]
[Route("api/policyholders")]
[Produces("application/json")]
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
