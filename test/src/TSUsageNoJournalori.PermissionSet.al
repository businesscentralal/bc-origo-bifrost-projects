namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Journal;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only role: usage lines and sheets, but no write access to any journal table.</summary>
permissionset 97153 "TSUsageNoJournal ori"
{
    Assignable = false;
    Permissions = tabledata "TS Usage Line ori" = RIMD,
        tabledata "Time Sheet Header" = R,
        tabledata "Time Sheet Line" = R,
        tabledata "Item Journal Template" = R,
        tabledata "Item Journal Batch" = R,
        tabledata "Message Argument ori" = RIMD,
        codeunit "TS Usage Mgt ori" = X,
        codeunit "TS Usage Journal ori" = X,
        codeunit "TS Usage Context ori" = X,
        codeunit "TS Usage Runner ori" = X;
}
