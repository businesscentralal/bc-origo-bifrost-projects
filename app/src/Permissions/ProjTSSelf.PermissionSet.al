namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Convenience bundle for employees who keep their own time sheets through Bifrost (#38, Architect ruling C, 18.11.2026).
/// Direct tabledata, like native BC time sheets: the user can also open time sheets in the client.
/// Separation is the sheet's owner identity, checked in code; the set carries no approval or posting data.
/// Assign together with BIFROST Read ori.
/// </summary>
permissionset 70013586 "PROJ TS SELF ori"
{
    Assignable = true;
    Caption = 'Projects Time Sheet Self', Comment = 'is-IS=Verkefni - eigin tímaskýrslur';
    Permissions =
        codeunit "TS Self Service Mgt ori" = X,
        codeunit "TS Native Mgt ori" = X,
        codeunit "TS Native Context ori" = X,
        codeunit "TS Native Runner ori" = X,
        codeunit "TS Contract Parts ori" = X,
        codeunit "TS Bulk Mgt ori" = X,
        tabledata "Time Sheet Header" = RIMD,
        tabledata "Time Sheet Line" = RIMD,
        tabledata "Time Sheet Detail" = RIMD,
        tabledata "Time Sheet Comment Line" = RIMD,
        tabledata Resource = R,
        tabledata "Resources Setup" = R,
        tabledata "User Setup" = R,
        tabledata Job = R,
        tabledata "Job Task" = R,
        tabledata "Resource Group" = R,
        tabledata "No. Series" = R,
        tabledata "No. Series Line" = RIM,
        tabledata "Accounting Period" = R,
        tabledata "My Time Sheets" = RIMD,
        report "Create Time Sheets" = X,
        codeunit "TS Create Writer ori" = X,
        codeunit "TS My Sheet Get Impl ori" = X,
        codeunit "TS My Sheet Create Impl ori" = X,
        codeunit "TS My Create Context ori" = X,
        codeunit "TS My Line Set Impl ori" = X,
        codeunit "TS My Line Set Runner ori" = X,
        codeunit "TS My Sheet Submit Impl ori" = X;
}
