namespace Origo.Bifrost.Projects;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Convenience bundle for the time-sheet posting role (#38, Architect ruling C, 18.11.2026). Direct tabledata.
/// Posting is separated by journal and posting rights: only this set carries the journal, ledger and register data a post needs.
/// Assign together with BIFROST Read ori. Grants the Projects.TimeSheet.Post and .Archive types; #38 PR (b) adds PreviewPost and the one-call Post here.
/// </summary>
permissionset 70013588 "PROJ TS POST"
{
    Assignable = true;
    Caption = 'Projects Time Sheet Post', Comment = 'is-IS=Verkefni - bókun tímaskýrslna';
    Permissions =
        codeunit "TS Native Mgt ori" = X,
        codeunit "TS Native Context ori" = X,
        codeunit "TS Native Runner ori" = X,
        codeunit "TS Contract Parts ori" = X,
        codeunit "TS Bulk Mgt ori" = X,
        codeunit "TS Post Confirm ori" = X,
        codeunit "TS Sheet Post Impl ori" = X,
        codeunit "TS Sheet Archive Impl ori" = X,
        tabledata "Time Sheet Header" = RIMD,
        tabledata "Time Sheet Line" = RIMD,
        tabledata "Time Sheet Detail" = RIMD,
        tabledata "Time Sheet Comment Line" = RIMD,
        tabledata "Time Sheet Posting Entry" = RIMD,
        tabledata "Time Sheet Header Archive" = RIMD,
        tabledata "Time Sheet Line Archive" = RIMD,
        tabledata "Time Sheet Detail Archive" = RIMD,
        tabledata "Time Sheet Cmt. Line Archive" = RIMD,
        tabledata "Job Journal Template" = R,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = RIMD,
        tabledata Resource = R,
        tabledata "Resources Setup" = R,
        tabledata "User Setup" = R,
        tabledata Job = RIMD,
        tabledata "Job Task" = R,
        tabledata "General Ledger Setup" = R,
        tabledata "Jobs Setup" = R,
        tabledata "Job Ledger Entry" = RIMD,
        tabledata "Job Planning Line" = RIMD,
        tabledata "Job Register" = RIMD,
        tabledata "Res. Ledger Entry" = RIMD,
        tabledata "Resource Register" = RIMD,
        tabledata "No. Series" = R,
        tabledata "No. Series Line" = RIMD,
        tabledata "Job Entry No." = rim,
        tabledata "Job Usage Link" = RI,
        tabledata "Dimension Set Entry" = ri,
        tabledata "Dimension Set Tree Node" = rim;
}
