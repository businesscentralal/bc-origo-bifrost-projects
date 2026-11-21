namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.TimeSheet;

/// <summary>
/// Creates the journal lines for usage lines and follows them: a ledger entry marks the usage
/// Posted, deleting the journal line before posting returns the usage to Approved.
/// </summary>
codeunit 70013402 "TS Usage Journal ori"
{
    Access = Internal;
    Permissions = tabledata "TS Usage Line ori" = RM,
                  tabledata "Time Sheet Line" = R;

    /// <summary>Creates the journal line for one usage line (negative quantity when Reverse is true) and returns the journal line number.</summary>
    procedure CreateJournalLine(var Usage: Record "TS Usage Line ori"; Template: Code[10]; Batch: Code[10]; Reverse: Boolean; DocumentNo: Code[20]) JournalLineNo: Integer
    var
        TimeSheetLine: Record "Time Sheet Line";
    begin
        TimeSheetLine.SetLoadFields("Job No.", "Job Task No.");
        TimeSheetLine.Get(Usage."Time Sheet No.", Usage."Time Sheet Line No.");
        if TimeSheetLine."Job No." <> '' then
            exit(CreateJobLine(Usage, TimeSheetLine, Template, Batch, Reverse, DocumentNo));
        if Usage.Type = Usage.Type::Item then
            exit(CreateItemLine(Usage, Template, Batch, Reverse, DocumentNo));
        exit(CreateResourceLine(Usage, Template, Batch, Reverse, DocumentNo));
    end;

    /// <summary>True when the usage goes to the Job Journal because its time sheet line has a project.</summary>
    procedure GoesToJobJournal(Usage: Record "TS Usage Line ori"): Boolean
    var
        TimeSheetLine: Record "Time Sheet Line";
    begin
        TimeSheetLine.SetLoadFields("Job No.");
        TimeSheetLine.Get(Usage."Time Sheet No.", Usage."Time Sheet Line No.");
        exit(TimeSheetLine."Job No." <> '');
    end;

    local procedure Signed(Usage: Record "TS Usage Line ori"; Reverse: Boolean): Decimal
    begin
        if Reverse then
            exit(-Usage.Quantity);
        exit(Usage.Quantity);
    end;

    local procedure CreateItemLine(Usage: Record "TS Usage Line ori"; Template: Code[10]; Batch: Code[10]; Reverse: Boolean; DocumentNo: Code[20]): Integer
    var
        ItemJnlTemplate: Record "Item Journal Template";
        Line: Record "Item Journal Line";
        LastLine: Record "Item Journal Line";
    begin
        ItemJnlTemplate.Get(Template);
        LastLine.SetRange("Journal Template Name", Template);
        LastLine.SetRange("Journal Batch Name", Batch);
        LastLine.SetLoadFields("Line No.");
        if LastLine.FindLast() then
            Line."Line No." := LastLine."Line No." + 10000
        else
            Line."Line No." := 10000;
        Line.Validate("Journal Template Name", Template);
        Line.Validate("Journal Batch Name", Batch);
        Line.Validate("Posting Date", Usage.Date);
        Line.Validate("Entry Type", Line."Entry Type"::"Negative Adjmt.");
        Line.Validate("Document No.", DocumentNo);
        Line.Validate("Item No.", Usage."No.");
        if Usage."Location Code" <> '' then
            Line.Validate("Location Code", Usage."Location Code");
        if (Usage."Bin Code" <> '') and BinMandatory(Usage."Location Code") then
            Line.Validate("Bin Code", Usage."Bin Code");
        if Usage."Unit of Measure Code" <> '' then
            Line.Validate("Unit of Measure Code", Usage."Unit of Measure Code");
        Line.Validate(Quantity, Signed(Usage, Reverse));
        Line.Description := Usage.Description;
        Line."Source Code" := ItemJnlTemplate."Source Code";
        Line.Insert(true);
        CreateTracking(Usage, Database::"Item Journal Line", Line."Entry Type".AsInteger(), Template, Batch, Line."Line No.", Line."Item No.", Line."Variant Code", Line."Location Code", Line.Description, Line."Posting Date", Line."Qty. per Unit of Measure", Line.Quantity, Line."Quantity (Base)");
        exit(Line."Line No.");
    end;

    local procedure CreateResourceLine(Usage: Record "TS Usage Line ori"; Template: Code[10]; Batch: Code[10]; Reverse: Boolean; DocumentNo: Code[20]): Integer
    var
        ResJnlTemplate: Record "Res. Journal Template";
        Line: Record "Res. Journal Line";
        LastLine: Record "Res. Journal Line";
    begin
        ResJnlTemplate.Get(Template);
        LastLine.SetRange("Journal Template Name", Template);
        LastLine.SetRange("Journal Batch Name", Batch);
        LastLine.SetLoadFields("Line No.");
        if LastLine.FindLast() then
            Line."Line No." := LastLine."Line No." + 10000
        else
            Line."Line No." := 10000;
        Line.Validate("Journal Template Name", Template);
        Line.Validate("Journal Batch Name", Batch);
        Line.Validate("Posting Date", Usage.Date);
        Line.Validate("Entry Type", Line."Entry Type"::Usage);
        Line.Validate("Document No.", DocumentNo);
        Line.Validate("Resource No.", Usage."No.");
        if Usage."Unit of Measure Code" <> '' then
            Line.Validate("Unit of Measure Code", Usage."Unit of Measure Code");
        Line.Validate(Quantity, Signed(Usage, Reverse));
        Line.Description := Usage.Description;
        Line."Source Code" := ResJnlTemplate."Source Code";
        Line.Insert(true);
        exit(Line."Line No.");
    end;

    local procedure CreateJobLine(Usage: Record "TS Usage Line ori"; TimeSheetLine: Record "Time Sheet Line"; Template: Code[10]; Batch: Code[10]; Reverse: Boolean; DocumentNo: Code[20]): Integer
    var
        JobJnlTemplate: Record "Job Journal Template";
        Line: Record "Job Journal Line";
        LastLine: Record "Job Journal Line";
    begin
        JobJnlTemplate.Get(Template);
        LastLine.SetRange("Journal Template Name", Template);
        LastLine.SetRange("Journal Batch Name", Batch);
        LastLine.SetLoadFields("Line No.");
        if LastLine.FindLast() then
            Line."Line No." := LastLine."Line No." + 10000
        else
            Line."Line No." := 10000;
        Line.Validate("Journal Template Name", Template);
        Line.Validate("Journal Batch Name", Batch);
        Line.Validate("Line Type", Line."Line Type"::Budget);
        Line.Validate("Posting Date", Usage.Date);
        Line.Validate("Document No.", DocumentNo);
        Line.Validate("Job No.", TimeSheetLine."Job No.");
        Line.Validate("Job Task No.", TimeSheetLine."Job Task No.");
        if Usage.Type = Usage.Type::Item then
            Line.Validate(Type, Line.Type::Item)
        else
            Line.Validate(Type, Line.Type::Resource);
        Line.Validate("No.", Usage."No.");
        if Usage."Location Code" <> '' then
            Line.Validate("Location Code", Usage."Location Code");
        if (Usage."Bin Code" <> '') and BinMandatory(Usage."Location Code") then
            Line.Validate("Bin Code", Usage."Bin Code");
        if Usage."Unit of Measure Code" <> '' then
            Line.Validate("Unit of Measure Code", Usage."Unit of Measure Code");
        Line.Validate(Quantity, Signed(Usage, Reverse));
        Line.Description := Usage.Description;
        Line."Source Code" := JobJnlTemplate."Source Code";
        Line.Insert(true);
        if Usage.Type = Usage.Type::Item then
            CreateTracking(Usage, Database::"Job Journal Line", Line."Entry Type".AsInteger(), Template, Batch, Line."Line No.", Line."No.", Line."Variant Code", Line."Location Code", Line.Description, Line."Posting Date", Line."Qty. per Unit of Measure", Line.Quantity, Line."Quantity (Base)");
        exit(Line."Line No.");
    end;

    local procedure BinMandatory(LocationCode: Code[10]): Boolean
    var
        Location: Record Location;
    begin
        // A journal line takes a bin only at a bin-mandatory location; the usage line keeps the bin either way.
        if LocationCode = '' then
            exit(false);
        Location.SetLoadFields("Bin Mandatory");
        exit(Location.Get(LocationCode) and Location."Bin Mandatory");
    end;

    local procedure CreateTracking(Usage: Record "TS Usage Line ori"; SourceType: Integer; SourceSubtype: Integer; Template: Code[10]; Batch: Code[10]; LineNo: Integer; ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; Description: Text[100]; PostingDate: Date; QtyPerUoM: Decimal; Quantity: Decimal; QuantityBase: Decimal)
    var
        Tracking: Record "Reservation Entry";
        CreateEntry: Codeunit "Create Reserv. Entry";
    begin
        if (Usage."Lot No." = '') and (Usage."Serial No." = '') then
            exit;
        Tracking."Lot No." := Usage."Lot No.";
        Tracking."Serial No." := Usage."Serial No.";
        CreateEntry.CreateReservEntryFor(SourceType, SourceSubtype, Template, Batch, 0, LineNo, QtyPerUoM, Quantity, QuantityBase, Tracking);
        CreateEntry.CreateEntry(ItemNo, VariantCode, LocationCode, Description, 0D, PostingDate, 0, "Reservation Status"::Surplus);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", OnAfterInsertEvent, '', false, false)]
    local procedure OnItemLedgerEntryInserted(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if CopyStr(Rec."Document No.", 1, 3) = 'TSU' then
            MarkPosted(Rec."Document No.", Rec."Entry No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Res. Ledger Entry", OnAfterInsertEvent, '', false, false)]
    local procedure OnResLedgerEntryInserted(var Rec: Record "Res. Ledger Entry"; RunTrigger: Boolean)
    begin
        if CopyStr(Rec."Document No.", 1, 3) = 'TSU' then
            MarkPosted(Rec."Document No.", Rec."Entry No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Job Ledger Entry", OnAfterInsertEvent, '', false, false)]
    local procedure OnJobLedgerEntryInserted(var Rec: Record "Job Ledger Entry"; RunTrigger: Boolean)
    begin
        if CopyStr(Rec."Document No.", 1, 3) = 'TSU' then
            MarkPosted(Rec."Document No.", Rec."Entry No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", OnAfterDeleteEvent, '', false, false)]
    local procedure OnItemJournalLineDeleted(var Rec: Record "Item Journal Line"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() then
            ReturnToApproved(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Line No.", Rec."Document No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Res. Journal Line", OnAfterDeleteEvent, '', false, false)]
    local procedure OnResJournalLineDeleted(var Rec: Record "Res. Journal Line"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() then
            ReturnToApproved(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Line No.", Rec."Document No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Job Journal Line", OnAfterDeleteEvent, '', false, false)]
    local procedure OnJobJournalLineDeleted(var Rec: Record "Job Journal Line"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() then
            ReturnToApproved(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Line No.", Rec."Document No.");
    end;

    local procedure MarkPosted(DocumentNo: Code[20]; LedgerEntryNo: Integer)
    var
        Usage: Record "TS Usage Line ori";
    begin
        Usage.SetCurrentKey("Document No.");
        Usage.SetRange("Document No.", DocumentNo);
        Usage.SetRange(Status, Usage.Status::Transferred);
        if Usage.FindFirst() then begin
            Usage.Status := Usage.Status::Posted;
            Usage."Ledger Entry No." := LedgerEntryNo;
            Usage.Modify();
        end;
    end;

    local procedure ReturnToApproved(Template: Code[10]; Batch: Code[10]; LineNo: Integer; DocumentNo: Code[20])
    var
        Usage: Record "TS Usage Line ori";
    begin
        if CopyStr(DocumentNo, 1, 3) <> 'TSU' then
            exit;
        Usage.SetRange("Document No.", DocumentNo);
        Usage.SetRange(Status, Usage.Status::Transferred);
        Usage.SetRange("Journal Template Name", Template);
        Usage.SetRange("Journal Batch Name", Batch);
        Usage.SetRange("Journal Line No.", LineNo);
        if Usage.FindFirst() then begin
            Usage.Status := Usage.Status::Approved;
            Clear(Usage."Journal Template Name");
            Clear(Usage."Journal Batch Name");
            Clear(Usage."Journal Line No.");
            Usage.Modify();
        end;
    end;
}
