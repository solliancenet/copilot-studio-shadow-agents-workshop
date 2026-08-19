namespace HalcourtMutual.Models;

/// <summary>How the premium reached us.</summary>
public enum PaymentMethod
{
    AutoPay,
    Card,
    Check,
    BankTransfer
}

/// <summary>Where a premium payment sits in the billing cycle.</summary>
public enum PaymentStatus
{
    Pending,
    Cleared,
    Returned
}

/// <summary>
/// A premium payment against a policy. This is the record behind "did my premium clear?".
/// </summary>
public class PremiumPayment
{
    public long Id { get; set; }

    public long PolicyId { get; set; }

    public Policy? Policy { get; set; }

    public DateTime PaidOn { get; set; }

    public decimal Amount { get; set; }

    public PaymentMethod Method { get; set; }

    public PaymentStatus Status { get; set; }
}
