namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-extension-only fixture operations for self-seeded live verification; never shipped with the product.</summary>
enumextension 97133 "TS Pending Fixture Types ori" extends "Message Type ori"
{
    /// <summary>Creates only the fixed issue 62 fixture in a CRONUS verification company.</summary>
    value(95631; "Test.PendingFixture.Seed")
    {
        Caption = 'Test.PendingFixture.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "TS Pending Fixture ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
    /// <summary>Removes only the fixed issue 62 fixture.</summary>
    value(95632; "Test.PendingFixture.Cleanup")
    {
        Caption = 'Test.PendingFixture.Cleanup', Locked = true;
        Implementation = "Msg Interface ori" = "TS Pending Cleanup ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
