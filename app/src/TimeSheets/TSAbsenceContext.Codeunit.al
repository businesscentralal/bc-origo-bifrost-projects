namespace Origo.Bifrost.Projects;

/// <summary>
/// Session state for one native time-sheet write. The runner reads it inside
/// Codeunit.Run so a failed write rolls back without a raw error to the caller.
/// </summary>
codeunit 70013551 "TS Absence Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Operation: Integer;
        SheetNo: Code[20];
        HoursText: Text;
        CauseCode: Code[10];
        FlagNonWorking: Boolean;
        ResultText: Text;

    /// <summary>Drops the previous call so a later message cannot reuse it.</summary>
    procedure Clear()
    begin
        ClearAll();
    end;

    /// <summary>Stores an absence registration. Hours text is date|quantity pairs separated by ;.</summary>
    procedure SetAbsence(NewSheetNo: Code[20]; NewCause: Code[10]; NewHours: Text; NonWorking: Boolean)
    begin
        ClearAll();
        Operation := 6;
        SheetNo := NewSheetNo;
        CauseCode := NewCause;
        HoursText := NewHours;
        FlagNonWorking := NonWorking;
    end;

    /// <summary>Returns the operation selected for the isolated writer.</summary>
    procedure GetOperation(): Integer
    begin
        exit(Operation);
    end;

    /// <summary>Returns the validated time sheet number.</summary>
    procedure GetSheetNo(): Code[20]
    begin
        exit(SheetNo);
    end;

    /// <summary>Returns the validated daily hours.</summary>
    procedure GetHoursText(): Text
    begin
        exit(HoursText);
    end;

    /// <summary>Returns the validated cause of absence.</summary>
    procedure GetCause(): Code[10]
    begin
        exit(CauseCode);
    end;

    /// <summary>Indicates whether the request includes weekend hours.</summary>
    procedure GetFlagNonWorking(): Boolean
    begin
        exit(FlagNonWorking);
    end;

    /// <summary>Stores the writer response for the dispatcher.</summary>
    procedure SetResult(NewResult: Text)
    begin
        ResultText := NewResult;
    end;

    /// <summary>Returns the isolated writer response.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;
}
