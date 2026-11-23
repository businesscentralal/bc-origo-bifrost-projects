namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;

/// <summary>
/// Grants the Base Application data that the Projects.Usage.* message types (projects#52) read and write.
/// Assign it together with BIFROST Full ori (or BIFROST Read ori for Projects.Usage.List). It holds the grants that a
/// permission set extension may not add for objects of another app (AS0110/AA0050, #65); the levels are those the
/// Projects Usage Full ori and Projects Usage Read ori extensions had.
/// </summary>
permissionset 70013402 "PROJ USAGE ori"
{
    Assignable = true;
    Caption = 'Projects Usage Registration', Comment = 'is-IS=Skráning notkunar verkefna';
    Permissions =
        tabledata "Time Sheet Header" = R,
        tabledata "Time Sheet Line" = R,
        tabledata Item = R,
        tabledata Resource = R,
        tabledata "Item Journal Template" = R,
        tabledata "Item Journal Batch" = R,
        tabledata "Item Journal Line" = RIMD,
        tabledata "Res. Journal Template" = R,
        tabledata "Res. Journal Batch" = R,
        tabledata "Res. Journal Line" = RIMD,
        tabledata "Job Journal Template" = R,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = RIMD,
        tabledata "Reservation Entry" = RIMD,
        tabledata "Item Tracking Code" = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "Res. Ledger Entry" = R,
        tabledata "Job Ledger Entry" = R;
}
