namespace Origo.Bifrost.Projects;

/// <summary>
/// Session state for one Projects.TimeSheetLine.Set call. The runner reads it inside
/// Codeunit.Run so a failed write rolls back every line of the call.
/// </summary>
codeunit 70013595 "TS Line Set Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        SheetNo: Code[20];
        LinesText: Text;
        ResultText: Text;

    /// <summary>Drops the previous call so a later message cannot reuse it.</summary>
    procedure Clear()
    begin
        ClearAll();
    end;

    /// <summary>Stores the checked request for the runner.</summary>
    procedure SetRequest(NewSheetNo: Code[20]; NewLinesText: Text)
    begin
        ClearAll();
        SheetNo := NewSheetNo;
        LinesText := NewLinesText;
    end;

    /// <summary>Returns the time sheet number of the call.</summary>
    procedure GetSheetNo(): Code[20]
    begin
        exit(SheetNo);
    end;

    /// <summary>Returns the checked lines array as JSON text.</summary>
    procedure GetLinesText(): Text
    begin
        exit(LinesText);
    end;

    /// <summary>Stores the response the runner built.</summary>
    procedure SetResult(NewResult: Text)
    begin
        ResultText := NewResult;
    end;

    /// <summary>Returns the response the runner built.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;
}
