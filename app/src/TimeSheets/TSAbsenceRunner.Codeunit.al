namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>
/// Write isolation for the native time-sheet message types. OnRun is started with
/// Codeunit.Run. A platform error rolls the write back and the caller maps it to a
/// clean refusal. This codeunit does not re-check the request; the manager did that.
/// </summary>
codeunit 70013555 "TS Absence Runner ori"
{
    Access = Internal;

    trigger OnRun()
    var
        Context: Codeunit "TS Absence Context ori";
    begin
        case Context.GetOperation() of
            6:
                RegisterAbsence(Context);
            else
                Error(InvalidLineTok);
        end;
    end;

    var
        InvalidLineTok: Label 'InvalidLine', Locked = true;
        NonWorkingMsg: Label 'Hours fall on a non-working day.', Comment = 'is-IS=Klukkustundir lenda á degi sem er ekki vinnudagur.';
        NonWorkingNextTxt: Label 'Confirm the date or move the hours to a working day.', Comment = 'is-IS=Staðfestu dagsetninguna eða færðu klukkustundirnar á vinnudag.';

    local procedure RegisterAbsence(Context: Codeunit "TS Absence Context ori")
    var
        Header: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Pair: Text;
        DateText: Text;
        QtyText: Text;
        Hours: JsonArray;
        Hour: JsonObject;
        Response: JsonObject;
        Warnings: JsonArray;
        Warning: JsonObject;
        WorkDateValue: Date;
        Quantity: Decimal;
        LineNo: Integer;
        PairPos: Integer;
    begin
        Header.LockTable();
        Header.Get(Context.GetSheetNo());
        TimeSheetLine.SetRange("Time Sheet No.", Header."No.");
        if TimeSheetLine.FindLast() then
            LineNo := TimeSheetLine."Line No." + 10000
        else
            LineNo := 10000;
        TimeSheetLine.Init();
        TimeSheetLine."Time Sheet No." := Header."No.";
        TimeSheetLine."Line No." := LineNo;
        TimeSheetLine."Time Sheet Starting Date" := Header."Starting Date";
        TimeSheetLine.Validate(Type, TimeSheetLine.Type::Absence);
        TimeSheetLine.Validate("Cause of Absence Code", Context.GetCause());
        TimeSheetLine.Insert(true);

        foreach Pair in Context.GetHoursText().Split(';') do begin
            PairPos := StrPos(Pair, '|');
            DateText := CopyStr(Pair, 1, PairPos - 1);
            QtyText := CopyStr(Pair, PairPos + 1);
            Evaluate(WorkDateValue, DateText, 9);
            Evaluate(Quantity, QtyText, 9);
            Detail.Init();
            Detail.CopyFromTimeSheetLine(TimeSheetLine);
            if (WorkDateValue < Header."Starting Date") or (WorkDateValue > Header."Ending Date") then
                Error(InvalidLineTok);
            Detail.Validate(Date, WorkDateValue);
            Detail.Validate(Quantity, Quantity);
            Detail.Insert(true);
            Clear(Hour);
            Hour.Add('date', DateText);
            Hour.Add('quantity', Quantity);
            Hours.Add(Hour);
        end;

        Response.Add('status', 'Success');
        Response.Add('timeSheetNo', Header."No.");
        Response.Add('lineNo', LineNo);
        Response.Add('causeOfAbsenceCode', Context.GetCause());
        Response.Add('resourceNo', Header."Resource No.");
        Response.Add('hours', Hours);
        if Context.GetFlagNonWorking() then begin
            Warning.Add('code', 'InvalidParameter');
            Warning.Add('message', NonWorkingMsg);
            Warning.Add('parameter', 'hours');
            Warning.Add('nextStep', NonWorkingNextTxt);
            Warnings.Add(Warning);
            Response.Add('warnings', Warnings);
        end;
        Context.SetResult(JsonText(Response));
    end;

    local procedure JsonText(Response: JsonObject): Text
    var
        Result: Text;
    begin
        Response.WriteTo(Result);
        exit(Result);
    end;
}
