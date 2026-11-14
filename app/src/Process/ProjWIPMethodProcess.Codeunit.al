namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Provides the native WIP method write rollback boundary.</summary>
codeunit 70009243 "Proj. WIP Method Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Methods: Codeunit "Projects WIP Methods ori";
    begin
        Methods.RunNative(Rec);
    end;
}
