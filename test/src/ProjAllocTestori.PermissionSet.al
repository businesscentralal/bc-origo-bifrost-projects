namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only role permits feature setup inspection and argument handling, with no native business table rights.</summary>
permissionset 97120 "ProjAllocTest ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        codeunit "Proj. Allocation Impl ori" = X,
        codeunit "Proj. Budget Actual Impl ori" = X,
        codeunit "Proj. Copy Impl ori" = X,
        codeunit "Proj. Create Impl ori" = X,
        codeunit "Proj. Plan Create Impl ori" = X,
        codeunit "Proj. Plan Delete Impl ori" = X,
        codeunit "Proj. Plan Update Impl ori" = X,
        codeunit "Proj. Posting Gate ori" = X,
        codeunit "Proj. Statistics Impl ori" = X,
        codeunit "Proj. Status Impl ori" = X,
        codeunit "Proj. Task Create Impl ori" = X,
        codeunit "Proj. Task Update Impl ori" = X,
        codeunit "Proj. Update Impl ori" = X,
        codeunit "Proj. Usage Get Impl ori" = X,
        codeunit "Proj. Usage Link Impl ori" = X,
        codeunit "Proj. WIP Calc Impl ori" = X,
        codeunit "Proj. WIP Get Impl ori" = X,
        codeunit "Proj. WIP Post Impl ori" = X,
        codeunit "Projects Allocation ori" = X,
        codeunit "Projects Contract ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Projects Gate ori" = X,
        codeunit "Projects Input ori" = X,
        codeunit "Projects Registration ori" = X,
        codeunit "Projects Setup Restrict ori" = X,
        codeunit "Projects Statistics ori" = X,
        codeunit "Projects Usage ori" = X,
        codeunit "Projects WIP ori" = X,
        codeunit "Projects Write Process ori" = X,
        codeunit "Projects Write ori" = X;
}
