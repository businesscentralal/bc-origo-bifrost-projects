namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;

/// <summary>
/// Session flag for Projects.MyTimeSheet.Create (projects#38). While it is set, report 950 Create Time Sheets
/// skips its Time Sheet Admin. check, because the manager has already limited the request to one resource whose
/// Time Sheet Owner User ID is the caller. The flag is cleared right after the run, also on failure.
/// </summary>
codeunit 70013592 "TS My Create Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        OwnResourceNo: Code[20];

    /// <summary>Allows the native report to create a sheet for this own resource only.</summary>
    procedure SetOwnResource(ResourceNo: Code[20])
    begin
        OwnResourceNo := ResourceNo;
    end;

    /// <summary>Ends the self-service create.</summary>
    procedure Clear()
    begin
        OwnResourceNo := '';
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Time Sheets", OnBeforeCheckUserSetup, '', false, false)]
    local procedure SkipAdminCheckForOwnSheet(var IsHandled: Boolean)
    begin
        if OwnResourceNo <> '' then
            IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Create Time Sheets", OnResourceOnAfterGerRecordOnBeforeTimeSheetHeaderInsert, '', false, false)]
    local procedure OnlyOwnResource(var TimeSheetHeader: Record "Time Sheet Header"; Resource: Record Resource)
    var
        OtherResourceErr: Label 'A self-service create can only create a time sheet for the caller''s own resource.', Comment = 'is-IS=Sjálfsafgreiðsla getur aðeins stofnað tímaskýrslu fyrir eigin forða kallanda.';
    begin
        if OwnResourceNo = '' then
            exit;
        if Resource."No." <> OwnResourceNo then
            Error(ErrorInfo.Create(OtherResourceErr));
    end;
}
