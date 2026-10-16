namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Runs a single atomic native Projects write with all field and table triggers.</summary>
codeunit 10078498 "Projects Write Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";
    trigger OnRun()
    var
        Dispatch: Codeunit "Projects Write ori";
    begin
        Dispatch.RunNative(Rec);
    end;
}
