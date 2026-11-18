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
/// Role set for employees who keep their own time sheets through Bifrost (#38, Architect 18.11.2026).
/// Assign together with BIFROST Read ori. Grants only the four My* types; ownership is still checked in code.
/// </summary>
permissionset 70013586 "PROJ TS SELF"
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
        tabledata "Time Sheet Header" = rim,
        tabledata "Time Sheet Line" = rimd,
        tabledata "Time Sheet Detail" = rimd,
        tabledata "Time Sheet Comment Line" = rimd,
        tabledata Resource = r,
        tabledata "Resources Setup" = r,
        tabledata "User Setup" = r,
        tabledata Job = r,
        tabledata "Job Task" = r,
        tabledata "Resource Group" = r,
        tabledata "No. Series" = r,
        tabledata "No. Series Line" = rim,
        tabledata "Accounting Period" = r,
        report "Create Time Sheets" = X,
        codeunit "TS Create Writer ori" = X,
        codeunit "TS My Sheet Get Impl ori" = X,
        codeunit "TS My Sheet Create Impl ori" = X,
        codeunit "TS My Create Context ori" = X,
        codeunit "TS My Line Set Impl ori" = X,
        codeunit "TS My Line Set Runner ori" = X,
        codeunit "TS My Sheet Submit Impl ori" = X;
}
