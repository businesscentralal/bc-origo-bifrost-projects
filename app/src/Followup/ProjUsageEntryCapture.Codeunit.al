namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Posting;

/// <summary>Captures only ledger entries created by the currently bound native journal source.</summary>
codeunit 70009247 "Proj. Usage Entry Capture ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        TempSource: Record "Job Journal Line" temporary;
        Entries: List of [Integer];

    /// <summary>Scopes the capture to one exact native journal source in this local binding.</summary>
    procedure ExpectSource(Journal: Record "Job Journal Line" temporary)
    begin
        TempSource := Journal;
    end;

    /// <summary>Returns the exact created ledger identifiers, including native cost-layer splits.</summary>
    procedure EntryNos() Result: JsonArray
    var
        EntryNo: Integer;
    begin
        foreach EntryNo in Entries do
            Result.Add(EntryNo);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Jnl.-Post Line", 'OnAfterJobLedgEntryInsert', '', false, false)]
    local procedure OnNativeLedgerInserted(var JobLedgerEntry: Record "Job Ledger Entry"; JobJournalLine: Record "Job Journal Line")
    begin
        if (JobJournalLine."Journal Template Name" <> TempSource."Journal Template Name") or
           (JobJournalLine."Journal Batch Name" <> TempSource."Journal Batch Name") or
           (JobJournalLine."Line No." <> TempSource."Line No.") or
           (JobJournalLine."Job No." <> TempSource."Job No.") or
           (JobJournalLine."Job Task No." <> TempSource."Job Task No.") or
           (JobJournalLine."Document No." <> TempSource."Document No.") then
            exit;
        if not Entries.Contains(JobLedgerEntry."Entry No.") then
            Entries.Add(JobLedgerEntry."Entry No.");
    end;
}
