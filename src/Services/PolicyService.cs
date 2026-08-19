using HalcourtMutual.Data;
using HalcourtMutual.Models;
using Microsoft.EntityFrameworkCore;

namespace HalcourtMutual.Services;

public class PolicyService
{
    private readonly HalcourtMutualDbContext _db;

    public PolicyService(HalcourtMutualDbContext db)
    {
        _db = db;
    }

    public Policyholder? GetPolicyholder(long id) =>
        _db.Policyholders.FirstOrDefault(h => h.Id == id);

    /// <summary>
    /// The member the portal is signed in as. The pilot has no identity provider yet and the
    /// demonstration estate seeds exactly one policyholder.
    /// </summary>
    public Policyholder? GetSignedInPolicyholder() =>
        _db.Policyholders.OrderBy(h => h.Id).FirstOrDefault();

    /// <summary>Every policy held by a member, newest line of business first.</summary>
    public List<Policy> GetByPolicyholder(long policyholderId) =>
        _db.Policies
            .Where(p => p.PolicyholderId == policyholderId)
            .OrderBy(p => p.Type)
            .ToList();

    public Policy? GetByPolicyNumber(string policyNumber) =>
        _db.Policies
            .Include(p => p.Policyholder)
            .FirstOrDefault(p => p.PolicyNumber == policyNumber);
}
