namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;

/// <summary>Test-only native rights deliberately exclude journal insert.</summary>
permissionset 97180 "ProjJnlNoInsert ori"
{
    Assignable = false;
    Permissions = tabledata Job = R,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = RM,
        tabledata "Job Journal Template" = R,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = RM;
}
