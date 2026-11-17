namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Restricts generic status writes to the dedicated time-sheet decision messages.</summary>
codeunit 70013578 "TS Sheet Restrict ori"
{
    Access = Internal;

    var
        PostingHintTok: Label 'Projects.TimeSheet.Post', Locked = true;
        ArchiveHintTok: Label 'Projects.TimeSheet.Archive', Locked = true;
        StatusHintTok: Label 'Projects.TimeSheet.Submit, Projects.TimeSheet.Approve, Projects.TimeSheet.Reject or Projects.TimeSheet.Reopen', Comment = 'is-IS=Projects.TimeSheet.Submit, Projects.TimeSheet.Approve, Projects.TimeSheet.Reject eða Projects.TimeSheet.Reopen';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure OnAfterIsFieldWriteRestricted(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if ManagedFieldHint(TableNo, FieldNo) <> '' then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure OnGetDedicatedMessageTypeHintForField(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        ManagedHint: Text;
    begin
        ManagedHint := ManagedFieldHint(TableNo, FieldNo);
        if ManagedHint <> '' then
            Hint := ManagedHint;
    end;

    // Keep generic writes from bypassing validated time-sheet and absence messages (moved from Clockify Field Restrict, projects#33).
    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictTimeSheetWrites(TableNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Time Sheet Header", Database::"Time Sheet Line", Database::"Time Sheet Detail"] then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure OnAfterIsTableWriteRestricted(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsArchiveTable(TableNo) or (TableNo = Database::"Time Sheet Posting Entry") then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure OnGetDedicatedMessageTypeHintForWrite(TableNo: Integer; var Hint: Text)
    begin
        if IsArchiveTable(TableNo) then
            Hint := ArchiveHintTok;
        if TableNo = Database::"Time Sheet Posting Entry" then
            Hint := PostingHintTok;
        if TableNo in [Database::"Time Sheet Line", Database::"Time Sheet Detail"] then
            Hint := NativeWriteHint();
    end;

    local procedure ManagedFieldHint(TableNo: Integer; FieldNo: Integer): Text
    var
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
    begin
        case TableNo of
            Database::"Time Sheet Line":
                begin
                    if FieldNo = Line.FieldNo(Status) then
                        exit(StatusHintTok);
                    if FieldNo = Line.FieldNo(Posted) then
                        exit(PostingHintTok);
                end;
            Database::"Time Sheet Detail":
                begin
                    if FieldNo = Detail.FieldNo(Status) then
                        exit(StatusHintTok);
                    if FieldNo in [Detail.FieldNo(Posted), Detail.FieldNo("Posted Quantity")] then
                        exit(PostingHintTok);
                end;
        end;
    end;

    local procedure IsArchiveTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Time Sheet Header Archive", Database::"Time Sheet Line Archive",
                        Database::"Time Sheet Detail Archive", Database::"Time Sheet Cmt. Line Archive"]);
    end;
    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableInsertRestrictedForDataRecords, '', false, false)]
    local procedure RestrictLineInsert(TableNo: Integer; RecRef: RecordRef; Force: Boolean; IdentityInsert: Boolean; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Time Sheet Line" then
            IsRestricted := true;
    end;

    // The table-level event has no field/operation context. Derive one shared list
    // from the native message catalogue so subsequent native writers join it too.
    local procedure NativeWriteHint(): Text
    var
        MessageType: Enum "Message Type ori";
        MessageName: Text;
        Hint: Text;
    begin
        foreach MessageName in MessageType.Names() do
            if ((MessageName.StartsWith('Projects.TimeSheet.') and (MessageName <> 'Projects.TimeSheet.Create')) or
                MessageName.StartsWith('Projects.TimeSheetLine.') or (MessageName = 'Projects.Absence.Register')) and
               not (MessageName.EndsWith('.Get') or MessageName.EndsWith('.List'))
            then begin
                if Hint <> '' then
                    Hint += ', ';
                Hint += MessageName;
            end;
        exit(Hint);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Time Sheet Management", OnBeforeTimeSheetDetailInsert, '', false, false)]
    local procedure LeaveCopiedHoursEmpty(var ToTimeSheetDetail: Record "Time Sheet Detail"; FromTimeSheetDetail: Record "Time Sheet Detail"; var IsHandled: Boolean)
    var
        Context: Codeunit "TS Fill Context ori";
    begin
        if Context.IsCopyDestination(ToTimeSheetDetail."Time Sheet No.") then
            IsHandled := true;
    end;
}
