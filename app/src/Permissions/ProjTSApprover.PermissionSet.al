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
/// Convenience bundle for time-sheet approvers who work their queue through Bifrost (#38, Architect ruling C, 18.11.2026).
/// Direct tabledata. Role separation for approval is the sheet's approver identity, checked in code; the set carries no posting data.
/// Assign together with BIFROST Read ori.
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
        tabledata "Time Sheet Header" = RM,
        tabledata "Time Sheet Line" = RIMD,
        tabledata "Time Sheet Detail" = RIMD,
        tabledata "Time Sheet Comment Line" = RIMD,
        tabledata Resource = R,
        tabledata "Resources Setup" = R,
        tabledata "User Setup" = R,
        tabledata Job = R,
        tabledata "Job Task" = R,
        tabledata "Time Sheet Posting Entry" = RIMD,
        tabledata Employee = R,
        tabledata "Employee Absence" = RIMD,
        tabledata "Cause of Absence" = R,
        tabledata "Human Resources Setup" = R,
        tabledata "Human Resource Unit of Measure" = R,
        tabledata "Accounting Period" = R,
        codeunit "TS Approval Get Impl ori" = X,
        codeunit "TS Approval Approve Impl ori" = X,
        codeunit "TS Approval Reject Impl ori" = X;
}
