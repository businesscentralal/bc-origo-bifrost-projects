namespace Origo.Bifrost.Projects;

/// <summary>Session-local request and response state for an isolated time-sheet fill operation.</summary>
codeunit 70013559 "TS Fill Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        SheetNo: Code[20];
        FromPlanning: Boolean;
        Active: Boolean;
        ResultText: Text;

    /// <summary>Clears request and result state after success or refusal.</summary>
    procedure Clear()
    begin
        ClearAll();
    end;

    /// <summary>Starts one owner-authorized fill operation.</summary>
    procedure SetFill(NewSheetNo: Code[20]; NewFromPlanning: Boolean)
    begin
        ClearAll();
        SheetNo := NewSheetNo;
        FromPlanning := NewFromPlanning;
        Active := true;
    end;

    /// <summary>Returns the destination time sheet.</summary>
    procedure GetSheetNo(): Code[20]
    begin
        exit(SheetNo);
    end;

    /// <summary>Whether this operation fills from project planning.</summary>
    procedure GetFromPlanning(): Boolean
    begin
        exit(FromPlanning);
    end;

    /// <summary>Limits empty-hours handling to this message's destination sheet.</summary>
    procedure IsCopyDestination(TimeSheetNo: Code[20]): Boolean
    begin
        exit(Active and not FromPlanning and (TimeSheetNo = SheetNo));
    end;

    /// <summary>Stores the response only after native processing succeeds.</summary>
    procedure SetResult(NewResult: Text)
    begin
        ResultText := NewResult;
    end;

    /// <summary>Reads the successful isolated operation result.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;
}
