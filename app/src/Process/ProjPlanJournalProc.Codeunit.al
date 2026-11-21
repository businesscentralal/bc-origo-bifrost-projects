namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Transfers every selected planning line within one native write transaction.</summary>
codeunit 70013428 "Proj. Plan Journal Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        Transfer(Rec);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure Transfer(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        PlanningLine: Record "Job Planning Line";
        JournalLine: Record "Job Journal Line";
        Impl: Codeunit "Proj. Plan Journal Impl ori";
        NativeTransfer: Codeunit "Job Transfer Line";
        Request: JsonObject;
        Entry: JsonToken;
        Selection: JsonObject;
        ResultLine: JsonObject;
        Response: JsonObject;
        Summary: JsonObject;
        Lines: JsonArray;
        NextSteps: JsonArray;
        Quantity: Decimal;
        PostingDate: Date;
        TemplateName: Code[10];
        BatchName: Code[10];
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
    begin
        Project.LockTable();
        PlanningLine.LockTable();
        JournalLine.LockTable();
        if not Impl.Validate(Argument, Request) then
            exit;
        Evaluate(PostingDate, Request.GetText('postingDate'), 9);
        TemplateName := CopyStr(Request.GetText('templateName'), 1, MaxStrLen(TemplateName));
        BatchName := CopyStr(Request.GetText('batchName'), 1, MaxStrLen(BatchName));
        foreach Entry in Request.GetArray('planningLines') do begin
            Selection := Entry.AsObject();
            PlanningLine.Get(Request.GetText('projectNo'), Selection.GetText('taskNo'), Selection.GetInteger('lineNo'));
            Quantity := PlanningLine."Remaining Qty.";
            if Selection.Contains('quantity') then
                Quantity := Selection.GetDecimal('quantity');
            if not PlanningLine."Usage Link" then
                PlanningLine.Validate("Usage Link", true);
            PlanningLine.Validate("Qty. to Transfer to Journal", Quantity);
            PlanningLine.Modify(true);
            Clear(JournalLine);
            NativeTransfer.FromPlanningLineToJnlLine(PlanningLine, PostingDate, TemplateName, BatchName, JournalLine);
            Clear(ResultLine);
            ResultLine.Add('lineNo', JournalLine."Line No.");
            TypeNames := JournalLine.Type.Names();
            TypeOrdinals := JournalLine.Type.Ordinals();
            ResultLine.Add('type', TypeNames.Get(TypeOrdinals.IndexOf(JournalLine.Type.AsInteger())));
            ResultLine.Add('no', JournalLine."No.");
            ResultLine.Add('quantity', JournalLine.Quantity);
            ResultLine.Add('taskNo', JournalLine."Job Task No.");
            ResultLine.Add('planningLineNo', JournalLine."Job Planning Line No.");
            Lines.Add(ResultLine);
        end;
        NextSteps.Add('Projects.ProjectJournal.Check');
        NextSteps.Add('Projects.ProjectJournal.Post');
        Summary.Add('journalLineCount', Lines.Count());
        Summary.Add('templateName', TemplateName);
        Summary.Add('batchName', BatchName);
        Response.Add('status', 'Success');
        Response.Add('journalLines', Lines);
        Response.Add('nextSteps', NextSteps);
        Response.Add('summary', Summary);
        Argument.SetResponseJson(Response);
    end;
}
