namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using System.Utilities;

/// <summary>Retains each request or manager decision in one atomic transaction.</summary>
codeunit 70013453 "Proj. Follow-up Runner ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";
    var
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
        SavedLbl: Label 'Follow-up request %1 is %2.', Comment = '%1 = request number; %2 = status; is-IS=Eftirfylgnibeiðni %1 er %2.';
        OpenLbl: Label 'Open', Comment = 'is-IS=Opin';
        ConvertedLbl: Label 'Converted', Comment = 'is-IS=Umbreytt';
        RejectedLbl: Label 'Rejected', Comment = 'is-IS=Hafnað';
        PreviewLbl: Label 'Preview completed; no changes were saved.', Comment = 'is-IS=Forskoðun lokið; engar breytingar voru vistaðar.';
        RollbackTok: Label 'FOLLOWUP_PREVIEW_ROLLBACK', Locked = true;
        NumberErr: Label 'Choose an unused task number within the original task group.', Comment = 'is-IS=Veldu laust verkþáttanúmer innan hóps upprunalega verkþáttarins.';
        PhotoErr: Label 'The photo upload no longer belongs to this caller or has already been consumed.', Comment = 'is-IS=Innhlaðna ljósmyndin tilheyrir ekki lengur þessum kallanda eða hefur þegar verið sótt.';

    trigger OnRun()
    begin
        Process(Rec);
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure Process(var Argument: Record "Message Argument ori")
    var
        Header: Record "Proj. Follow-up Request ori";
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Result: Codeunit "Proj. Follow-up Result ori";
        Request: JsonObject;
        Response: JsonObject;
        Created: JsonObject;
        OriginalRequest: JsonObject;
        Steps: JsonArray;
        Operation: Integer;
        Preview: Boolean;
    begin
        Request := Argument.GetRequestJson();
        case Argument.Type of
            "Message Type ori"::"Projects.FollowUp.Request": Operation := 1;
            "Message Type ori"::"Projects.FollowUp.Convert": Operation := 3;
            "Message Type ori"::"Projects.FollowUp.Reject": Operation := 4;
        end;
        Header.LockTable();
        if Operation = 3 then begin
            Project.LockTable();
            Task.LockTable();
            Planning.LockTable();
        end;
        if not Mgt.Validate(Argument, Request, Operation) then
            exit;
        if Operation = 1 then begin
            if Mgt.Replay(Argument, Request) then
                exit;
            if not CreateRequest(Argument, Request, Header) then
                exit;
        end else begin
            Header.Get(Mgt.IntegerValue(Request, 'requestId'));
            if Operation = 3 then begin
                OriginalRequest := Mgt.ToJson(Header);
                Convert(Header, Request, Created);
                Header.Status := Header.Status::Converted;
                if Request.Contains('preview') then
                    Preview := Request.GetBoolean('preview');
                Steps.Add('Projects.Quote.Send');
            end else begin
                Header.Status := Header.Status::Rejected;
                Header."Rejection Reason" := CopyStr(Mgt.TextValue(Request, 'reason'), 1, MaxStrLen(Header."Rejection Reason"));
            end;
            Header."Decided By" := UserSecurityId();
            Header."Decided At" := CurrentDateTime();
            Header.Modify(true);
        end;
        Response := ResponseFor(Header);
        if Operation = 3 then begin
            Response.Add('created', Created);
            Response.Add('preview', Preview);
            Response.Add('nextSteps', Steps);
        end;
        if Preview then begin
            Response.Replace('summary', PreviewLbl);
            Response.Replace('requestStatus', 'Open');
            Response.Replace('request', OriginalRequest);
            Result.SetResult(Response);
            Error(RollbackTok);
        end;
        Argument.SetResponseJson(Response);
    end;

    local procedure CreateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; var Header: Record "Proj. Follow-up Request ori"): Boolean
    var
        Line: Record "Proj. Follow-up Req. Line ori";
        Item: Record Item;
        Staging: Codeunit "Blob Staging ori";
        TempBlob: Codeunit "Temp Blob";
        Token: JsonToken;
        Child: JsonObject;
        StagingId: Guid;
        InStr: InStream;
        OutStr: OutStream;
        ResourceNo: Code[20];
        LineNo: Integer;
        FileName: Text;
        ContentType: Text;
    begin
        if not Mgt.OwnResource(Argument, ResourceNo) then
            exit(false);
        Header.Init();
        Header."Project No." := CopyStr(Mgt.TextValue(Request, 'projectNo'), 1, 20);
        Header."Task No." := CopyStr(Mgt.TextValue(Request, 'taskNo'), 1, 20);
        Header."Resource No." := ResourceNo;
        Header."Requested By" := UserSecurityId();
        Header.Description := CopyStr(Mgt.TextValue(Request, 'description'), 1, 100);
        Header."Client Request Id" := CopyStr(Mgt.TextValue(Request, 'clientRequestId'), 1, 100);
        Header.Urgency := 'normal';
        if Request.Contains('urgency') then
            Header.Urgency := CopyStr(Mgt.TextValue(Request, 'urgency'), 1, 20);
        if Request.Contains('preferredDate') then
            Evaluate(Header."Preferred Date", Mgt.TextValue(Request, 'preferredDate'), 9);
        if Request.Contains('estimatedHours') then
            Header."Estimated Hours" := Request.GetDecimal('estimatedHours');
        Header.Insert(true);
        if Request.Contains('items') then
            foreach Token in Request.GetArray('items') do begin
                Child := Token.AsObject();
                LineNo += 10000;
                Line.Init();
                Line."Request No." := Header."Entry No.";
                Line."Line No." := LineNo;
                Line."Item No." := CopyStr(Mgt.TextValue(Child, 'itemNo'), 1, 20);
                Line.Description := CopyStr(Mgt.TextValue(Child, 'description'), 1, 100);
                if (Line.Description = '') and (Line."Item No." <> '') then begin
                    Item.Get(Line."Item No.");
                    Line.Description := Item.Description;
                end;
                Line.Quantity := Mgt.DecimalValue(Child, 'quantity');
                Line.Insert(true);
            end;
        if Request.Contains('stagingIds') then
            foreach Token in Request.GetArray('stagingIds') do begin
                Evaluate(StagingId, Token.AsValue().AsText());
                Clear(TempBlob);
                if not Staging.Take(StagingId, TempBlob, ContentType, FileName) then
                    Error(PhotoErr);
                LineNo += 10000;
                Line.Init();
                Line."Request No." := Header."Entry No.";
                Line."Line No." := LineNo;
                Line."Is Photo" := true;
                Line."File Name" := CopyStr(FileName, 1, 250);
                Line."Content Type" := CopyStr(ContentType, 1, 100);
                TempBlob.CreateInStream(InStr);
                Line.Photo.CreateOutStream(OutStr);
                CopyStream(OutStr, InStr);
                Line.Insert(true);
            end;
        exit(true);
    end;

    local procedure Convert(var Header: Record "Proj. Follow-up Request ori"; Request: JsonObject; var Created: JsonObject)
    var
        Task: Record "Job Task";
        OriginalTask: Record "Job Task";
        Setup: Record "Projects Setup ori";
        Planning: Record "Job Planning Line";
        Line: Record "Proj. Follow-up Req. Line ori";
        Writer: Codeunit "Projects Write ori";
        LineRequest: JsonObject;
        TaskNode: JsonObject;
        Lines: JsonArray;
        TaskNo: Code[20];
        ResourceNo: Code[20];
        LineNo: Integer;
        Day: Date;
        Increment: Integer;
        Index: Integer;
    begin
        OriginalTask.Get(Header."Project No.", Header."Task No.");
        TaskNo := CopyStr(Mgt.TextValue(Request, 'taskNo'), 1, 20);
        ResourceNo := Header."Resource No.";
        if Request.Contains('resourceNo') then
            ResourceNo := CopyStr(Mgt.TextValue(Request, 'resourceNo'), 1, 20);
        if Mgt.TextValue(Request, 'target') = 'newTask' then begin
            if TaskNo = '' then begin
                TaskNo := Header."Task No.";
                Increment := 1;
                if Setup.Get() then
                    if Setup."Follow-up Task Increment" > 0 then
                        Increment := Setup."Follow-up Task Increment";
                repeat
                    for Index := 1 to Increment do begin
                        if IncStr(TaskNo) = '' then
                            Error(NumberErr);
                        TaskNo := IncStr(TaskNo);
                    end;
                until not Task.Get(Header."Project No.", TaskNo);
            end;
            CheckGroup(OriginalTask, TaskNo);
            Writer.CreateTask(Header."Project No.", TaskNo, Header.Description, OriginalTask.Indentation);
        end else
            if TaskNo = '' then
                TaskNo := Header."Task No.";
        Planning.SetRange("Job No.", Header."Project No.");
        Planning.SetRange("Job Task No.", TaskNo);
        if Planning.FindLast() then
            LineNo := Planning."Line No.";
        Day := Header."Preferred Date";
        if Day = 0D then
            Day := Today();
        if Header."Estimated Hours" > 0 then begin
            LineNo += 10000;
            LineRequest := PlanningRequest(Header."Project No.", TaskNo, LineNo, 'Resource', ResourceNo, Header.Description, Header."Estimated Hours", Day);
            CreatePlanning(LineRequest);
            Header."Resource Planning Line No." := LineNo;
            Lines.Add(LineRequest);
        end;
        Line.SetRange("Request No.", Header."Entry No.");
        Line.SetRange("Is Photo", false);
        if Line.FindSet(true) then
            repeat
                LineNo += 10000;
                if Line."Item No." = '' then
                    LineRequest := PlanningRequest(Header."Project No.", TaskNo, LineNo, 'Text', '', Line.Description, 0, Day)
                else
                    LineRequest := PlanningRequest(Header."Project No.", TaskNo, LineNo, 'Item', Line."Item No.", Line.Description, Line.Quantity, Day);
                CreatePlanning(LineRequest);
                Line."Planning Line No." := LineNo;
                Line.Modify(true);
                Lines.Add(LineRequest);
            until Line.Next() = 0;
        Header."Converted Task No." := TaskNo;
        TaskNode.Add('projectNo', Header."Project No.");
        TaskNode.Add('taskNo', TaskNo);
        TaskNode.Add('new', Mgt.TextValue(Request, 'target') = 'newTask');
        Created.Add('task', TaskNode);
        Created.Add('planningLines', Lines);
    end;

    local procedure CheckGroup(Original: Record "Job Task"; NewNo: Code[20])
    var
        Boundary: Record "Job Task";
    begin
        if NewNo <= Original."Job Task No." then
            Error(NumberErr);
        Boundary.SetRange("Job No.", Original."Job No.");
        Boundary.SetFilter("Job Task No.", '>%1&<%2', Original."Job Task No.", NewNo);
        if Boundary.FindSet() then
            repeat
                if (Boundary.Indentation < Original.Indentation) or (Boundary."Job Task Type" in [Boundary."Job Task Type"::"Begin-Total", Boundary."Job Task Type"::"End-Total"]) then
                    Error(NumberErr);
            until Boundary.Next() = 0;
    end;

    local procedure PlanningRequest(ProjectNo: Code[20]; TaskNo: Code[20]; LineNo: Integer; Kind: Text; No: Code[20]; Description: Text; Quantity: Decimal; Day: Date) Request: JsonObject
    begin
        Request.Add('projectNo', ProjectNo);
        Request.Add('taskNo', TaskNo);
        Request.Add('lineNo', LineNo);
        Request.Add('type', Kind);
        Request.Add('lineType', 'Budget');
        if No <> '' then
            Request.Add('no', No);
        Request.Add('description', Description);
        Request.Add('planningDate', Format(Day, 0, 9));
        if Kind <> 'Text' then
            Request.Add('quantity', Quantity);
    end;

    local procedure CreatePlanning(LineRequest: JsonObject)
    var
        Writer: Codeunit "Projects Write ori";
        Quantity: Decimal;
        Day: Date;
    begin
        if LineRequest.Contains('quantity') then
            Quantity := LineRequest.GetDecimal('quantity');
        Evaluate(Day, LineRequest.GetText('planningDate'), 9);
        Writer.CreatePlanningLine(CopyStr(LineRequest.GetText('projectNo'), 1, 20), CopyStr(LineRequest.GetText('taskNo'), 1, 20), LineRequest.GetInteger('lineNo'), LineRequest.GetText('type'), CopyStr(Mgt.TextValue(LineRequest, 'no'), 1, 20), LineRequest.GetText('description'), Quantity, Day);
    end;

    /// <summary>Returns a stable result for initial creation and duplicate client request ids.</summary>
    procedure ResponseFor(Header: Record "Proj. Follow-up Request ori") Response: JsonObject
    var
        Node: JsonObject;
        StatusText: Text;
    begin
        Node := Mgt.ToJson(Header);
        Response.Add('status', 'Success');
        Response.Add('requestId', Header."Entry No.");
        Response.Add('requestStatus', Node.GetText('status'));
        Response.Add('request', Node);
        case Header.Status of
            Header.Status::Open: StatusText := OpenLbl;
            Header.Status::Converted: StatusText := ConvertedLbl;
            Header.Status::Rejected: StatusText := RejectedLbl;
        end;
        Response.Add('summary', StrSubstNo(SavedLbl, Header."Entry No.", StatusText));
    end;
}
