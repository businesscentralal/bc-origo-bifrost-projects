namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Counts the project journal lines Projects.TimeSheet.Post would create, so the Foundation gate can confirm it (#54).</summary>
codeunit 70013582 "TS Post Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Counts without writing; the count equals postedLines of a successful post.</summary>
    /// <param name="Argument">The request.</param>
    /// <param name="Count">Receives the number of project journal lines a post would create.</param>
    /// <param name="Summary">Receives a localized description of the counted lines.</param>
    /// <returns>True; the post validates the journal template and batch itself.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        BulkMgt: Codeunit "TS Bulk Mgt ori";
        LinesTxt: Label 'project journal lines for approved time sheet entries', Comment = 'is-IS=verkbókarlínur fyrir samþykktar tímaskýrslufærslur';
    begin
        Count := BulkMgt.CountPostableLines();
        Summary := LinesTxt;
        exit(true);
    end;
}
