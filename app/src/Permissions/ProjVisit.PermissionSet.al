namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Utilities;

/// <summary>
/// Assignable delta for field visits (projects#83). Assign together with BIFROST Read ori and PROJ TS SELF ori.
/// PROJ FIELD TECH ori includes this set.
/// No project journal tabledata. Delete is included because Record.WritePermission is false without it.
/// </summary>
permissionset 70013443 "PROJ VISIT ori"
{
    Assignable = true;
    Caption = 'Projects Field Visit', Comment = 'is-IS=Verkefni - vettvangsheimsókn';
    Permissions =
        tabledata "Proj. Field Visit ori" = RIMD,
        tabledata "TS Usage Line ori" = RIMD,
        tabledata Job = R,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = R,
        tabledata "Work Type" = R,
        tabledata Resource = R,
        tabledata "Projects Setup ori" = R,
        codeunit "Proj. Visit Start Impl ori" = X,
        codeunit "Proj. Visit Stop Impl ori" = X,
        codeunit "Proj. Visit Complete Impl ori" = X,
        codeunit "Proj. Visit Mgt ori" = X,
        codeunit "Proj. Visit Runner ori" = X,
        codeunit "Proj. Visit Contract ori" = X,
        codeunit "Proj. Visit Restrict ori" = X;
}
