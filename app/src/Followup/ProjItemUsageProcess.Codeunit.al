namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Owns the atomic native item-usage posting transaction for a single message task.</summary>
codeunit 70009244 "Proj. Item Usage Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Usage: Codeunit "Projects Item Usage ori";
    begin
        Usage.PostNative(Rec);
    end;
}
