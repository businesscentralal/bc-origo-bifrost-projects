namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Sales.Customer;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;
using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only native purchase and inventory rights without Full or reservation rights; never assigned by the product.</summary>
permissionset 97129 "ProjUsageTest ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        tabledata "Proj. Posting ori" = R,
        tabledata "Purchase Line" = RIMD,
        tabledata "Purchase Header" = R,
        tabledata Job = RIMD,
        tabledata Customer = R,
        tabledata "Job Journal Line" = RIMD,
        tabledata "Job Ledger Entry" = RIMD,
        tabledata "Job Register" = RIMD,
        tabledata Item = RIMD,
        tabledata "Item Variant" = R,
        tabledata Location = R,
        tabledata Bin = R,
        tabledata "Item Unit of Measure" = R,
        tabledata "Item Ledger Entry" = RIMD,
        tabledata "Item Register" = RIMD,
        tabledata "Value Entry" = RIMD,
        tabledata "Item Application Entry" = RIMD,
        tabledata "G/L Entry" = RIMD,
        tabledata "G/L Register" = RIMD,
        tabledata "Warehouse Entry" = RIMD,
        tabledata "Warehouse Register" = RIMD,
        tabledata "Bin Content" = RIMD,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = RIMD,
        codeunit "Projects Gate ori" = X,
        codeunit "Proj. Posting Gate ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Projects Purchase ori" = X,
        codeunit "Projects Item Usage ori" = X,
        codeunit "Proj. Purchase Impl ori" = X,
        codeunit "Proj. Item Usage Impl ori" = X;
}
