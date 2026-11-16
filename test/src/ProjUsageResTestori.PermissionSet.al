namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Tracking;

/// <summary>Completes native tracking rights for scoped permission tests without changing production grants.</summary>
permissionset 97130 "ProjUsageResTest ori"
{
    Assignable = false;
    Permissions = tabledata "Reservation Entry" = RIMD;
}
