# MVC Areas

> A way to partition a large ASP.NET Core MVC application into distinct functional groups — each with its own controllers, views, and models folder structure — so that related features stay physically together without colliding with other parts of the app.

---

## Quick Reference

| | |
|---|---|
| **What it is** | Named folder namespaces that group controllers, views, and models |
| **Use when** | Large apps with distinct sections (Admin, Storefront, API, Account) |
| **Avoid when** | Small apps — the overhead of the folder structure adds noise without benefit |
| **Key attribute** | `[Area("AreaName")]` on the controller class |
| **Required** | Area route registered in `Program.cs` AND `[Area]` attribute on controller |
| **View path** | `Areas/{AreaName}/Views/{Controller}/{Action}.cshtml` |

---

## When To Use It

Use Areas when your application has multiple distinct sections with their own controllers, views, and logic that would clutter the root `Controllers/` and `Views/` folders. Good candidates are an admin panel, a customer-facing storefront, an API surface, and an account management section that all live in the same app but have nothing to share. Don't add Areas to a small app just to "organise" — if all your controllers fit comfortably in one folder, Areas add folder ceremony without payoff. Also avoid Areas when you're already using a microservices architecture where each section is its own deployable — Areas are an intra-app organisational tool, not a deployment boundary.

---

## Core Concept

An Area adds a third dimension to routing: `{area}/{controller}/{action}` instead of just `{controller}/{action}`. A controller belongs to an area by being decorated with `[Area("AreaName")]` and living in the corresponding folder under `Areas/`. The view engine looks for views under `Areas/{AreaName}/Views/` before falling back to `Views/Shared/`. The area route template must be registered in `Program.cs` alongside (and before) the default route.

Both sides must be in place — the `[Area]` attribute on the controller and the area route in `Program.cs`. Missing either one breaks the area silently: the `[Area]` attribute without a route means the controller is unreachable (404); an area route without the attribute on the controller means the route matches but the wrong controller is selected.

Cross-area links require specifying the area explicitly in `asp-area` — without it, the Tag Helper assumes the current area, which generates a broken link when navigating between areas.

---

## Version History

| ASP.NET Core Version | .NET Version | What changed |
|---|---|---|
| ASP.NET Core 1.0 | .NET Core 1.0 | Areas introduced, carried over from ASP.NET MVC 5 |
| ASP.NET Core 2.0 | .NET Core 2.0 | `[Area]` attribute replaces `AreaRegistration` class from MVC 5; no more `RegisterAllAreas()` |
| ASP.NET Core 3.0 | .NET Core 3.0 | Endpoint routing makes area routes work with `app.MapControllerRoute()` |
| ASP.NET Core 3.0 | .NET Core 3.0 | `_ViewStart.cshtml` per area supported; area-scoped `_ViewImports.cshtml` |
| ASP.NET Core 6.0 | .NET 6 | `MapAreaControllerRoute()` helper method added as shorthand |

*ASP.NET MVC 5 used `AreaRegistration` classes with a `RegisterArea()` method to register area routes. ASP.NET Core replaced this with simple `MapControllerRoute` calls in `Program.cs` and the `[Area]` attribute on controllers — no separate registration class needed.*

---

## The Code

**1. Folder structure for an app with an Admin area**
```
MyApp/
├── Areas/
│   └── Admin/
│       ├── Controllers/
│       │   ├── DashboardController.cs
│       │   └── UsersController.cs
│       ├── Views/
│       │   ├── Dashboard/
│       │   │   └── Index.cshtml
│       │   ├── Users/
│       │   │   ├── Index.cshtml
│       │   │   └── Edit.cshtml
│       │   └── Shared/
│       │       └── _AdminLayout.cshtml   ← area-specific layout
│       ├── _ViewStart.cshtml              ← sets Layout = "_AdminLayout" for admin views
│       └── _ViewImports.cshtml            ← area-scoped using statements
├── Controllers/
│   ├── HomeController.cs
│   └── ProductsController.cs
└── Views/
    ├── Home/
    ├── Products/
    └── Shared/
        └── _Layout.cshtml
```

**2. Controller with [Area] attribute**
```csharp
// Areas/Admin/Controllers/DashboardController.cs
[Area("Admin")]
[Authorize(Roles = "Admin")]
public class DashboardController : Controller
{
    // Accessible at: /admin/dashboard/index (with area route registered)
    public async Task<IActionResult> Index()
        => View(await dashboardService.GetSummaryAsync());

    // /admin/dashboard/activity
    public async Task<IActionResult> Activity()
        => View(await dashboardService.GetActivityAsync());
}

// Areas/Admin/Controllers/UsersController.cs
[Area("Admin")]
[Authorize(Roles = "Admin")]
public class UsersController : Controller
{
    public async Task<IActionResult> Index()  => View(await userService.GetAllAsync());
    public async Task<IActionResult> Edit(int id) => View(await userService.GetAsync(id));

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, EditUserDto dto)
    {
        if (!ModelState.IsValid) return View(dto);
        await userService.UpdateAsync(id, dto);
        return RedirectToAction(nameof(Index));
    }
}
```

**3. Registering area routes in Program.cs**
```csharp
// Program.cs
var app = builder.Build();

// Area route must come BEFORE the default route
app.MapControllerRoute(
    name:    "admin",
    pattern: "admin/{controller=Dashboard}/{action=Index}/{id?}",
    defaults: new { area = "Admin" },
    constraints: new { });

// Shorthand helper (ASP.NET Core 6+)
app.MapAreaControllerRoute(
    name:     "admin",
    areaName: "Admin",
    pattern:  "admin/{controller=Dashboard}/{action=Index}/{id?}");

// Default route — non-area controllers
app.MapControllerRoute(
    name:    "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
```

**4. Area-scoped _ViewStart.cshtml — different layout per area**
```cshtml
@* Areas/Admin/Views/_ViewStart.cshtml *@
@* Overrides the root Views/_ViewStart.cshtml for all admin views *@
@{
    Layout = "_AdminLayout";
}
```

**5. Generating links — asp-area is required for cross-area navigation**
```cshtml
@* Link within the same area (admin view linking to another admin page) *@
<a asp-action="Index" asp-controller="Users">Manage Users</a>
@* Generates: /admin/users — asp-area not needed when staying in the same area *@

@* Link FROM admin area TO the non-area storefront *@
<a asp-area="" asp-controller="Home" asp-action="Index">Back to site</a>
@* asp-area="" explicitly clears the area — without this, it would link to /admin/home/index *@

@* Link FROM the storefront TO the admin area *@
<a asp-area="Admin" asp-controller="Dashboard" asp-action="Index">Admin panel</a>
@* Generates: /admin/dashboard *@
```

**6. Url.Action() for cross-area links in controller code**
```csharp
// From within an Admin area controller — linking out to non-area controller
var homeUrl = Url.Action("Index", "Home", new { area = "" });
// homeUrl = "/"

// From a non-area controller — linking into the Admin area
var adminUrl = Url.Action("Index", "Dashboard", new { area = "Admin" });
// adminUrl = "/admin/dashboard"

// Redirect from one area to another
return RedirectToAction("Index", "Dashboard", new { area = "Admin" });
```

**7. Multiple areas — one app with Admin, Account, and API areas**
```csharp
// Program.cs
app.MapAreaControllerRoute("admin",   "Admin",   "admin/{controller=Dashboard}/{action=Index}/{id?}");
app.MapAreaControllerRoute("account", "Account", "account/{controller=Profile}/{action=Index}/{id?}");
app.MapControllers();  // API controllers use attribute routing — no area convention route needed
app.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");
```

```
Areas/
├── Admin/
│   ├── Controllers/
│   └── Views/
├── Account/
│   ├── Controllers/
│   └── Views/
└── Api/
    └── Controllers/   ← API controllers use [Route("api/...")] — no Views needed
```

---

## Real World Example

A school management system with three distinct user groups: students (public-facing portal), staff (internal management), and system admins (user and configuration management). Each group has its own layout, navigation, and features. Using Areas keeps each group's controllers and views physically separate while sharing common services and domain logic.

```csharp
// Areas/Staff/Controllers/AttendanceController.cs
[Area("Staff")]
[Authorize(Policy = "StaffOnly")]
public class AttendanceController : Controller
{
    public AttendanceController(IAttendanceService attendanceService)
        => _attendanceService = attendanceService;

    // /staff/attendance — default view shows today's classes
    public async Task<IActionResult> Index()
    {
        var vm = await _attendanceService.GetTodayAsync(User.GetStaffId());
        return View(vm);
    }

    // /staff/attendance/class/5
    [HttpGet("staff/attendance/class/{classId:int}")]
    public async Task<IActionResult> Class(int classId)
        => View(await _attendanceService.GetClassAsync(classId));

    [HttpPost("staff/attendance/class/{classId:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SubmitAttendance(int classId, AttendanceSubmitDto dto)
    {
        if (!ModelState.IsValid) return View("Class", await _attendanceService.GetClassAsync(classId));
        await _attendanceService.SubmitAsync(classId, dto, User.GetStaffId());
        TempData["Success"] = "Attendance saved.";
        return RedirectToAction(nameof(Index));
    }
}
```

```cshtml
@* Areas/Staff/Views/Shared/_StaffLayout.cshtml *@
@{
    Layout = "_Layout";  // nests inside the root layout for <html>/<head>/fonts
}

<div class="staff-shell">
    <aside class="staff-nav">
        <a asp-area="Staff" asp-controller="Dashboard" asp-action="Index">Dashboard</a>
        <a asp-area="Staff" asp-controller="Attendance" asp-action="Index">Attendance</a>
        <a asp-area="Staff" asp-controller="Grades"     asp-action="Index">Grades</a>

        @* Cross-area link — asp-area="" clears the area *@
        <a asp-area="" asp-controller="Home" asp-action="Index" class="text-muted">
            Student portal
        </a>
    </aside>

    <main class="staff-content">
        @RenderBody()
    </main>
</div>

@section Scripts { @RenderSection("Scripts", required: false) }
```

*The key insight: the staff layout nests inside `_Layout.cshtml` (for the shared `<html>` shell) while adding its own sidebar navigation. The cross-area link to the student portal uses `asp-area=""` to escape the staff area — without the empty string, the Tag Helper would generate `/staff/home/index` instead of `/home/index`. The `@section Scripts` forwarding in the staff layout is critical — without it, any page-specific scripts defined in staff views would be silently swallowed.*

---

## Common Misconceptions

**"Adding [Area] to a controller is enough to make it accessible at /area-name/..."**
The `[Area]` attribute alone does nothing to routing. It marks the controller as belonging to an area, but if there's no area route registered in `Program.cs`, the controller is unreachable — requests return 404. Both the `[Area]` attribute and the area route template in `Program.cs` are required.

**"Area views fall back to the root Views/Shared/ automatically"**
Area views have their own fallback order: `Areas/{Area}/Views/{Controller}/{Action}.cshtml` → `Areas/{Area}/Views/Shared/{Action}.cshtml` → `Views/Shared/{Action}.cshtml`. The root `Views/Shared/` is the last fallback — so area views can use shared layouts and partials from the root. But it's not a simple one-step fallback; the Razor view engine walks the area folder first.

**"You can link to another area just by specifying the controller and action"**
Without `asp-area`, the Tag Helper inherits the current area from the request. A link generated inside an admin view without `asp-area` will prepend `/admin/` to the target URL. To link to a non-area controller from an area view, you must explicitly set `asp-area=""`. To link to a different area, set `asp-area="OtherArea"`.

---

## Gotchas

- **Both `[Area("Name")]` on the controller AND an area route in `Program.cs` are required.** One without the other produces either a 404 (attribute without route) or incorrect controller selection (route without attribute). It's the most common areas setup mistake.

- **The area route must be registered before the default route.** The default `{controller}/{action}/{id?}` template is greedy and will match `/admin/dashboard` before the area route gets a chance. Register specific routes (including area routes) first, the default route last.

- **Cross-area links require explicit `asp-area` — inheriting the current area produces wrong URLs.** Without `asp-area=""` (or `asp-area="OtherArea"`), links generated from within an area view will include the current area in the URL. This silently produces broken links that render correctly as HTML but navigate to 404 pages.

- **Area `_ViewStart.cshtml` and `_ViewImports.cshtml` are scoped to the area folder.** An `Areas/Admin/_ViewImports.cshtml` applies to all views under `Areas/Admin/` and does not affect the root `Views/` folder. This lets you set a different layout, different `@using` statements, and different `@addTagHelper` directives per area — but it also means forgetting to add `@addTagHelper` in an area's `_ViewImports.cshtml` will silently disable Tag Helpers for that area only.

- **Renaming the `[Area("Name")]` string changes the URL.** Unlike `[controller]` tokens, the area name in the `[Area]` attribute is a literal string that must match what's in the route template. Changing `[Area("Admin")]` to `[Area("Administration")]` without updating `Program.cs` breaks routing silently.

- **Shared partials in `Views/Shared/` are accessible from area views, but partials in `Areas/{Area}/Views/Shared/` are not accessible from non-area views.** The fallback path is one-directional — area views fall back to the root; root views don't look in area folders.

---

## Interview Angle

**What they're really testing:** Whether you understand that Areas require both controller-side (`[Area]` attribute) and routing-side (route template in `Program.cs`) configuration — and the cross-area link generation trap.

**Common question forms:**
- *"What are MVC Areas and when would you use them?"*
- *"How do you generate a link from one area to another?"*
- *"I added [Area("Admin")] to my controller but it returns 404 — why?"*

**The depth signal:** A junior answer describes Areas as "folders for organising controllers." A senior answer explains that both the `[Area]` attribute and the area route template are required (missing either causes silent failures), why area routes must precede the default route in `Program.cs` (specificity), the cross-area `asp-area` requirement and what happens when it's missing (wrong URL silently generated), how `_ViewStart.cshtml` scoping per area enables different layouts, and the view fallback order (`Areas/{Area}/Views/{Controller}/` → `Areas/{Area}/Views/Shared/` → `Views/Shared/`).

**Follow-up questions to expect:**
- *"How would you share a partial view between two areas?"* (put it in `Views/Shared/` — accessible from all areas as the final fallback)
- *"What's the difference between Areas and separate projects/microservices?"* (Areas are an organisational tool within one app; separate projects are deployment boundaries)

---

## Related Topics

- [[dotnet/mvc/mvc-routing.md]] — Area routes are registered using the same `MapControllerRoute` mechanism; routing is the underlying system that makes areas work.
- [[dotnet/mvc/mvc-controllers.md]] — The `[Area]` attribute is applied to controller classes; understanding controllers is the prerequisite for understanding area controllers.
- [[dotnet/mvc/mvc-layout-sections.md]] — Area-specific `_ViewStart.cshtml` files set different layouts per area; nested layouts (area layout wrapping inside root layout) use the same section-forwarding patterns.
- [[dotnet/mvc/mvc-views.md]] — Area view discovery follows the same Razor view engine fallback order, extended with area-specific paths; `_ViewImports.cshtml` per area enables area-scoped `@using` and `@addTagHelper`.

---

## Source

https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/areas

---
*Last updated: 2026-04-09*