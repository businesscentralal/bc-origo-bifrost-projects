namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Runs the native planning-date batch inside one atomic write boundary.</summary>
codeunit 70013418 "Proj. Shift Dates Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ShiftDates(Rec);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure ShiftDates(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Task: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        Invoice: Record "Job Planning Line Invoice";
        TempBefore: Record "Job Planning Line" temporary;
        Batch: Codeunit "Job Calculate Batches";
        Impl: Codeunit "Proj. Shift Dates Impl ori";
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Response: JsonObject;
        Summary: JsonObject;
        Changes: JsonArray;
        Skipped: JsonArray;
        PeriodLength: DateFormula;
        FixedDate: Date;
        StartingDate: Date;
        EndingDate: Date;
        FromTask: Code[20];
        ToTask: Code[20];
        DateField: Text;
        LineType: Text;
        ChangedCount: Integer;
        FieldCount: Integer;
        MissingLbl: Label 'Select an existing project and task range.', Comment = 'is-IS=Veldu fyrirliggjandi verkefni og verkhlutabil.';
        BlockedLbl: Label 'Unblock the project before changing planning dates.', Comment = 'is-IS=Afblokkun verkefnis er nauðsynleg áður en áætlunardagsetningum er breytt.';
        InvoicedLbl: Label 'Select a range without lines already transferred to an invoice or invoiced. Nothing changed.', Comment = 'is-IS=Veldu bil án lína sem hafa þegar verið fluttar á reikning eða reikningsfærðar. Engu var breytt.';
    begin
        Request := Argument.GetRequestJson();
        if not Impl.ValidateOptions(Argument, Request, PeriodLength, FixedDate, StartingDate, EndingDate) then
            exit;
        Project.LockTable();
        if not Project.Get(Request.GetText('projectNo')) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl);
            exit;
        end;
        if Project.Blocked = Project.Blocked::All then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', BlockedLbl);
            exit;
        end;
        FromTask := CopyStr(Input.TextValue(Request, 'fromTaskNo'), 1, MaxStrLen(FromTask));
        ToTask := CopyStr(Input.TextValue(Request, 'toTaskNo'), 1, MaxStrLen(ToTask));
        Task.LockTable();
        if Request.Contains('fromTaskNo') then
            if not Task.Get(Project."No.", FromTask) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'fromTaskNo', MissingLbl);
                exit;
            end;
        if Request.Contains('toTaskNo') then
            if not Task.Get(Project."No.", ToTask) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'toTaskNo', MissingLbl);
                exit;
            end;
        DateField := Input.TextValue(Request, 'dateField');
        if DateField = '' then
            DateField := 'planningDate';
        LineType := Request.GetText('lineType');
        PlanningLine.LockTable();
        Invoice.LockTable();
        PlanningLine.SetRange("Job No.", Project."No.");
        if FromTask <> '' then
            PlanningLine.SetFilter("Job Task No.", '>=%1', FromTask);
        if ToTask <> '' then
            if FromTask = '' then
                PlanningLine.SetFilter("Job Task No.", '<=%1', ToTask)
            else
                PlanningLine.SetRange("Job Task No.", FromTask, ToTask);
        if LineType = 'Budget' then
            PlanningLine.SetRange("Schedule Line", true);
        if LineType = 'Billable' then
            PlanningLine.SetRange("Contract Line", true);
        if PlanningLine.FindSet() then
            repeat
                if IsSelected(PlanningLine, DateField, StartingDate, EndingDate) then begin
                    // Refuse even offsetting invoice/credit quantities: there is invoice history.
                    Invoice.SetRange("Job No.", PlanningLine."Job No.");
                    Invoice.SetRange("Job Task No.", PlanningLine."Job Task No.");
                    Invoice.SetRange("Job Planning Line No.", PlanningLine."Line No.");
                    if not Invoice.IsEmpty() then begin
                        Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'lineNo', InvoicedLbl);
                        exit;
                    end;
                    TempBefore := PlanningLine;
                    TempBefore.Insert();
                end;
            until PlanningLine.Next() = 0;
        Task.SetRange("Job No.", Project."No.");
        Task.SetFilter("Job Task No.", PlanningLine.GetFilter("Job Task No."));
        if Task.FindSet() then
            repeat
                if DateField in ['planningDate', 'both'] then
                    Batch.ChangePlanningDates(Task, LineType in ['Budget', 'Both'], LineType in ['Billable', 'Both'], PeriodLength, FixedDate, StartingDate, EndingDate);
                if DateField in ['currencyDate', 'both'] then
                    Batch.ChangeCurrencyDates(Task, LineType in ['Budget', 'Both'], LineType in ['Billable', 'Both'], PeriodLength, FixedDate, StartingDate, EndingDate);
            until Task.Next() = 0;
        if TempBefore.FindSet() then
            repeat
                PlanningLine.Get(TempBefore."Job No.", TempBefore."Job Task No.", TempBefore."Line No.");
                FieldCount := Changes.Count();
                AddChange(Changes, TempBefore, 'planningDate', TempBefore."Planning Date", PlanningLine."Planning Date");
                AddChange(Changes, TempBefore, 'currencyDate', TempBefore."Currency Date", PlanningLine."Currency Date");
                AddChange(Changes, TempBefore, 'documentDate', TempBefore."Document Date", PlanningLine."Document Date");
                if Changes.Count() > FieldCount then
                    ChangedCount += 1;
            until TempBefore.Next() = 0;
        Summary.Add('changedLineCount', ChangedCount);
        Summary.Add('changedFieldCount', Changes.Count());
        Response.Add('status', 'Success');
        Response.Add('projectNo', Project."No.");
        Response.Add('changedLines', Changes);
        Response.Add('skipped', Skipped);
        Response.Add('summary', Summary);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsSelected(PlanningLine: Record "Job Planning Line"; DateField: Text; StartingDate: Date; EndingDate: Date): Boolean
    begin
        exit(((DateField in ['planningDate', 'both']) and (PlanningLine."Planning Date" >= StartingDate) and (PlanningLine."Planning Date" <= EndingDate)) or
            ((DateField in ['currencyDate', 'both']) and (PlanningLine."Currency Date" >= StartingDate) and (PlanningLine."Currency Date" <= EndingDate)));
    end;

    local procedure AddChange(var Changes: JsonArray; PlanningLine: Record "Job Planning Line"; FieldName: Text; OldDate: Date; NewDate: Date)
    var
        Change: JsonObject;
    begin
        if OldDate = NewDate then
            exit;
        Change.Add('taskNo', PlanningLine."Job Task No.");
        Change.Add('lineNo', PlanningLine."Line No.");
        Change.Add('field', FieldName);
        Change.Add('oldDate', Format(OldDate, 0, 9));
        Change.Add('newDate', Format(NewDate, 0, 9));
        Changes.Add(Change);
    end;
}
