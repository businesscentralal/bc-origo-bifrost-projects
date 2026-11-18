namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Role set for the time-sheet posting role (#38, Architect 18.11.2026), separate from Self and Approver.
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
        tabledata "Time Sheet Header" = rimd,
        tabledata "Time Sheet Line" = rimd,
        tabledata "Time Sheet Detail" = rimd,
        tabledata "Time Sheet Comment Line" = rimd,
        tabledata "Time Sheet Posting Entry" = ri,
        tabledata "Time Sheet Header Archive" = rimd,
        tabledata "Time Sheet Line Archive" = rimd,
        tabledata "Time Sheet Detail Archive" = rimd,
        tabledata "Time Sheet Cmt. Line Archive" = rimd,
        tabledata "Job Journal Template" = r,
        tabledata "Job Journal Batch" = r,
        tabledata "Job Journal Line" = rimd,
        tabledata Resource = r,
        tabledata "Resources Setup" = r,
        tabledata "User Setup" = r,
        tabledata Job = r,
        tabledata "Job Task" = r;
}
