namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only native purchase rights without the feature posting/full token.</summary>
permissionset 97129 "ProjUsageTest ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        tabledata "Proj. Posting ori" = R,
        tabledata "Purchase Line" = RIMD,
        tabledata "Purchase Header" = R,
        tabledata Job = R,
        tabledata "Job Task" = R,
        tabledata "Job Planning Line" = R,
        codeunit "Projects Gate ori" = X,
        codeunit "Proj. Posting Gate ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Projects Purchase ori" = X,
        codeunit "Projects Item Usage ori" = X,
        codeunit "Proj. Purchase Impl ori" = X,
        codeunit "Proj. Item Usage Impl ori" = X;
}
