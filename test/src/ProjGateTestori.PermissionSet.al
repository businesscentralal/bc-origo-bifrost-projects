namespace Origo.Bifrost.Projects.Test;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.WIP;
/// <summary>Native rights for isolated posting gate permission tests; excludes the posting token.</summary>
permissionset 97107 "Proj Gate Test ori"
{
    Assignable = false;
    Permissions = tabledata Job = RIMD, tabledata "Job WIP Entry" = RIMD, tabledata "Job WIP G/L Entry" = RIMD;
}
