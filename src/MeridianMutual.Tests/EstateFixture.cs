using MeridianMutual.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace MeridianMutual.Tests;

/// <summary>
/// Builds a throwaway policy database on disk and hands out the connection string, so tests
/// exercise the same SQLite code paths the portal uses at runtime.
/// </summary>
public sealed class EstateFixture : IDisposable
{
    private readonly string _databasePath;

    public EstateFixture()
    {
        _databasePath = Path.Combine(Path.GetTempPath(), $"meridianmutual-tests-{Guid.NewGuid():N}.db");
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
                ["ConnectionStrings:MeridianMutualDb"] = ConnectionString
            })
            .Build();

    public MeridianMutualDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<MeridianMutualDbContext>().UseSqlite(ConnectionString).Options);

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
