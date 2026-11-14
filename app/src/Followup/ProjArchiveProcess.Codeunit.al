namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Isolates the native project archive action so failures roll back the complete snapshot.</summary>
codeunit 70009236 "Proj. Archive Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Archive: Codeunit "Projects Archive ori";
    begin
        Archive.RunNative(Rec);
    end;
}
