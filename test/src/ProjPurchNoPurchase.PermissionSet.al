namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Purchases.Vendor;

/// <summary>Test-only project/planning rights without any purchase-document rights.</summary>
permissionset 97172 "Proj Purch NoPurchase ori"
{
    Assignable = false;
    IncludedPermissionSets = "ProjAllocTest ori";
    Permissions = tabledata Job = R,
        tabledata "Job Planning Line" = RIMD,
        tabledata "Requisition Line" = RIMD,
        tabledata Vendor = R;
}
