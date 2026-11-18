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
using Microsoft.Service.Document;
using Microsoft.Utilities;
using Origo.Bifrost;
using System.Security.User;

/// <summary>Grants the moved time-sheet objects and their data to the Foundation Full role.</summary>
permissionsetextension 70013580 "Projects TimeSheet Full ori" extends "BIFROST Full ori"
{
    Permissions =
        codeunit "TS Absence Mgt ori" = X,
        codeunit "TS Absence Contract ori" = X,
        codeunit "TS Absence Context ori" = X,
        codeunit "TS Absence Runner ori" = X,
        codeunit "TS Fill Mgt ori" = X,
        codeunit "TS Fill Context ori" = X,
        codeunit "TS Fill Runner ori" = X,
        codeunit "TS Fill Contract ori" = X,
        codeunit "TS Line CopyPrev Impl ori" = X,
        codeunit "TS Line FromPlan Impl ori" = X,
        tabledata "Resources Setup" = R,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = R,
        codeunit "TS Native Mgt ori" = X,
        codeunit "TS Contract Parts ori" = X,
        codeunit "TS Native Context ori" = X,
        codeunit "TS Native Runner ori" = X,
        codeunit "TS Sheet Restrict ori" = X,
        codeunit "TS Sheet Approve Impl ori" = X,
        codeunit "TS Sheet Reject Impl ori" = X,
        tabledata "Time Sheet Header" = RIMD,
        tabledata "Time Sheet Line" = RIMD,
        tabledata "Time Sheet Detail" = RIMD,
        tabledata "Time Sheet Comment Line" = RIMD,
        codeunit "TS Pending Approval ori" = X,
        tabledata "Time Sheet Posting Entry" = RI,
        tabledata "Employee Absence" = RI,
        tabledata "Cause of Absence" = R,
        tabledata "Human Resource Unit of Measure" = R,
        tabledata "Human Resources Setup" = R,
        tabledata Employee = R,
        tabledata Resource = R,
        tabledata "User Setup" = R,
        codeunit "TS Sheet Create Impl ori" = X,
        codeunit "TS Create Contract ori" = X,
        codeunit "TS Create Writer ori" = X,
        codeunit "TS Create Restrict ori" = X,
        report "Create Time Sheets" = X,
        tabledata "Resource Group" = R,
        tabledata "No. Series" = R,
        tabledata "No. Series Line" = RIM,
        tabledata "Accounting Period" = R,
        tabledata Job = R,
        codeunit "TS Sheet Reopen Impl ori" = X,
        codeunit "TS Sheet Post Impl ori" = X,
        codeunit "TS Sheet Archive Impl ori" = X,
        tabledata "Time Sheet Header Archive" = RIMD,
        tabledata "Time Sheet Line Archive" = RIMD,
        tabledata "Time Sheet Detail Archive" = RIMD,
        tabledata "Time Sheet Cmt. Line Archive" = RIMD,
        tabledata "Job Journal Template" = R,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = RIMD,
        codeunit "TS Absence Reg Impl ori" = X,
        codeunit "TS Sheet Submit Impl ori" = X,
        codeunit "TS Bulk Mgt ori" = X,
        codeunit "TS Post Confirm ori" = X,
        codeunit "TS Line Set Impl ori" = X,
        codeunit "TS Line Set Contract ori" = X,
        codeunit "TS Line Set Mgt ori" = X,
        codeunit "TS Line Set Runner ori" = X,
        codeunit "TS Line Set Context ori" = X,
        tabledata "Service Header" = R,
        tabledata "Work Type" = R;
}
