namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Owns the rollback boundary for native purchase project-link validation.</summary>
codeunit 70013537 "Proj. Purchase Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Purchase: Codeunit "Projects Purchase ori";
    begin
        Purchase.RunNative(Rec);
    end;
}
