using MeridianMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers;

public class PoliciesController : Controller
{
    private readonly ILogger<PoliciesController> _logger;
    private readonly PolicyService _policies;
    private readonly PremiumService _premiums;
    private readonly ClaimService _claims;

    public PoliciesController(
        ILogger<PoliciesController> logger,
        PolicyService policies,
        PremiumService premiums,
        ClaimService claims)
    {
        _logger = logger;
        _policies = policies;
        _premiums = premiums;
        _claims = claims;
    }

    public IActionResult Index() => RedirectToAction("Index", "Home");

    public IActionResult Details(string id)
    {
        var policy = _policies.GetByPolicyNumber(id ?? "");

        if (policy is null)
        {
            _logger.LogWarning("Policy {PolicyNumber} was requested but does not exist.", id);
            return NotFound();
        }

        ViewData["Payments"] = _premiums.GetPayments(policy.Id);
        ViewData["Claims"] = _claims.GetClaims(policy.Id);

        return View(policy);
    }
}
