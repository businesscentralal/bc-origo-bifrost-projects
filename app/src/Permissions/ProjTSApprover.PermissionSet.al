namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.Period;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Role set for time-sheet approvers who work their queue through Bifrost (#38, Architect 18.11.2026).
/// Assign together with BIFROST Read ori. Grants only the three Approval types; the approver check stays in code.
/// </summary>
permissionset 70013587 "PROJ TS APPROVER"
{
    Assignable = true;
    Caption = 'Projects Time Sheet Approver', Comment = 'is-IS=Verkefni - samþykkjandi tímaskýrslna';
    Permissions =
        codeunit "TS Self Service Mgt ori" = X,
        codeunit "TS Native Mgt ori" = X,
        codeunit "TS Native Context ori" = X,
        codeunit "TS Native Runner ori" = X,
        codeunit "TS Contract Parts ori" = X,
        codeunit "TS Bulk Mgt ori" = X,
        tabledata "Time Sheet Header" = rm,
        tabledata "Time Sheet Line" = rimd,
        tabledata "Time Sheet Detail" = rimd,
        tabledata "Time Sheet Comment Line" = rimd,
        tabledata Resource = r,
        tabledata "Resources Setup" = r,
        tabledata "User Setup" = r,
        tabledata Job = r,
        tabledata "Job Task" = r,
        tabledata "Time Sheet Posting Entry" = ri,
        tabledata Employee = r,
        tabledata "Employee Absence" = ri,
        tabledata "Cause of Absence" = r,
        tabledata "Human Resources Setup" = r,
        tabledata "Human Resource Unit of Measure" = r,
        codeunit "TS Approval Get Impl ori" = X,
        codeunit "TS Approval Approve Impl ori" = X,
        codeunit "TS Approval Reject Impl ori" = X;
}
