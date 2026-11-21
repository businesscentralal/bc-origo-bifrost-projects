namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Counts the projects Projects.ItemCost.Update would update, so the Foundation gate can confirm it (#77).</summary>
codeunit 70013409 "Proj. Item Cost Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Counts without writing; the count equals the number of projects in the response.</summary>
    /// <param name="Argument">The request.</param>
    /// <param name="Count">Receives the number of projects in scope.</param>
    /// <param name="Summary">Receives a localized description of the counted projects.</param>
    /// <returns>True; an unusable request counts as naming no subject and the type's own validation refuses it.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        DefaultConfirm: Codeunit "Default Confirm ori";
        ItemCost: Codeunit "Projects Item Cost ori";
        Projects: List of [Code[20]];
        ProjectsTxt: Label 'projects whose item cost is updated', Comment = 'is-IS=verkefni þar sem vörukostnaður er uppfærður';
    begin
        if not ItemCost.CountScope(Argument, Projects) then begin
            Count := 0;
            Summary := DefaultConfirm.NoSubjectText();
            exit(true);
        end;
        Count := Projects.Count();
        Summary := ProjectsTxt;
        exit(true);
    end;
}
