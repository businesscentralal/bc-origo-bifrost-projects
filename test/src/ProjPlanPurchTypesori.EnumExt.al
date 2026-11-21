namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Registers only fixture creation in the test extension.</summary>
enumextension 97173 "Proj. Plan Purch Types ori" extends "Message Type ori"
{
    /// <summary>Creates raw two-vendor project demand on owned test tenants.</summary>
    value(97173; "Test.PlanPurchase74.Seed")
    {
        Caption = 'Test.PlanPurchase74.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Purch Seed ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
