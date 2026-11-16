namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only role allows setup inspection and task handling, with no native report data rights.</summary>
permissionset 97127 "ProjReportTest ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        codeunit "Projects Gate ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Projects Report ori" = X,
        codeunit "Proj. Report Impl ori" = X;
}
