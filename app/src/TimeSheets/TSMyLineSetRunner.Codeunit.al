namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>
/// Write isolation for Projects.MyTimeSheetLine.Set (projects#38). The manager validates the whole
/// request first and then calls Run() on this instance, so a native validation error rolls back every
/// line of the call. The runner re-checks ownership and line status before each write.
/// </summary>
codeunit 70013590 "TS My Line Set Runner ori"
{
    Access = Internal;

    var
        SheetNo: Code[20];
        Entries: JsonArray;
        Results: JsonArray;
        NotOwnerErr: Label 'The time sheet does not belong to the caller.', Comment = 'is-IS=Tímaskýrslan tilheyrir ekki kallanda.';
        LockedLineErr: Label 'Only open or rejected lines can be changed.', Comment = 'is-IS=Aðeins er hægt að breyta opnum eða höfnuðum línum.';

    trigger OnRun()
    var
        Header: Record "Time Sheet Header";
        Entry: JsonToken;
    begin
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(SheetNo);
        if (Header."Owner User ID" = '') or (Header."Owner User ID" <> CopyStr(UpperCase(UserId()), 1, MaxStrLen(Header."Owner User ID"))) then
            Error(ErrorInfo.Create(NotOwnerErr));
        foreach Entry in Entries do
            Results.Add(ApplyEntry(Header, Entry.AsObject()));
    end;

    /// <summary>Stores the validated request for the next Run().</summary>
    procedure SetRequest(NewSheetNo: Code[20]; NewEntries: JsonArray)
    begin
        SheetNo := NewSheetNo;
        Entries := NewEntries;
        Clear(Results);
    end;

    /// <summary>Returns one result node per written line.</summary>
    procedure GetResults(): JsonArray
    begin
        exit(Results);
    end;

    local procedure ApplyEntry(Header: Record "Time Sheet Header"; Entry: JsonObject) Result: JsonObject
    var
        Line: Record "Time Sheet Line";
        Token: JsonToken;
        Created: Boolean;
    begin
        if Entry.Get('lineNo', Token) then begin
            Line.ReadIsolation := IsolationLevel::UpdLock;
            Line.Get(Header."No.", Token.AsValue().AsInteger());
            if not (Line.Status in [Line.Status::Open, Line.Status::Rejected]) then
                Error(ErrorInfo.Create(LockedLineErr));
            // An edited rejected line goes back to Open so the owner can submit it again.
            if Line.Status = Line.Status::Rejected then begin
                Line.Status := Line.Status::Open;
                Line.Modify(false);
                ReopenDetails(Line);
            end;
        end else begin
            Line.Init();
            Line."Time Sheet No." := Header."No.";
            Line."Line No." := NextLineNo(Header."No.");
            Line."Time Sheet Starting Date" := Header."Starting Date";
            Line.Insert(true);
            if Entry.Get('type', Token) then
                case Token.AsValue().AsText() of
                    'Job':
                        Line.Validate(Type, Line.Type::Job);
                    'Resource':
                        Line.Validate(Type, Line.Type::Resource);
                end;
            Created := true;
        end;
        if Entry.Get('projectNo', Token) then
            Line.Validate("Job No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Job No.")));
        if Entry.Get('taskNo', Token) then
            Line.Validate("Job Task No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Job Task No.")));
        if Entry.Get('workTypeCode', Token) then
            Line.Validate("Work Type Code", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Work Type Code")));
        if Entry.Get('description', Token) then
            Line.Validate(Description, CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line.Description)));
        Line.Modify(true);
        if Entry.Get('days', Token) then
            SetDays(Line, Token.AsArray());
        Result.Add('lineNo', Line."Line No.");
        Result.Add('created', Created);
        Result.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
        Result.Add('totalHours', TotalHours(Line));
    end;

    local procedure SetDays(Line: Record "Time Sheet Line"; Days: JsonArray)
    var
        Detail: Record "Time Sheet Detail";
        Day: JsonToken;
        DayDate: Date;
        Hours: Decimal;
        DayObject: JsonObject;
    begin
        foreach Day in Days do begin
            DayObject := Day.AsObject();
            Evaluate(DayDate, DayObject.GetText('date'), 9);
            Hours := DayObject.GetDecimal('hours');
            Detail.ReadIsolation := IsolationLevel::UpdLock;
            if Detail.Get(Line."Time Sheet No.", Line."Line No.", DayDate) then begin
                // Zero hours keeps the day with 0; this type never deletes records.
                Detail.Validate(Quantity, Hours);
                Detail.Modify(true);
            end else
                if Hours <> 0 then begin
                    Detail.Init();
                    Detail.CopyFromTimeSheetLine(Line);
                    Detail.Date := DayDate;
                    Detail.Validate(Quantity, Hours);
                    Detail.Insert(true);
                end;
        end;
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

    local procedure TotalHours(Line: Record "Time Sheet Line"): Decimal
    var
        Detail: Record "Time Sheet Detail";
    begin
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        Detail.CalcSums(Quantity);
        exit(Detail.Quantity);
    end;
}
