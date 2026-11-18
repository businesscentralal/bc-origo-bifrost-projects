namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Grants the Base Application data and objects that the Projects time-sheet message types (#33) read and write.
/// Assign it together with BIFROST Full ori. It holds the grants that a permission set extension may not add for
/// objects of another app (AS0110/AA0050, #65); the levels are those the Projects TimeSheet Full ori extension had.
/// </summary>
permissionset 70013589 "PROJ TS ADMIN"
{
    Assignable = true;
    Caption = 'Projects Time Sheet Admin', Comment = 'is-IS=Stjórnun tímaskýrslna verkefna';
    Permissions =
        tabledata "Resources Setup" = R,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = R,
        tabledata "Time Sheet Header" = RIMD,
        tabledata "Time Sheet Line" = RIMD,
        tabledata "Time Sheet Detail" = RIMD,
        tabledata "Time Sheet Comment Line" = RIMD,
        tabledata "Time Sheet Posting Entry" = RI,
        tabledata "Employee Absence" = RI,
        tabledata "Cause of Absence" = R,
        tabledata "Human Resource Unit of Measure" = R,
        tabledata "Human Resources Setup" = R,
        tabledata Employee = R,
        tabledata Resource = R,
        tabledata "User Setup" = R,
        report "Create Time Sheets" = X,
        tabledata "Resource Group" = R,
        tabledata "No. Series" = R,
        tabledata "No. Series Line" = RIM,
        tabledata "Accounting Period" = R,
        tabledata Job = R,
        tabledata "Time Sheet Header Archive" = RIMD,
        tabledata "Time Sheet Line Archive" = RIMD,
        tabledata "Time Sheet Detail Archive" = RIMD,
        tabledata "Time Sheet Cmt. Line Archive" = RIMD,
        tabledata "Job Journal Template" = R,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = RIMD;
}
