namespace Origo.Bifrost.Projects;

using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Validates owner-only requests to fill a time sheet and isolates native writes.</summary>
codeunit 70013561 "TS Fill Mgt ori"
{
    Access = Internal;

    var
        MissingMsg: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeMsg: Label 'A key has the wrong JSON type or format.', Comment = 'is-IS=Lykill er af röngu JSON-tagi eða sniði.';
        TypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownMsg: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundMsg: Label 'The identifier does not match a time sheet.', Comment = 'is-IS=Auðkennið passar ekki við tímaskýrslu.';
        NotFoundNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictMsg: Label 'The request names the time sheet in more than one way.', Comment = 'is-IS=Beiðnin nefnir tímaskýrsluna á fleiri en einn hátt.';
        ConflictNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        OwnerMsg: Label 'The caller is not the owner of the time sheet.', Comment = 'is-IS=Kallandinn er ekki eigandi tímaskýrslunnar.';
        OwnerNextTxt: Label 'Ask the owner.', Comment = 'is-IS=Biddu eigandann.';
        PermissionMsg: Label 'The caller cannot fill time sheet lines.', Comment = 'is-IS=Kallandinn getur ekki fyllt út tímaskýrslulínur.';
        PermissionNextTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori eða BIFROST Full ori.';
        PreviousMsg: Label 'The resource has no previous time sheet.', Comment = 'is-IS=Auðlindin hefur enga fyrri tímaskýrslu.';
        PreviousNextTxt: Label 'Add lines by hand.', Comment = 'is-IS=Bættu við línum handvirkt.';
        TransactionMsg: Label 'This operation requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslumeðhöndlunar.';
        TransactionNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        NativeMsg: Label 'Business Central could not fill the time sheet. No lines were added.', Comment = 'is-IS=Business Central gat ekki fyllt út tímaskýrsluna. Engum línum var bætt við.';
        NativeNextTxt: Label 'Check the time sheet and source lines in Business Central, then retry.', Comment = 'is-IS=Athugaðu tímaskýrsluna og upprunalínurnar í Business Central og reyndu aftur.';

    /// <summary>Checks every native read and the line/detail write permissions without reading business data.</summary>
    procedure CanFillLines(FromPlanning: Boolean): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        Cause: Record "Cause of Absence";
        Employee: Record Employee;
    begin
        if not (Header.ReadPermission() and Line.ReadPermission() and Line.WritePermission() and
                Detail.ReadPermission() and Detail.WritePermission() and Resource.ReadPermission() and
                ResourcesSetup.ReadPermission() and Job.ReadPermission() and JobTask.ReadPermission())
        then
            exit(false);
        if FromPlanning then
            exit(Planning.ReadPermission());
        exit(Cause.ReadPermission() and Employee.ReadPermission());
    end;

    /// <summary>Copies only line definitions from the immediately preceding resource time sheet.</summary>
    procedure ExecuteCopy(var Argument: Record "Message Argument ori")
    begin
        ExecuteFill(Argument, false);
    end;

    /// <summary>Creates native project lines for this resource and period, without daily hours.</summary>
    procedure ExecutePlanning(var Argument: Record "Message Argument ori")
    begin
        ExecuteFill(Argument, true);
    end;

    local procedure ExecuteFill(var Argument: Record "Message Argument ori"; FromPlanning: Boolean)
    var
        Header: Record "Time Sheet Header";
        Previous: Record "Time Sheet Header";
        Context: Codeunit "TS Fill Context ori";
        Response: JsonObject;
    begin
        Context.Clear();
        if not CanFillLines(FromPlanning) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        if not ResolveSheet(Argument, Header) then
            exit;
        if (Header."Owner User ID" = '') or (Header."Owner User ID" <> UserId()) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, OwnerMsg, 'timeSheetNo', OwnerNextTxt);
            exit;
        end;
        if not FromPlanning then begin
            Previous.ReadIsolation := IsolationLevel::ReadCommitted;
            Previous.SetCurrentKey("Resource No.", "Starting Date");
            Previous.SetRange("Resource No.", Header."Resource No.");
            Previous.SetFilter("Starting Date", '<%1', Header."Starting Date");
            if Previous.IsEmpty() then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, PreviousMsg, 'timeSheetNo', PreviousNextTxt);
                exit;
            end;
        end;
        // An omitCommit caller must retain its transaction; this type cannot isolate writes there.
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, TransactionMsg, 'omitCommit', TransactionNextTxt);
            exit;
        end;
        if Database.IsInWriteTransaction() then
            Commit();
        Context.SetFill(Header."No.", FromPlanning);
        if not Codeunit.Run(Codeunit::"TS Fill Runner ori") then begin
            Context.Clear();
            ClearLastError();
            Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, NativeMsg, '', NativeNextTxt);
            exit;
        end;
        Response.ReadFrom(Context.GetResult());
        Context.Clear();
        Argument.SetResponseJson(Response);
    end;

    local procedure ResolveSheet(var Argument: Record "Message Argument ori"; var Header: Record "Time Sheet Header"): Boolean
    var
        Request: JsonObject;
        SheetToken: JsonToken;
        IdToken: JsonToken;
        KeyName: Text;
        SheetNo: Text;
        SheetId: Guid;
        HasNumber: Boolean;
        HasId: Boolean;
    begin
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not (KeyName in ['timeSheetNo', 'timeSheetId']) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownMsg, KeyName, UnknownNextTxt);
                exit(false);
            end;
        HasNumber := Request.Get('timeSheetNo', SheetToken);
        HasId := Request.Get('timeSheetId', IdToken);
        if HasNumber and HasId then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictMsg, 'timeSheetNo', ConflictNextTxt);
            exit(false);
        end;
        if not HasNumber and not HasId then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingMsg, 'timeSheetNo', MissingNextTxt);
            exit(false);
        end;
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if HasNumber then begin
            if not IsString(SheetToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetNo', TypeNextTxt);
                exit(false);
            end;
            SheetNo := SheetToken.AsValue().AsText();
            if (SheetNo = '') or (StrLen(SheetNo) > MaxStrLen(Header."No.")) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetNo', TypeNextTxt);
                exit(false);
            end;
            if Header.Get(SheetNo) then
                exit(true);
            KeyName := 'timeSheetNo';
        end else begin
            if not IsString(IdToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetId', TypeNextTxt);
                exit(false);
            end;
            if not Evaluate(SheetId, IdToken.AsValue().AsText()) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetId', TypeNextTxt);
                exit(false);
            end;
            if Header.GetBySystemId(SheetId) then
                exit(true);
            KeyName := 'timeSheetId';
        end;
        Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundMsg, KeyName, NotFoundNextTxt);
        exit(false);
    end;

    local procedure IsString(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Raw);
        exit(CopyStr(Raw, 1, 1) = '"');
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, MessageText, Parameter, '', '', NextStep);
    end;
}
