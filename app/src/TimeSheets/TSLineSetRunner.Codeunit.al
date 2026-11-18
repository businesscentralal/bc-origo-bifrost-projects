namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>
/// Write isolation for Projects.TimeSheetLine.Set. OnRun is started with Codeunit.Run.
/// Every field goes through Validate, so Business Central's own rules apply. A platform
/// error on any line rolls back the whole call and the manager maps it to a refusal.
/// </summary>
codeunit 70013594 "TS Line Set Runner ori"
{
    Access = Internal;

    trigger OnRun()
    var
        Header: Record "Time Sheet Header";
        Context: Codeunit "TS Line Set Context ori";
        Entry: JsonToken;
        Lines: JsonArray;
        Request: JsonArray;
        Response: JsonObject;
        ResultText: Text;
    begin
        Header.LockTable();
        Header.Get(Context.GetSheetNo());
        Request.ReadFrom(Context.GetLinesText());
        foreach Entry in Request do
            Lines.Add(WriteLine(Header, Entry.AsObject()));
        Response.Add('status', 'Success');
        Response.Add('timeSheetNo', Header."No.");
        Response.Add('resourceNo', Header."Resource No.");
        Response.Add('lines', Lines);
        Response.WriteTo(ResultText);
        Context.SetResult(ResultText);
    end;

    local procedure WriteLine(Header: Record "Time Sheet Header"; LineJson: JsonObject): JsonObject
    var
        Line: Record "Time Sheet Line";
        Mgt: Codeunit "TS Line Set Mgt ori";
        LineType: Enum "Time Sheet Line Type";
        Token: JsonToken;
        IsNew: Boolean;
    begin
        IsNew := not LineJson.Get('lineNo', Token);
        if IsNew then begin
            LineJson.Get('type', Token);
            Mgt.TryParseLineType(Token.AsValue().AsText(), LineType);
            Line.Init();
            Line."Time Sheet No." := Header."No.";
            Line."Line No." := NextLineNo(Header."No.");
            Line."Time Sheet Starting Date" := Header."Starting Date";
            Line.Validate(Type, LineType);
            ApplyFields(Line, LineJson);
            Line.Insert(true);
        end else begin
            Line.ReadIsolation := IsolationLevel::UpdLock;
            Line.Get(Header."No.", Token.AsValue().AsInteger());
            Line.TestStatus();
            Line.TestField(Posted, false);
            ApplyFields(Line, LineJson);
            Line.Modify(true);
        end;
        ApplyHours(Line, LineJson);
        exit(LineNode(Line, IsNew));
    end;

    local procedure ApplyFields(var Line: Record "Time Sheet Line"; LineJson: JsonObject)
    var
        Token: JsonToken;
    begin
        // Project before task: Business Central clears the task when the project changes.
        if LineJson.Get('projectNo', Token) then
            Line.Validate("Job No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Job No.")));
        if LineJson.Get('projectTaskNo', Token) then
            Line.Validate("Job Task No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Job Task No.")));
        if LineJson.Get('causeOfAbsenceCode', Token) then
            Line.Validate("Cause of Absence Code", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Cause of Absence Code")));
        if LineJson.Get('serviceOrderNo', Token) then
            Line.Validate("Service Order No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Service Order No.")));
        if LineJson.Get('workTypeCode', Token) then
            Line.Validate("Work Type Code", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line."Work Type Code")));
        // Description last: the task and cause set their own description first.
        if LineJson.Get('description', Token) then
            Line.Validate(Description, CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Line.Description)));
        if LineJson.Get('chargeable', Token) then
            Line.Validate(Chargeable, Token.AsValue().AsBoolean());
    end;

    local procedure ApplyHours(Line: Record "Time Sheet Line"; LineJson: JsonObject)
    var
        Detail: Record "Time Sheet Detail";
        DateToken: JsonToken;
        Entry: JsonToken;
        HoursToken: JsonToken;
        QtyToken: JsonToken;
        HourDate: Date;
        Quantity: Decimal;
    begin
        if not LineJson.Get('hours', HoursToken) then
            exit;
        foreach Entry in HoursToken.AsArray() do begin
            Entry.AsObject().Get('date', DateToken);
            Entry.AsObject().Get('quantity', QtyToken);
            Evaluate(HourDate, DateToken.AsValue().AsText(), 9);
            Quantity := QtyToken.AsValue().AsDecimal();
            // Zero keeps the day with zero hours: this type never deletes a record.
            if Detail.Get(Line."Time Sheet No.", Line."Line No.", HourDate) then begin
                if Detail.Quantity <> Quantity then begin
                    Detail.Validate(Quantity, Quantity);
                    Detail.Modify(true);
                end;
            end else
                if Quantity <> 0 then begin
                    Detail.Init();
                    Detail.CopyFromTimeSheetLine(Line);
                    Detail.Validate(Date, HourDate);
                    Detail.Validate(Quantity, Quantity);
                    Detail.Insert(true);
                end;
        end;
    end;

    local procedure NextLineNo(SheetNo: Code[20]): Integer
    var
        Line: Record "Time Sheet Line";
    begin
        Line.SetRange("Time Sheet No.", SheetNo);
        if Line.FindLast() then
            exit(Line."Line No." + 10000);
        exit(10000);
    end;

    local procedure LineNode(Line: Record "Time Sheet Line"; Created: Boolean) Node: JsonObject
    var
        Detail: Record "Time Sheet Detail";
        Mgt: Codeunit "TS Line Set Mgt ori";
        Hour: JsonObject;
        Hours: JsonArray;
    begin
        Line.Get(Line."Time Sheet No.", Line."Line No.");
        Line.CalcFields("Total Quantity");
        Node.Add('lineNo', Line."Line No.");
        Node.Add('type', Mgt.LineTypeToken(Line.Type));
        Node.Add('created', Created);
        Node.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
        Node.Add('projectNo', Line."Job No.");
        Node.Add('projectTaskNo', Line."Job Task No.");
        Node.Add('causeOfAbsenceCode', Line."Cause of Absence Code");
        Node.Add('serviceOrderNo', Line."Service Order No.");
        Node.Add('workTypeCode', Line."Work Type Code");
        Node.Add('description', Line.Description);
        Node.Add('chargeable', Line.Chargeable);
        Node.Add('totalQuantity', Line."Total Quantity");
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        if Detail.FindSet() then
            repeat
                Clear(Hour);
                Hour.Add('date', Format(Detail.Date, 0, 9));
                Hour.Add('quantity', Detail.Quantity);
                Hours.Add(Hour);
            until Detail.Next() = 0;
        Node.Add('hours', Hours);
    end;
}
