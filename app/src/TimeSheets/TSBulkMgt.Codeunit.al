namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Posting;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;

/// <summary>
/// Time-sheet automation engine behind the <c>Projects.TimeSheet.*</c> message types.
/// Parameterized and made
/// to return counts so the operations can run unattended from a Job Queue or message
/// chain. These are BC-side operations — they call no external API.
/// </summary>
codeunit 70013576 "TS Bulk Mgt ori"
{
    Access = Internal;

    var
        WeekTok: Label 'Week %1', Comment = '%1 = week number|is-IS=Vika %1';

    /// <summary>
    /// Ensures every time-sheet resource has upcoming weekly time sheets, up to
    /// <paramref name="TargetAhead"/> sheets per resource (default 4).
    /// </summary>
    /// <param name="TargetAhead">Target number of sheets each resource should have. Values &lt;= 0 default to 4.</param>
    /// <returns>The number of time sheets created.</returns>
    procedure CreateUpcomingTimeSheets(TargetAhead: Integer) CreatedCount: Integer
    var
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        ExistingTimeSheet: Record "Time Sheet Header";
        TimeSheetHeader: Record "Time Sheet Header";
        NoSeries: Codeunit "No. Series";
        StartingDate: Date;
        EndingDate: Date;
        LastEndingDate: Date;
    begin
        if TargetAhead <= 0 then
            TargetAhead := 4;
        ResourcesSetup.Get();
        ResourcesSetup.TestField("Time Sheet Nos.");
        Resource.SetLoadFields("No.", "Time Sheet Owner User ID");
        Resource.SetRange(Blocked, false);
        Resource.SetRange("Use Time Sheet", true);
        if Resource.FindSet() then
            repeat
                ExistingTimeSheet.SetLoadFields("Ending Date");
                ExistingTimeSheet.SetRange("Owner User ID", Resource."Time Sheet Owner User ID");
                // Advance from the last sheet's end date each iteration (the legacy code
                // reused a stale end date, producing overlapping sheets). Resources with no
                // existing sheets start from the current week so they still get upcoming sheets.
                if ExistingTimeSheet.FindLast() then
                    LastEndingDate := ExistingTimeSheet."Ending Date"
                else
                    LastEndingDate := CalcDate('<-CW>', WorkDate()) - 1;
                while ExistingTimeSheet.Count() < TargetAhead do begin
                    StartingDate := LastEndingDate + 1;
                    EndingDate := CalcDate('<CW>', StartingDate);
                    TimeSheetHeader.Init();
                    TimeSheetHeader."No." := NoSeries.GetNextNo(ResourcesSetup."Time Sheet Nos.", StartingDate);
                    TimeSheetHeader."Starting Date" := StartingDate;
                    TimeSheetHeader."Ending Date" := EndingDate;
                    TimeSheetHeader.Validate("Resource No.", Resource."No.");
                    TimeSheetHeader.Description := StrSubstNo(WeekTok, Date2DWY(StartingDate, 2));
                    TimeSheetHeader.Insert(true);
                    LastEndingDate := EndingDate;
                    CreatedCount += 1;
                end;
            until Resource.Next() = 0;
    end;

    /// <summary>
    /// Submits and approves all open time-sheet lines whose sheet ends on or before
    /// <paramref name="EndingDateTo"/> (default work date).
    /// </summary>
    /// <param name="EndingDateTo">Upper bound for the sheet ending date. 0D defaults to the work date.</param>
    /// <returns>The number of time-sheet lines approved.</returns>
    procedure ApprovePendingTimeSheets(EndingDateTo: Date) ApprovedLineCount: Integer
    var
        TimeSheet: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
        TimeSheetApprovalMgt: Codeunit "Time Sheet Approval Management";
        TimeSheetMgt: Codeunit "Time Sheet Management";
    begin
        if EndingDateTo = 0D then
            EndingDateTo := WorkDate();
        TimeSheet.SetLoadFields("No.");
        TimeSheet.SetRange("Open Exists", true);
        TimeSheet.SetFilter("Ending Date", '<=%1', EndingDateTo);
        if TimeSheet.FindSet() then
            repeat
                TimeSheetMgt.SetTimeSheetNo(TimeSheet."No.", TimeSheetLine);
                if TimeSheetLine.FindSet(true) then
                    repeat
                        // Status is not filtered so submitting and approving (which both change
                        // Status) does not disrupt Next() — the same reason RejectPendingTimeSheets
                        // and ReopenTimeSheets test the status in code instead of in the recordset.
                        if TimeSheetLine.Status = TimeSheetLine.Status::Open then begin
                            TimeSheetApprovalMgt.Submit(TimeSheetLine);
                            TimeSheetApprovalMgt.Approve(TimeSheetLine);
                            ApprovedLineCount += 1;
                        end;
                    until TimeSheetLine.Next() = 0;
            until TimeSheet.Next() = 0;
    end;

    /// <summary>
    /// Rejects submitted time-sheet lines whose sheet ends on or before
    /// <paramref name="EndingDateTo"/> (default work date).
    /// </summary>
    /// <param name="EndingDateTo">Upper bound for the sheet ending date. 0D defaults to the work date.</param>
    /// <returns>The number of time-sheet lines rejected.</returns>
    procedure RejectPendingTimeSheets(EndingDateTo: Date) RejectedLineCount: Integer
    var
        TimeSheet: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
        TimeSheetApprovalMgt: Codeunit "Time Sheet Approval Management";
        TimeSheetMgt: Codeunit "Time Sheet Management";
    begin
        if EndingDateTo = 0D then
            EndingDateTo := WorkDate();
        TimeSheet.SetLoadFields("No.");
        TimeSheet.SetRange("Submitted Exists", true);
        TimeSheet.SetFilter("Ending Date", '<=%1', EndingDateTo);
        if TimeSheet.FindSet() then
            repeat
                TimeSheetMgt.SetTimeSheetNo(TimeSheet."No.", TimeSheetLine);
                if TimeSheetLine.FindSet(true) then
                    repeat
                        // Status is not filtered so rejecting (which changes Status) does not disrupt Next().
                        if TimeSheetLine.Status = TimeSheetLine.Status::Submitted then begin
                            TimeSheetApprovalMgt.Reject(TimeSheetLine);
                            RejectedLineCount += 1;
                        end;
                    until TimeSheetLine.Next() = 0;
            until TimeSheet.Next() = 0;
    end;

    /// <summary>
    /// Reopens submitted or approved time-sheet lines back to Open, on sheets ending on or
    /// before <paramref name="EndingDateTo"/> (default work date).
    /// </summary>
    /// <param name="EndingDateTo">Upper bound for the sheet ending date. 0D defaults to the work date.</param>
    /// <returns>The number of time-sheet lines reopened.</returns>
    procedure ReopenTimeSheets(EndingDateTo: Date) ReopenedLineCount: Integer
    var
        TimeSheet: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
        TimeSheetApprovalMgt: Codeunit "Time Sheet Approval Management";
        TimeSheetMgt: Codeunit "Time Sheet Management";
        WasPending: Boolean;
    begin
        if EndingDateTo = 0D then
            EndingDateTo := WorkDate();
        TimeSheet.SetLoadFields("No.");
        TimeSheet.SetFilter("Ending Date", '<=%1', EndingDateTo);
        if TimeSheet.FindSet() then
            repeat
                TimeSheetMgt.SetTimeSheetNo(TimeSheet."No.", TimeSheetLine);
                if TimeSheetLine.FindSet(true) then
                    repeat
                        // Posted lines are final: Business Central refuses to reopen them, so they must not abort the whole run.
                        WasPending := (not TimeSheetLine.Posted) and (TimeSheetLine.Status in [TimeSheetLine.Status::Submitted, TimeSheetLine.Status::Approved]);
                        // Approved -> Submitted, then Submitted -> Open, so a fully approved line lands back on Open.
                        if WasPending then begin
                            if TimeSheetLine.Status = TimeSheetLine.Status::Approved then
                                TimeSheetApprovalMgt.ReopenApproved(TimeSheetLine);
                            if TimeSheetLine.Status = TimeSheetLine.Status::Submitted then
                                TimeSheetApprovalMgt.ReopenSubmitted(TimeSheetLine);
                        end;
                        if WasPending then
                            ReopenedLineCount += 1;
                    until TimeSheetLine.Next() = 0;
            until TimeSheet.Next() = 0;
    end;

    /// <summary>
    /// Transfers approved, unposted time-sheet detail to the given Job Journal batch and
    /// posts each line.
    /// </summary>
    /// <param name="JournalTemplateName">The Job Journal template to post through.</param>
    /// <param name="JournalBatchName">The Job Journal batch to post through.</param>
    /// <returns>The number of Job Journal lines posted.</returns>
    procedure PostApprovedTimeSheets(JournalTemplateName: Code[10]; JournalBatchName: Code[10]) PostedLineCount: Integer
    var
        JobJnlTemplate: Record "Job Journal Template";
        JobJnlBatch: Record "Job Journal Batch";
        JobJnlLine: Record "Job Journal Line";
        TimeSheetDetail: Record "Time Sheet Detail";
        TimeSheetHeader: Record "Time Sheet Header";
        TempTimeSheetLine: Record "Time Sheet Line" temporary;
        NoSeries: Codeunit "No. Series";
        JobJournalPostLine: Codeunit "Job Jnl.-Post Line";
        NextDocNo: Code[20];
        QtyToPost: Decimal;
    begin
        JobJnlTemplate.Get(JournalTemplateName);
        JobJnlBatch.Get(JournalTemplateName, JournalBatchName);
        FillApprovedLineBuffer(TempTimeSheetLine);
        if TempTimeSheetLine.FindSet() then begin
            JobJnlLine.LockTable();
            if JobJnlBatch."No. Series" = '' then
                NextDocNo := ''
            else
                NextDocNo := NoSeries.GetNextNo(JobJnlBatch."No. Series", TempTimeSheetLine."Time Sheet Starting Date");

            TimeSheetHeader.SetLoadFields("Resource No.");
            repeat
                TimeSheetHeader.Get(TempTimeSheetLine."Time Sheet No.");
                TimeSheetDetail.SetRange("Time Sheet No.", TempTimeSheetLine."Time Sheet No.");
                TimeSheetDetail.SetRange("Time Sheet Line No.", TempTimeSheetLine."Line No.");
                TimeSheetDetail.SetFilter(Quantity, '<>0');
                TimeSheetDetail.SetRange(Posted, false);
                if TimeSheetDetail.FindSet() then
                    repeat
                        QtyToPost := TimeSheetDetail.GetMaxQtyToPost();
                        if QtyToPost <> 0 then begin
                            JobJnlLine.Init();
                            JobJnlLine."Journal Template Name" := JobJnlBatch."Journal Template Name";
                            JobJnlLine."Journal Batch Name" := JobJnlBatch.Name;
                            JobJnlLine."Time Sheet No." := TimeSheetDetail."Time Sheet No.";
                            JobJnlLine."Time Sheet Line No." := TimeSheetDetail."Time Sheet Line No.";
                            JobJnlLine."Time Sheet Date" := TimeSheetDetail.Date;
                            JobJnlLine.Validate("Line Type", JobJnlLine."Line Type"::"Both Budget and Billable");
                            JobJnlLine.Validate("Job No.", TimeSheetDetail."Job No.");
                            JobJnlLine."Source Code" := JobJnlTemplate."Source Code";
                            if TimeSheetDetail."Job Task No." <> '' then
                                JobJnlLine.Validate("Job Task No.", TimeSheetDetail."Job Task No.");
                            JobJnlLine.Validate(Type, JobJnlLine.Type::Resource);
                            JobJnlLine.Validate("No.", TimeSheetHeader."Resource No.");
                            if TempTimeSheetLine."Work Type Code" <> '' then
                                JobJnlLine.Validate("Work Type Code", TempTimeSheetLine."Work Type Code");
                            JobJnlLine.Validate("Posting Date", TimeSheetDetail.Date);
                            JobJnlLine."Document No." := NextDocNo;
                            NextDocNo := IncStr(NextDocNo);
                            JobJnlLine."Posting No. Series" := JobJnlBatch."Posting No. Series";
                            JobJnlLine.Description := TempTimeSheetLine.Description;
                            JobJnlLine.Validate(Quantity, QtyToPost);
                            JobJnlLine.Validate(Chargeable, TempTimeSheetLine.Chargeable);
                            JobJnlLine."Reason Code" := JobJnlBatch."Reason Code";
                            // The native/legacy message runner owns the transaction boundary.
                            // A nested captured Codeunit.Run is invalid after number-series writes
                            // and used to hide a failed posting as a successful zero count.
                            JobJournalPostLine.RunWithCheck(JobJnlLine);
                            PostedLineCount += 1;
                        end;
                    until TimeSheetDetail.Next() = 0;
            until TempTimeSheetLine.Next() = 0;
        end;
    end;

    /// <summary>
    /// Counts the Job Journal lines PostApprovedTimeSheets would create right now, without writing:
    /// one per unposted time sheet detail with a quantity left to post on an approved job line.
    /// </summary>
    /// <returns>The number of Job Journal lines a post would create; equals postedLines of a successful post.</returns>
    procedure CountPostableLines() LineCount: Integer
    var
        TimeSheetDetail: Record "Time Sheet Detail";
        TempTimeSheetLine: Record "Time Sheet Line" temporary;
    begin
        FillApprovedLineBuffer(TempTimeSheetLine);
        if TempTimeSheetLine.FindSet() then
            repeat
                TimeSheetDetail.SetRange("Time Sheet No.", TempTimeSheetLine."Time Sheet No.");
                TimeSheetDetail.SetRange("Time Sheet Line No.", TempTimeSheetLine."Line No.");
                TimeSheetDetail.SetFilter(Quantity, '<>0');
                TimeSheetDetail.SetRange(Posted, false);
                if TimeSheetDetail.FindSet() then
                    repeat
                        if TimeSheetDetail.GetMaxQtyToPost() <> 0 then
                            LineCount += 1;
                    until TimeSheetDetail.Next() = 0;
            until TempTimeSheetLine.Next() = 0;
    end;

    /// <summary>
    /// Archives time sheets that are fully posted and no longer open, and removes empty
    /// posted sheets. Runs on sheets ending before the work date.
    /// </summary>
    /// <returns>The number of time sheets moved to the archive.</returns>
    procedure ArchivePostedTimeSheets() ArchivedCount: Integer
    var
        TimeSheet: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
        TimeSheetMgt: Codeunit "Time Sheet Management";
    begin
        TimeSheet.SetRange("Open Exists", false);
        TimeSheet.SetFilter("Ending Date", '<%1', WorkDate());
        if TimeSheet.FindSet() then
            repeat
                TimeSheetLine.SetRange("Time Sheet No.", TimeSheet."No.");
                TimeSheetLine.SetRange(Posted);
                if TimeSheetLine.IsEmpty() then
                    TimeSheet.Delete(true)
                else begin
                    TimeSheetLine.SetRange(Posted, false);
                    if TimeSheetLine.IsEmpty() then begin
                        TimeSheetMgt.MoveTimeSheetToArchive(TimeSheet);
                        ArchivedCount += 1;
                    end;
                end;
            until TimeSheet.Next() = 0;
    end;

    local procedure FillApprovedLineBuffer(var TempTimeSheetLine: Record "Time Sheet Line" temporary)
    var
        TimeSheetHeader: Record "Time Sheet Header";
        TimeSheetLine: Record "Time Sheet Line";
    begin
        TimeSheetHeader.SetLoadFields("No.");
        TimeSheetHeader.ReadIsolation := IsolationLevel::ReadCommitted;
        if TimeSheetHeader.FindSet() then
            repeat
                TimeSheetLine.SetRange("Time Sheet No.", TimeSheetHeader."No.");
                TimeSheetLine.SetRange(Type, TimeSheetLine.Type::Job);
                TimeSheetLine.SetRange(Status, TimeSheetLine.Status::Approved);
                TimeSheetLine.SetRange(Posted, false);
                if TimeSheetLine.FindSet() then
                    repeat
                        TempTimeSheetLine := TimeSheetLine;
                        TempTimeSheetLine.Insert();
                    until TimeSheetLine.Next() = 0;
            until TimeSheetHeader.Next() = 0;
    end;
}
