using MeridianMutual.Services;

namespace MeridianMutual.Models.ViewModels;

/// <summary>Everything the adjuster claim view needs: the claim, its context, and any briefing.</summary>
public class ClaimDetailViewModel
{
    public required Claim Claim { get; set; }

    public List<PremiumPayment> Payments { get; set; } = new();

    /// <summary>Other claims on the same policy (prior claims history / anomaly context).</summary>
    public List<Claim> PriorClaims { get; set; } = new();

    /// <summary>Whether the Foundry agent is configured (drives whether the button is enabled).</summary>
    public bool AgentConfigured { get; set; }

    /// <summary>The generated briefing, when one has been produced this request.</summary>
    public TriageBriefing? Briefing { get; set; }

    /// <summary>A user-facing error if briefing generation failed.</summary>
    public string? BriefingError { get; set; }
}
