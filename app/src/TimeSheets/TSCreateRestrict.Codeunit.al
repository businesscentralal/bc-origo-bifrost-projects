namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Routes generic time sheet header writes to the dedicated creation type; reads remain available.</summary>
codeunit 70013577 "TS Create Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictHeader(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Time Sheet Header" then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HeaderHint(TableNo: Integer; var Hint: Text)
    begin
        if TableNo = Database::"Time Sheet Header" then
            Hint := 'Projects.TimeSheet.Create';
    end;
}
