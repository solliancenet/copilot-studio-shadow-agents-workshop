namespace HalcourtMutual.Models;

/// <summary>A member of the mutual. One policyholder can hold several policies.</summary>
public class Policyholder
{
    public long Id { get; set; }

    public string Name { get; set; } = "";

    public string Email { get; set; } = "";

    public DateTime MemberSince { get; set; }

    public List<Policy> Policies { get; set; } = new();
}
