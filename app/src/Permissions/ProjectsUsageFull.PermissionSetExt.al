namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;

/// <summary>Grants the time sheet usage objects and the journals they write to the Foundation Full role (projects#52).</summary>
permissionsetextension 70013400 "Projects Usage Full ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "TS Usage Line ori" = RIMD,
        page "TS Usage Lines ori" = X,
        codeunit "TS Usage Mgt ori" = X,
        codeunit "TS Usage Context ori" = X,
        codeunit "TS Usage Journal ori" = X,
        codeunit "TS Usage Runner ori" = X,
        codeunit "TS Usage Contract ori" = X,
        codeunit "TS Usage Restrict ori" = X,
        codeunit "TS Usage Register Impl ori" = X,
        codeunit "TS Usage Submit Impl ori" = X,
        codeunit "TS Usage Approve Impl ori" = X,
        codeunit "TS Usage Reject Impl ori" = X,
        codeunit "TS Usage Transfer Impl ori" = X,
        codeunit "TS Usage Reverse Impl ori" = X,
        codeunit "TS Usage List Impl ori" = X,
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
        tabledata "Item Ledger Entry" = R,
        tabledata "Res. Ledger Entry" = R,
        tabledata "Job Ledger Entry" = R;
}
