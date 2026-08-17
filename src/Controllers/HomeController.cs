using System.Diagnostics;
using MeridianMutual.Models;
using MeridianMutual.Services;
using Microsoft.AspNetCore.Mvc;

namespace MeridianMutual.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly PolicyService _policies;

    public HomeController(ILogger<HomeController> logger, PolicyService policies)
    {
        _logger = logger;
        _policies = policies;
    }

    public IActionResult Index()
    {
        _logger.LogInformation("Loading the policy summary");

        var member = _policies.GetSignedInPolicyholder();

        if (member is null)
        {
            return View(new List<Policy>());
        }

        ViewData["Member"] = member;
        return View(_policies.GetByPolicyholder(member.Id));
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
