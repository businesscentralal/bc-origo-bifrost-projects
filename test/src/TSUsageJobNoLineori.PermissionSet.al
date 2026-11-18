namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Journal;

/// <summary>Test-only role with template write access but no Job Journal Line write access.</summary>
permissionset 97154 "TSUsageJobNoLine ori"
{
    Assignable = false;
    IncludedPermissionSets = "TSUsageNoJournal ori";
    Permissions = tabledata "Job Journal Template" = RIMD,
        tabledata "Job Journal Batch" = R,
        tabledata "Job Journal Line" = R;
}
