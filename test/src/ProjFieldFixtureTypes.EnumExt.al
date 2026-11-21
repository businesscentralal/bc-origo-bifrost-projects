namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-only seed operation for #82; no deletion operation.</summary>
enumextension 97180 "Proj. Field Fixture Types ori" extends "Message Type ori"
{
    value(97180; "Test.Field82.Seed")
    {
        Caption = 'Test.Field82.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Field Fixture ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
