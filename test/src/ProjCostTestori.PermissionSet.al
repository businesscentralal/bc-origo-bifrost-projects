namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Native project rights for the item cost permission tests; excludes the posting token.</summary>
permissionset 97133 "Proj Cost Test ori"
{
    Assignable = false;
    Permissions = tabledata Job = RIMD, tabledata "Job Ledger Entry" = RIMD, tabledata "Job Planning Line" = RIMD;
}
