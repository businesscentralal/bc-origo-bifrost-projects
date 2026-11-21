namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Closes visit status, times, hours and time sheet keys to the visit message types.</summary>
codeunit 70013442 "Proj. Visit Restrict ori"
{
    Access = Internal;

    var
        HintLbl: Label 'Projects.Visit.Start, Projects.Visit.Stop or Projects.Visit.Complete', Comment = 'is-IS=Projects.Visit.Start, Projects.Visit.Stop eða Projects.Visit.Complete';

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
            Hint := HintLbl;
    end;

    local procedure IsManagedField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        Visit: Record "Proj. Field Visit ori";
    begin
        if TableNo <> Database::"Proj. Field Visit ori" then
            exit(false);
        exit(FieldNo in [
            Visit.FieldNo(Status),
            Visit.FieldNo("Started At"),
            Visit.FieldNo("Stopped At"),
            Visit.FieldNo("Hours Written"),
            Visit.FieldNo("Time Sheet No."),
            Visit.FieldNo("Time Sheet Line No.")]);
    end;
}
