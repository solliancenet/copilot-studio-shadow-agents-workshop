using MeridianMutual.Models;
using Microsoft.EntityFrameworkCore;

namespace MeridianMutual.Data;

public class MeridianMutualDbContext : DbContext
{
    public MeridianMutualDbContext(DbContextOptions<MeridianMutualDbContext> options)
        : base(options)
    {
    }

    public DbSet<Policyholder> Policyholders => Set<Policyholder>();

    public DbSet<Policy> Policies => Set<Policy>();

    public DbSet<PremiumPayment> PremiumPayments => Set<PremiumPayment>();

    public DbSet<Claim> Claims => Set<Claim>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Policyholder>(entity =>
        {
            entity.Property(p => p.Name).IsRequired();
            entity.Property(p => p.Email).IsRequired();
        });

        modelBuilder.Entity<Policy>(entity =>
        {
            entity.Property(p => p.PolicyNumber).IsRequired();
            entity.Property(p => p.CoverageSummary).IsRequired();

            // Enums are stored as text so the SQLite file stays readable.
            entity.Property(p => p.Type).HasConversion<string>().IsRequired();
            entity.Property(p => p.Status).HasConversion<string>().IsRequired();

            // Policy number is how both the portal and the API look a policy up.
            entity.HasIndex(p => p.PolicyNumber).IsUnique();

            entity.HasOne(p => p.Policyholder)
                .WithMany(h => h.Policies)
                .HasForeignKey(p => p.PolicyholderId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PremiumPayment>(entity =>
        {
            entity.Property(p => p.Method).HasConversion<string>().IsRequired();
            entity.Property(p => p.Status).HasConversion<string>().IsRequired();

            entity.HasOne(p => p.Policy)
                .WithMany(p => p.PremiumPayments)
                .HasForeignKey(p => p.PolicyId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Claim>(entity =>
        {
            entity.Property(c => c.ClaimNumber).IsRequired();
            entity.Property(c => c.Description).IsRequired();
            entity.Property(c => c.Status).HasConversion<string>().IsRequired();

            entity.HasIndex(c => c.ClaimNumber).IsUnique();

            entity.HasOne(c => c.Policy)
                .WithMany(p => p.Claims)
                .HasForeignKey(c => c.PolicyId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
