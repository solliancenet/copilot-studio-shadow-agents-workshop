using MeridianMutual.Data;
using MeridianMutual.Models;

namespace MeridianMutual.Services;

public class PremiumService
{
    private readonly MeridianMutualDbContext _db;

    public PremiumService(MeridianMutualDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Premium payments for a policy, newest first. This is the record behind the
    /// "did my premium clear this month?" question the member portal has to answer.
    /// </summary>
    public List<PremiumPayment> GetPayments(long policyId) =>
        _db.PremiumPayments
            .Where(p => p.PolicyId == policyId)
            .OrderByDescending(p => p.PaidOn)
            .ToList();
}
