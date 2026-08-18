using System.Diagnostics;
using MeridianMutual.Models;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly ClaimService _claims;

    public HomeController(ILogger<HomeController> logger, ClaimService claims)
    {
        _logger = logger;
        _claims = claims;
    }

    /// <summary>The triage queue — the adjuster's landing page.</summary>
    public IActionResult Index()
    {
        _logger.LogInformation("Loading the triage queue");
        return View(_claims.GetTriageQueue());
    }

    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
