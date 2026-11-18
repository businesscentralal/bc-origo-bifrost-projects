namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Projects.Project.Journal;

/// <summary>Test-only native validation reads plus usage and Job Journal Line writes; templates remain read-only.</summary>
permissionset 97155 "TSUsageJobLine ori"
{
    Assignable = false;
    IncludedPermissionSets = "TSUsageNoJournal ori";
    Permissions = tabledata * = R,
        tabledata "Job Journal Line" = RIMD,
        tabledata "Dimension Set Entry" = rimd,
        tabledata "Dimension Set Tree Node" = rimd,
        codeunit * = X;
}
