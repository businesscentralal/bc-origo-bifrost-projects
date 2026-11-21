namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-only seed; no deletion operation and no production workflow depends on it.</summary>
enumextension 97196 "Proj. Visit Sign Probe ori" extends "Message Type ori"
{
    value(97196; "Test.Visit86.Seed")
    {
        Caption = 'Test.Visit86.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Sign Probe ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
