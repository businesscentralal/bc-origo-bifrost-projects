namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Closes the generic write of usage business, link and state fields; the Projects.Usage.* messages own them.</summary>
codeunit 70013405 "TS Usage Restrict ori"
{
    Access = Internal;

    var
        HintTxt: Label 'Projects.Usage.Register, Projects.Usage.Submit, Projects.Usage.Approve, Projects.Usage.Reject, Projects.Usage.Transfer or Projects.Usage.Reverse', Comment = 'is-IS=Projects.Usage.Register, Projects.Usage.Submit, Projects.Usage.Approve, Projects.Usage.Reject, Projects.Usage.Transfer eða Projects.Usage.Reverse';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure OnAfterIsFieldWriteRestricted(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if IsManagedField(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure OnGetDedicatedMessageTypeHintForField(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if IsManagedField(TableNo, FieldNo) then
            Hint := HintTxt;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableInsertRestrictedForDataRecords, '', false, false)]
    local procedure RestrictInsert(TableNo: Integer; RecRef: RecordRef; Force: Boolean; IdentityInsert: Boolean; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"TS Usage Line ori" then
            IsRestricted := true;
    end;

    local procedure IsManagedField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        Usage: Record "TS Usage Line ori";
    begin
        if TableNo <> Database::"TS Usage Line ori" then
            exit(false);
        exit(FieldNo in [Usage.FieldNo("Time Sheet No."), Usage.FieldNo("Time Sheet Line No."),
                         Usage.FieldNo("Resource No."), Usage.FieldNo(Type), Usage.FieldNo("No."), Usage.FieldNo(Date),
                         Usage.FieldNo(Quantity), Usage.FieldNo("Unit of Measure Code"), Usage.FieldNo(Status), Usage.FieldNo(Reversed), Usage.FieldNo("Approved By"), Usage.FieldNo("Approved At"),
                         Usage.FieldNo("Journal Template Name"), Usage.FieldNo("Journal Batch Name"), Usage.FieldNo("Journal Line No."),
                         Usage.FieldNo("Ledger Entry No."), Usage.FieldNo("Document No."), Usage.FieldNo("Reject Comment"),
                         Usage.FieldNo("Location Code"), Usage.FieldNo("Bin Code"), Usage.FieldNo("Lot No."), Usage.FieldNo("Serial No."), Usage.FieldNo("Client Request Id")]);
    end;
}
