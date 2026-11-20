namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Owns the native project item cost update so a failure rolls the whole task back (#77).</summary>
codeunit 70013407 "Proj. Item Cost Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ItemCost: Codeunit "Projects Item Cost ori";
    begin
        ItemCost.RunNative(Rec);
    end;
}
