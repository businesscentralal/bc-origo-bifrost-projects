namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Registers only fixture creation in the test extension.</summary>
enumextension 97181 "Proj. Plan Journal Types ori" extends "Message Type ori"
{
    /// <summary>Creates raw resource and stocked-item planning lines on owned test tenants.</summary>
    value(97181; "Test.PlanJournal81.Seed")
    {
        Caption = 'Test.PlanJournal81.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Journal Seed ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
