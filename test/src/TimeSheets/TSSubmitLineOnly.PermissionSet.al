namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.Period;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Non-assignable mock role deliberately omits native detail modify access.</summary>
permissionset 97136 "TS SUBMIT LINE ONLY"
{
    Assignable = false;
    Access = Internal;
    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Time Sheet Header" = R,
        tabledata "Time Sheet Line" = RM,
        tabledata "Time Sheet Detail" = R,
        tabledata Resource = R,
        tabledata "Resources Setup" = R,
        tabledata Job = R,
        tabledata "Accounting Period" = R,
        codeunit "TS Sheet Submit Impl ori" = X,
        codeunit "TS Native Mgt ori" = X;
}
