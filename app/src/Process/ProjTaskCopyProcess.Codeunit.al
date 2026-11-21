namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Owns the atomic native task copy transaction.</summary>
codeunit 70013426 "Proj. Task Copy Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        CopyTasks: Codeunit "Proj. Task Copy Impl ori";
    begin
        CopyTasks.RunNative(Rec);
    end;
}
