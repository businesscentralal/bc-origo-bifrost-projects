namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-extension-only fixture operations for the projects#38 live MCP verification; never shipped with the product.</summary>
enumextension 97163 "TS Self Service Fixture Types" extends "Message Type ori"
{
    /// <summary>Creates only the fixed X38M fixture in a CRONUS verification company.</summary>
    value(95633; "Test.SelfServiceFixture.Seed")
    {
        Caption = 'Test.SelfServiceFixture.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "TS Self Service Fixture ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
    /// <summary>Removes only the fixed X38M fixture.</summary>
    value(95634; "Test.SelfServiceFixture.Cleanup")
    {
        Caption = 'Test.SelfServiceFixture.Cleanup', Locked = true;
        Implementation = "Msg Interface ori" = "TS Self Service Cleanup ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
