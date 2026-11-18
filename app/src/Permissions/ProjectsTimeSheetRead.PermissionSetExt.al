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
using Origo.Bifrost;
using System.Security.User;

/// <summary>Grants the moved time-sheet objects to the Foundation Read role.</summary>
permissionsetextension 70013581 "Projects TimeSheet Read ori" extends "BIFROST Read ori"
{
    Permissions =
        codeunit "TS Sheet Reopen Impl ori" = X,
        codeunit "TS Sheet Post Impl ori" = X,
        codeunit "TS Sheet Archive Impl ori" = X,
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
        codeunit "TS Native Mgt ori" = X,
        codeunit "TS Contract Parts ori" = X,
        codeunit "TS Native Context ori" = X,
        codeunit "TS Native Runner ori" = X,
        codeunit "TS Sheet Restrict ori" = X,
        codeunit "TS Sheet Approve Impl ori" = X,
        codeunit "TS Sheet Reject Impl ori" = X,
        codeunit "TS Absence Reg Impl ori" = X,
        codeunit "TS Sheet Create Impl ori" = X,
        codeunit "TS Create Contract ori" = X,
        codeunit "TS Create Restrict ori" = X,
        codeunit "TS Pending Approval ori" = X,
        codeunit "TS Sheet Submit Impl ori" = X,
        codeunit "TS Bulk Mgt ori" = X,
        codeunit "TS Post Confirm ori" = X,
        codeunit "TS Line Set Impl ori" = X,
        codeunit "TS Line Set Contract ori" = X,
        codeunit "TS Line Set Mgt ori" = X;
}
