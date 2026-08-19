using HalcourtMutual.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace HalcourtMutual.Tests;

/// <summary>
/// Builds a throwaway policy database on disk and hands out the connection string, so tests
/// exercise the same SQLite code paths the portal uses at runtime.
/// </summary>
public sealed class EstateFixture : IDisposable
{
    private readonly string _databasePath;

    public EstateFixture()
    {
        _databasePath = Path.Combine(Path.GetTempPath(), $"halcourtmutual-tests-{Guid.NewGuid():N}.db");
        ConnectionString = $"Data Source={_databasePath}";

        using var db = CreateContext();
        db.Database.Migrate();
        PolicySeeder.Seed(db);
    }

    public string ConnectionString { get; }

    public IConfiguration Configuration =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:HalcourtMutualDb"] = ConnectionString
            })
            .Build();

    public HalcourtMutualDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<HalcourtMutualDbContext>().UseSqlite(ConnectionString).Options);

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();

        foreach (var path in new[] { _databasePath, $"{_databasePath}-wal", $"{_databasePath}-shm" })
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }
}
