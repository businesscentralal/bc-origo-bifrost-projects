namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.Comment;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Journal;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Activity;
using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Environment.Configuration;

/// <summary>Test-only native archive rights without the feature Full token; never assigned by the product.</summary>
permissionset 97132 "ProjArchiveNat ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        tabledata "Job Archive" = RIMD,
        tabledata "Job Task Archive" = RIMD,
        tabledata "Job Planning Line Archive" = RIMD,
        tabledata "Job" = RIMD,
        tabledata "Job Task" = RIMD,
        tabledata "Job Planning Line" = RIMD,
        tabledata "Jobs Setup" = RIMD,
        tabledata "Comment Line" = RIMD,
        tabledata "Comment Line Archive" = RIMD,
        tabledata "Job Ledger Entry" = RIMD,
        tabledata "Purchase Line" = RIMD,
        tabledata "Job Planning Line Invoice" = RIMD,
        tabledata "Reservation Entry" = RIMD,
        tabledata "Warehouse Activity Line" = RIMD,
        tabledata "Job Journal Line" = RIMD,
        tabledata "Record Link" = RIMD,
        codeunit "Projects Gate ori" = X,
        codeunit "Proj. Posting Gate ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Proj. Archive Impl ori" = X,
        codeunit "Proj. Archive Get Impl ori" = X,
        codeunit "Projects Archive ori" = X;
}
