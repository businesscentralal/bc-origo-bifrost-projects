namespace Origo.Bifrost.Projects;

/// <summary>
/// Session state for one native time-sheet write. The runner reads it inside
/// Codeunit.Run so a failed write rolls back without a raw error to the caller.
/// </summary>
codeunit 70013565 "TS Native Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Operation: Integer;
        SheetNo: Code[20];
        LineFilter: Text;
        CommentText: Text;
        ResultText: Text;
        StartDate: Date;
        JournalTemplate: Code[10];
        JournalBatch: Code[10];

    /// <summary>Drops the previous call so a later message cannot reuse it.</summary>
    /// <summary>Clear for the time sheet decision contract.</summary>
    procedure Clear()
    begin
        ClearAll();
    end;

    /// <summary>SetApprove for the time sheet decision contract.</summary>
    procedure SetApprove(NewSheetNo: Code[20]; NewLineFilter: Text)
    begin
        ClearAll();
        Operation := 2;
        SheetNo := NewSheetNo;
        LineFilter := NewLineFilter;
    end;

    /// <summary>SetReject for the time sheet decision contract.</summary>
    procedure SetReject(NewSheetNo: Code[20]; NewLineFilter: Text; NewComment: Text)
    begin
        ClearAll();
        Operation := 3;
        SheetNo := NewSheetNo;
        LineFilter := NewLineFilter;
        CommentText := NewComment;
    end;

    /// <summary>GetOperation for the time sheet decision contract.</summary>
    procedure GetOperation(): Integer
    begin
        exit(Operation);
    end;

    /// <summary>GetSheetNo for the time sheet decision contract.</summary>
    procedure GetSheetNo(): Code[20]
    begin
        exit(SheetNo);
    end;

    /// <summary>GetLineFilter for the time sheet decision contract.</summary>
    procedure GetLineFilter(): Text
    begin
        exit(LineFilter);
    end;

    /// <summary>GetComment for the time sheet decision contract.</summary>
    procedure GetComment(): Text
    begin
        exit(CommentText);
    end;

    /// <summary>SetResult for the time sheet decision contract.</summary>
    procedure SetResult(NewResult: Text)
    begin
        ResultText := NewResult;
    end;

    /// <summary>GetResult for the time sheet decision contract.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;

    /// <summary>Stores a bulk reopen through the existing time sheet engine.</summary>
    procedure SetReopen(EndingDateTo: Date)
    begin
        ClearAll();
        Operation := 8;
        StartDate := EndingDateTo;
    end;

    /// <summary>Stores a bulk post through the existing job journal engine.</summary>
    procedure SetPost(NewJournalTemplate: Code[10]; NewJournalBatch: Code[10])
    begin
        ClearAll();
        Operation := 9;
        JournalTemplate := NewJournalTemplate;
        JournalBatch := NewJournalBatch;
    end;

    /// <summary>Stores a bulk archive through the existing time sheet engine.</summary>
    procedure SetArchive()
    begin
        ClearAll();
        Operation := 10;
    end;

    /// <summary>Returns the validated job journal template.</summary>
    procedure GetJournalTemplate(): Code[10]
    begin
        exit(JournalTemplate);
    end;

    /// <summary>Returns the validated job journal batch.</summary>
    procedure GetJournalBatch(): Code[10]
    begin
        exit(JournalBatch);
    end;

    procedure GetStartDate(): Date
    begin
        exit(StartDate);
    end;

    /// <summary>Handles SetSubmit for the Submit message contract.</summary>
    procedure SetSubmit(NewSheetNo: Code[20]; NewLineFilter: Text)
    begin
        ClearAll();
        Operation := 1;
        SheetNo := NewSheetNo;
        LineFilter := NewLineFilter;
    end;
}
