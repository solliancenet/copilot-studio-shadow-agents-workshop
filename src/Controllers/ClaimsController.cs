using HalcourtMutual.Models.ViewModels;
using HalcourtMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace HalcourtMutual.Controllers;

/// <summary>
/// The adjuster-facing claim workspace: open a claim from the triage queue, review its policy
/// context, and generate an AI triage briefing from the Foundry Claims-Triage agent.
/// </summary>
public class ClaimsController : Controller
{
    private readonly ILogger<ClaimsController> _logger;
    private readonly ClaimService _claims;
    private readonly PremiumService _premiums;
    private readonly ClaimsTriageAgentService _agent;

    public ClaimsController(
        ILogger<ClaimsController> logger,
        ClaimService claims,
        PremiumService premiums,
        ClaimsTriageAgentService agent)
    {
        _logger = logger;
        _claims = claims;
        _premiums = premiums;
        _agent = agent;
    }

    /// <summary>Adjuster view for a single claim.</summary>
    public IActionResult Details(string id)
    {
        var claim = _claims.GetForAdjuster(id ?? "");

        if (claim is null)
        {
            _logger.LogWarning("Claim {ClaimNumber} was requested but does not exist.", id);
            return NotFound();
        }

        var model = new ClaimDetailViewModel
        {
            Claim = claim,
            Payments = claim.Policy is null ? new() : _premiums.GetPayments(claim.Policy.Id),
            PriorClaims = claim.Policy is null
                ? new()
                : _claims.GetClaims(claim.Policy.Id).Where(c => c.Id != claim.Id).ToList(),
            AgentConfigured = _agent.IsConfigured
        };

        return View(model);
    }

    /// <summary>
    /// Calls the Foundry Claims-Triage agent and re-renders the adjuster view with the briefing.
    /// </summary>
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> GenerateBriefing(string id, CancellationToken cancellationToken)
    {
        var claim = _claims.GetForAdjuster(id ?? "");

        if (claim is null)
        {
            return NotFound();
        }

        var model = new ClaimDetailViewModel
        {
            Claim = claim,
            Payments = claim.Policy is null ? new() : _premiums.GetPayments(claim.Policy.Id),
            PriorClaims = claim.Policy is null
                ? new()
                : _claims.GetClaims(claim.Policy.Id).Where(c => c.Id != claim.Id).ToList(),
            AgentConfigured = _agent.IsConfigured
        };

        try
        {
            model.Briefing = await _agent.GenerateBriefingAsync(claim.ClaimNumber, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Triage briefing failed for {ClaimNumber}.", claim.ClaimNumber);
            model.BriefingError =
                "The triage briefing could not be generated. Check the Foundry configuration and "
                + "that the app identity has the Foundry User role. Details: " + ex.Message;
        }

        return View(nameof(Details), model);
    }
}
