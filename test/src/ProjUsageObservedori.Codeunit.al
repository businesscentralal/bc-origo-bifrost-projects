namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Posting;

/// <summary>Observes native ledger insertion in memory so rollback tests prove an earlier line actually ran.</summary>
codeunit 97130 "Proj. Usage Observed ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        OwnedProjectNo: Code[20];
        Observed: Integer;

    /// <summary>Scopes the observation to the fresh project owned by the current test.</summary>
    procedure ObserveProject(ProjectNo: Code[20])
    begin
        OwnedProjectNo := ProjectNo;
        Observed := 0;
    end;

    /// <summary>Returns event observations retained outside the rolled-back database transaction.</summary>
    procedure ObservedCount(): Integer
    begin
        exit(Observed);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Jnl.-Post Line", 'OnAfterJobLedgEntryInsert', '', false, false)]
    local procedure OnNativeInsert(var JobLedgerEntry: Record "Job Ledger Entry"; JobJournalLine: Record "Job Journal Line")
    begin
        if (JobLedgerEntry."Job No." = OwnedProjectNo) and (JobJournalLine."Job No." = OwnedProjectNo) then
            Observed += 1;
    end;
}
