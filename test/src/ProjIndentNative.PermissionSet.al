namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;

/// <summary>Test-only native task rights without the Projects Full feature-role token.</summary>
permissionset 97115 "ProjIndentNative ori"
{
    Assignable = false;
    Permissions = tabledata "Job Task" = RIMD;
}
