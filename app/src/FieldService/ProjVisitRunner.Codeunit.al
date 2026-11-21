namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>
/// Writes one visit, its time sheet hours and an optional mileage line in a single transaction.
/// Hours are added. Zero hours leaves the day unchanged. Nothing is deleted or submitted.
/// </summary>
codeunit 70013440 "Proj. Visit Runner ori"
{
    Access = Internal;

    var
        Operation: Integer;
        Payload: JsonObject;
        ResultText: Text;
        StillRunningErr: Label 'Another visit is still running.', Comment = 'is-IS=Önnur heimsókn er enn í gangi.';
        NotRunningErr: Label 'The visit is not running.', Comment = 'is-IS=Heimsóknin er ekki í gangi.';
        NotOwnerErr: Label 'The time sheet does not belong to the caller.', Comment = 'is-IS=Tímaskýrslan tilheyrir ekki kallanda.';
        LineMissingErr: Label 'No open time sheet line is available for this task.', Comment = 'is-IS=Engin opin tímaskýrslulína er til fyrir þennan verkþátt.';
        TooManyHoursErr: Label 'The day would exceed 24 hours.', Comment = 'is-IS=Dagurinn færi yfir 24 klukkustundir.';
        MileageLbl: Label 'Mileage', Comment = 'is-IS=Akstur';

    /// <summary>Stores the validated operation for the next Run.</summary>
    procedure SetCall(NewOperation: Integer; NewPayload: JsonObject)
    begin
        Operation := NewOperation;
        Payload := NewPayload;
        ResultText := '';
    end;

    /// <summary>Returns the success JSON written by the last Run.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;

    trigger OnRun()
    begin
        case Operation of
            1:
                StartVisit();
            2:
                StopVisit();
            3:
                CompleteVisit();
        end;
    end;

    local procedure StartVisit()
    var
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        Stopped: JsonObject;
        StartedAt: DateTime;
        StoppedVisitId: Integer;
    begin
        StartedAt := ReadDateTime('at');
        StoppedVisitId := ReadInteger('autoStopVisitId');
        if StoppedVisitId <> 0 then
            Stopped := FinishRunning(StoppedVisitId, StartedAt, ReadDecimal('stoppedHours'), ReadCode('stoppedSheetNo', 20), '', false);
        Visit.ReadIsolation := IsolationLevel::UpdLock;
        Visit.SetRange("Resource No.", ReadCode('resourceNo', 20));
        Visit.SetRange(Status, Visit.Status::Running);
        if not Visit.IsEmpty() then
            Error(StillRunningErr);
        Visit.Reset();
        Visit.Init();
        Visit."Resource No." := CopyStr(ReadCode('resourceNo', 20), 1, MaxStrLen(Visit."Resource No."));
        Visit."Project No." := CopyStr(ReadCode('projectNo', 20), 1, MaxStrLen(Visit."Project No."));
        Visit."Task No." := CopyStr(ReadCode('taskNo', 20), 1, MaxStrLen(Visit."Task No."));
        Visit.Date := DT2Date(StartedAt);
        // kind arrives as a Code, which BC stores in uppercase. Compare the text in lowercase.
        if LowerCase(ReadText('kind')) = 'travel' then
            Visit.Kind := Visit.Kind::Travel
        else
            Visit.Kind := Visit.Kind::Work;
        Visit."Started At" := StartedAt;
        Visit.Status := Visit.Status::Running;
        Visit."Client Request Id" := CopyStr(ReadText('clientRequestId'), 1, MaxStrLen(Visit."Client Request Id"));
        Visit.Insert(true);
        Response.Add('status', 'Success');
        Response.Add('visitId', Visit."Entry No.");
        Response.Add('startedAt', Format(StartedAt, 0, 9));
        if StoppedVisitId <> 0 then
            Response.Add('stopped', Stopped);
        Response.Add('summary', StartSummary(Visit));
        Visit.StoreRequest(ReadText('clientRequestId'), JsonText(Response));
        Visit.Modify(true);
        ResultText := JsonText(Response);
    end;

    local procedure StopVisit()
    var
        Response: JsonObject;
    begin
        Response := FinishRunning(ReadInteger('visitId'), ReadDateTime('at'), ReadDecimal('hours'), ReadCode('sheetNo', 20), ReadText('note'), true);
        ResultText := JsonText(Response);
    end;

    local procedure CompleteVisit()
    var
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        VisitNode: JsonObject;
        UsageEntryNo: Integer;
        Mileage: Decimal;
    begin
        Visit.ReadIsolation := IsolationLevel::UpdLock;
        Visit.Get(ReadInteger('visitId'));
        if ReadBoolean('running') then begin
            FinishRunning(Visit."Entry No.", ReadDateTime('at'), ReadDecimal('hours'), ReadCode('sheetNo', 20), '', false);
            Visit.Get(Visit."Entry No.");
        end;
        if Payload.Contains('mileageKm') then begin
            Evaluate(Mileage, ReadText('mileageKm'), 9);
            UsageEntryNo := WriteMileage(Visit, Mileage);
            Visit.Get(Visit."Entry No.");
        end;
        Visit.Outcome := CopyStr(ReadText('outcome'), 1, MaxStrLen(Visit.Outcome));
        Visit.Status := Visit.Status::Completed;
        Visit."Client Request Id" := CopyStr(ReadText('clientRequestId'), 1, MaxStrLen(Visit."Client Request Id"));
        VisitNode.Add('visitId', Visit."Entry No.");
        VisitNode.Add('status', 'Completed');
        VisitNode.Add('projectNo', Visit."Project No.");
        VisitNode.Add('taskNo', Visit."Task No.");
        VisitNode.Add('hours', Visit."Hours Written");
        Response.Add('status', 'Success');
        Response.Add('visit', VisitNode);
        if UsageEntryNo <> 0 then begin
            Visit."Usage Entry No." := UsageEntryNo;
            Response.Add('usageEntryNo', UsageEntryNo);
        end;
        Response.Add('summary', CompleteSummary(Visit, Mileage, UsageEntryNo <> 0));
        Response.Add('nextSteps', CompleteSteps());
        Visit.StoreRequest(ReadText('clientRequestId'), JsonText(Response));
        Visit.Modify(true);
        ResultText := JsonText(Response);
    end;

    local procedure FinishRunning(VisitId: Integer; StoppedAt: DateTime; Hours: Decimal; SheetNo: Code[20]; Note: Text; StoreThisRequest: Boolean) Response: JsonObject
    var
        Visit: Record "Proj. Field Visit ori";
        Header: Record "Time Sheet Header";
        WorkType: Code[10];
        LineNo: Integer;
    begin
        Visit.ReadIsolation := IsolationLevel::UpdLock;
        Visit.Get(VisitId);
        if Visit.Status <> Visit.Status::Running then
            Error(NotRunningErr);
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(SheetNo);
        if Header."Owner User ID" <> CopyStr(UpperCase(UserId()), 1, MaxStrLen(Header."Owner User ID")) then
            Error(NotOwnerErr);
        if Visit.Kind = Visit.Kind::Travel then
            WorkType := TravelWorkType();
        if Hours > 0 then
            LineNo := AddHours(Header, Visit, WorkType, Hours)
        else
            LineNo := 0;
        Visit."Stopped At" := StoppedAt;
        Visit."Hours Written" := Hours;
        Visit."Time Sheet No." := SheetNo;
        Visit."Time Sheet Line No." := LineNo;
        if Note <> '' then
            Visit.Note := CopyStr(Note, 1, MaxStrLen(Visit.Note));
        Visit.Status := Visit.Status::Stopped;
        Response.Add('visitId', Visit."Entry No.");
        Response.Add('hours', Hours);
        Response.Add('timeSheetNo', SheetNo);
        Response.Add('timeSheetLineNo', LineNo);
        Response.Add('day', Format(Visit.Date, 0, 9));
        if StoreThisRequest then begin
            Response.Add('status', 'Success');
            Response.Add('summary', StopSummary(Hours, Visit.Date));
            Response.Add('nextSteps', StopSteps());
            Visit."Client Request Id" := CopyStr(ReadText('clientRequestId'), 1, MaxStrLen(Visit."Client Request Id"));
            Visit.StoreRequest(ReadText('clientRequestId'), JsonText(Response));
        end;
        Visit.Modify(true);
    end;

    local procedure AddHours(Header: Record "Time Sheet Header"; Visit: Record "Proj. Field Visit ori"; WorkType: Code[10]; Hours: Decimal): Integer
    var
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Existing: Decimal;
    begin
        if DayQuantity(Header."No.", Visit.Date) + Hours > 24 then
            Error(TooManyHoursErr);
        if not FindOpenLine(Header."No.", Visit."Project No.", Visit."Task No.", WorkType, Line) then begin
            if not ReadBoolean('mayCreateLine') and (Operation <> 1) then
                Error(LineMissingErr);
            CreateJobLine(Header, Visit."Project No.", Visit."Task No.", WorkType, Line);
        end;
        Detail.ReadIsolation := IsolationLevel::UpdLock;
        if Detail.Get(Line."Time Sheet No.", Line."Line No.", Visit.Date) then begin
            Existing := Detail.Quantity;
            Detail.Validate(Quantity, Existing + Hours);
            Detail.Modify(true);
        end else begin
            Detail.Init();
            Detail.CopyFromTimeSheetLine(Line);
            Detail.Date := Visit.Date;
            Detail.Validate(Quantity, Hours);
            Detail.Insert(true);
        end;
        // Detail insert can reload the line. Put the work type back with the same validate the line writer uses.
        EnsureWorkType(Line, WorkType);
        exit(Line."Line No.");
    end;

    local procedure WriteMileage(Visit: Record "Proj. Field Visit ori"; Mileage: Decimal): Integer
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        Description: Text;
    begin
        Header.Get(Visit."Time Sheet No.");
        if Header."No." = '' then
            Header.Get(ReadCode('sheetNo', 20));
        if not FindOpenLine(Header."No.", Visit."Project No.", Visit."Task No.", '', Line) then begin
            if not ReadBoolean('mayCreateLine') then
                Error(LineMissingErr);
            CreateJobLine(Header, Visit."Project No.", Visit."Task No.", '', Line);
        end;
        Description := ReadText('outcome');
        if Description = '' then
            Description := MileageLbl;
        Usage.Init();
        Usage."Time Sheet No." := Header."No.";
        Usage."Time Sheet Line No." := Line."Line No.";
        Usage."Resource No." := Header."Resource No.";
        Usage.Type := Usage.Type::Resource;
        Usage."No." := CopyStr(ReadCode('mileageResource', 20), 1, MaxStrLen(Usage."No."));
        Usage.Date := Visit.Date;
        Usage.Quantity := Mileage;
        Usage."Unit of Measure Code" := CopyStr(ReadCode('mileageUnit', 10), 1, MaxStrLen(Usage."Unit of Measure Code"));
        Usage.Description := CopyStr(Description, 1, MaxStrLen(Usage.Description));
        Usage.Status := Usage.Status::Open;
        Usage.Insert(true);
        exit(Usage."Entry No.");
    end;

    internal procedure CreateJobLine(Header: Record "Time Sheet Header"; ProjectNo: Code[20]; TaskNo: Code[20]; WorkType: Code[10]; var Line: Record "Time Sheet Line")
    begin
        // Same order as Projects.MyTimeSheetLine.Set: insert the open line, then validate.
        // Validating the work type before insert does not survive Time Sheet Line.OnInsert,
        // and Work Type Code.OnValidate requires the work type unit to match the resource.
        Line.Reset();
        Line.Init();
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := NextLineNo(Header."No.");
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Insert(true);
        Line.Validate(Type, Line.Type::Job);
        Line.Validate("Job No.", ProjectNo);
        Line.Validate("Job Task No.", TaskNo);
        if WorkType <> '' then
            Line.Validate("Work Type Code", WorkType);
        Line.Modify(true);
    end;

    local procedure TravelWorkType(): Code[10]
    var
        Setup: Record "Projects Setup ori";
        FromPayload: Code[10];
    begin
        // The client does not send the work type. Prefer the value copied onto the payload, then setup.
        FromPayload := CopyStr(ReadText('travelWorkType'), 1, MaxStrLen(FromPayload));
        if FromPayload <> '' then
            exit(FromPayload);
        if Setup.Get() then
            exit(Setup."Travel Work Type Code");
    end;

    local procedure EnsureWorkType(var Line: Record "Time Sheet Line"; WorkType: Code[10])
    var
        SheetNo: Code[20];
        LineNo: Integer;
    begin
        if WorkType = '' then
            exit;
        SheetNo := Line."Time Sheet No.";
        LineNo := Line."Line No.";
        Line.Reset();
        Line.Get(SheetNo, LineNo);
        if Line."Work Type Code" = WorkType then
            exit;
        Line.Validate("Work Type Code", WorkType);
        Line.Modify(true);
    end;

    internal procedure FindOpenLine(SheetNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20]; WorkType: Code[10]; var Line: Record "Time Sheet Line"): Boolean
    begin
        Line.ReadIsolation := IsolationLevel::UpdLock;
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Job);
        Line.SetRange("Job No.", ProjectNo);
        Line.SetRange("Job Task No.", TaskNo);
        Line.SetRange("Work Type Code", WorkType);
        Line.SetFilter(Status, '%1|%2', Line.Status::Open, Line.Status::Rejected);
        if not Line.FindFirst() then
            exit(false);
        if Line.Status = Line.Status::Rejected then begin
            Line.Status := Line.Status::Open;
            Line.Modify(true);
            ReopenDetails(Line);
        end;
        exit(true);
    end;

    local procedure ReopenDetails(Line: Record "Time Sheet Line")
    var
        Detail: Record "Time Sheet Detail";
    begin
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        Detail.ModifyAll(Status, Detail.Status::Open, false);
    end;

    local procedure NextLineNo(TimeSheetNo: Code[20]): Integer
    var
        Line: Record "Time Sheet Line";
    begin
        Line.ReadIsolation := IsolationLevel::UpdLock;
        Line.SetRange("Time Sheet No.", TimeSheetNo);
        if Line.FindLast() then
            exit(Line."Line No." + 10000);
        exit(10000);
    end;

    local procedure DayQuantity(SheetNo: Code[20]; Day: Date): Decimal
    var
        Detail: Record "Time Sheet Detail";
    begin
        Detail.SetRange("Time Sheet No.", SheetNo);
        Detail.SetRange(Date, Day);
        Detail.CalcSums(Quantity);
        exit(Detail.Quantity);
    end;

    local procedure StartSummary(Visit: Record "Proj. Field Visit ori"): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        if Visit.Kind = Visit.Kind::Travel then
            exit(Texts.TravelSummary(Visit."Project No.", Visit."Task No."));
        exit(Texts.WorkSummary(Visit."Project No.", Visit."Task No."));
    end;

    local procedure StopSummary(Hours: Decimal; Day: Date): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.StopSummary(Hours, Day));
    end;

    local procedure CompleteSummary(Visit: Record "Proj. Field Visit ori"; Mileage: Decimal; HasMileage: Boolean): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.CompleteSummary(Visit."Entry No.", Mileage, HasMileage));
    end;

    local procedure StopSteps() Steps: JsonArray
    begin
        Steps.Add('Projects.Visit.Complete');
        Steps.Add('Projects.Visit.SignOff');
        Steps.Add('Projects.FollowUp.Request');
        Steps.Add('Projects.MyTimeSheet.Submit');
    end;

    local procedure CompleteSteps() Steps: JsonArray
    begin
        Steps.Add('Projects.Visit.SignOff');
        Steps.Add('Projects.FollowUp.Request');
        Steps.Add('Projects.MyTimeSheet.Submit');
        Steps.Add('Projects.Usage.Submit');
    end;

    local procedure ReadText(KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure ReadCode(KeyName: Text; MaxLength: Integer) Result: Code[20]
    begin
        if MaxLength < 1 then
            exit;
        Result := CopyStr(ReadText(KeyName), 1, MaxStrLen(Result));
    end;

    local procedure ReadInteger(KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadDecimal(KeyName: Text): Decimal
    var
        Token: JsonToken;
        Raw: Text;
        Value: Decimal;
    begin
        // Hours are JSON numbers. AsText throws on a number, so read the compact token text.
        if not Payload.Get(KeyName, Token) then
            exit;
        if not Token.IsValue() then
            exit;
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '=', '"');
        if Evaluate(Value, Raw, 9) then
            exit(Value);
    end;

    local procedure ReadBoolean(KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadDateTime(KeyName: Text) Value: DateTime
    var
        Raw: Text;
    begin
        Raw := ReadText(KeyName);
        if Raw.EndsWith('Z') then
            Raw := CopyStr(Raw, 1, StrLen(Raw) - 1);
        Evaluate(Value, Raw, 9);
    end;

    local procedure JsonText(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
    end;
}
