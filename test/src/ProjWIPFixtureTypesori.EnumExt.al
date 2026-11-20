namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-only reversal fixture creation; cleanup uses the existing Foundation test tooling.</summary>
enumextension 97114 "Proj. WIP Fixture Types ori" extends "Message Type ori"
{
    /// <summary>Creates raw owned WIP inputs for verification.</summary>
    value(97114; "Test.WIP75.Seed")
    {
        Caption = 'Test.WIP75.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Reverse Fixture ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
