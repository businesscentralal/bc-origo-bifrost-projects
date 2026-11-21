namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Microsoft.Sales.Customer;
using Microsoft.Warehouse.Structure;
using System.Security.User;

/// <summary>
/// Technician self-service with project/site/stock reads and own usage registration (#82).
/// Direct tabledata, like native BC time sheets: the user can also open time sheets in the client.
/// Separation is the sheet's owner identity, checked in code; the set carries no approval or posting data.
/// Assign together with BIFROST Read ori.
/// </summary>
permissionset 70013403 "PROJ FIELD TECH"
{
    Assignable = true;
    Caption = 'Projects Field Technician', Comment = 'is-IS=Verkefni - vettvangstæknimaður';
    IncludedPermissionSets = "PROJ TS SELF", "PROJ VISIT";
    Permissions =
        tabledata "Job Planning Line" = R,
        tabledata Customer = R,
        tabledata "Ship-to Address" = R,
        tabledata Item = R,
        tabledata "Item Reference" = R,
        tabledata Location = R,
        tabledata "Bin Content" = R,
        tabledata "Stockkeeping Unit" = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "TS Usage Line ori" = RIM,
        tabledata Bin = R,
        tabledata "Item Tracking Code" = R,
        tabledata "Item Unit of Measure" = R,
        tabledata "Proj. Technician Setup ori" = R,
        codeunit "Proj. VisitItem Reg Impl ori" = X,
        codeunit "Proj. VanStock Get Impl ori" = X,
        codeunit "Proj. Van Mgt ori" = X,
        codeunit "Proj. Van Runner ori" = X,
        codeunit "Proj. Van Contract ori" = X,
        codeunit "TS Usage Context ori" = X,
        codeunit "TS Usage Runner ori" = X;
}
