namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Registers only fixture creation in the test extension.</summary>
enumextension 97177 "Proj. Task Copy Types ori" extends "Message Type ori"
{
    /// <summary>Creates raw two-vendor project demand on owned test tenants.</summary>
    value(97177; "Test.TaskCopy79.Seed")
    {
        Caption = 'Test.TaskCopy79.Seed', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Copy Seed ori", "Msg Contract ori" = "TS Fixture Contract ori";
    }
}
