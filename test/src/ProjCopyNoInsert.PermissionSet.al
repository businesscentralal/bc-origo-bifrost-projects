namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Test-only native read/modify rights without task insert permission.</summary>
permissionset 97176 "ProjCopyNoInsert ori"
{
    Assignable = false;
    Permissions = tabledata Job = R,
        tabledata "Job Task" = RM,
        tabledata "Job Planning Line" = RIMD;
}
