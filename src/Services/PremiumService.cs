using HalcourtMutual.Data;
using HalcourtMutual.Models;

namespace HalcourtMutual.Services;

public class PremiumService
{
    private readonly HalcourtMutualDbContext _db;

    public PremiumService(HalcourtMutualDbContext db)
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
