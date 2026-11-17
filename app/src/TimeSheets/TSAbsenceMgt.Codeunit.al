namespace Origo.Bifrost.Projects;

using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>
/// Request checks and dispatch for the native Timesheets message types.
/// Each Execute procedure reads only that type's keys. Writes run in
/// "TS Absence Runner ori" so a failure rolls back.
/// </summary>
codeunit 70013553 "TS Absence Mgt ori"
{
    Access = Internal;

    var
        MissingKeyNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownKeyNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        IdentifierNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        OneIdentifierNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        FixLineNextTxt: Label 'Fix the line and submit again.', Comment = 'is-IS=Lagfærðu línuna og sendu aftur inn.';
        InvalidHoursNextTxt: Label 'Send each date once and keep every date inside the time sheet period.', Comment = 'is-IS=Sendu hverja dagsetningu einu sinni og haltu öllum dagsetningum innan tímabils tímaskýrslunnar.';
        LinkEmployeeNextTxt: Label 'Link the resource to an employee in BC.', Comment = 'is-IS=Tengdu auðlindina við starfsmann í BC.';
        CauseNextTxt: Label 'Use a code from Causes of Absence.', Comment = 'is-IS=Notaðu kóða úr fjarvistarástæðum.';
        AssignSetNextTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        RetryNextTxt: Label 'Retry the call.', Comment = 'is-IS=Reyndu kallið aftur.';
        MissingKeyMsg: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        TypeMsg: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        UnknownKeyMsg: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        IdentifierMsg: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        OneIdentifierMsg: Label 'The request names the time sheet in more than one way.', Comment = 'is-IS=Beiðnin nefnir tímaskýrsluna á fleiri en einn hátt.';
        FixLineMsg: Label 'Business Central rejected the line.', Comment = 'is-IS=Business Central hafnaði línunni.';
        InvalidHoursMsg: Label 'Hours dates must be unique and inside the time sheet period.', Comment = 'is-IS=Dagsetningar klukkustunda verða að vera einstakar og innan tímabils tímaskýrslunnar.';
        LinkEmployeeMsg: Label 'The resource is not linked to an employee.', Comment = 'is-IS=Auðlindin er ekki tengd við starfsmann.';
        CauseMsg: Label 'The cause of absence was not found.', Comment = 'is-IS=Fjarvistarástæðan fannst ekki.';
        AssignSetMsg: Label 'The caller cannot write time sheets.', Comment = 'is-IS=Kallandinn getur ekki skrifað tímaskýrslur.';

    /// <summary>True when the caller can read a header and write its lines and details.</summary>
    procedure CanMaintainSheets(): Boolean
    var
        Cause: Record "Cause of Absence";
        Employee: Record Employee;
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Line.WritePermission() and
            Detail.ReadPermission() and Detail.WritePermission() and Cause.ReadPermission() and Employee.ReadPermission() and
            Resource.ReadPermission() and ResourcesSetup.ReadPermission());
    end;

    /// <summary>Registers an absence line and its daily hours.</summary>
    procedure ExecuteAbsence(var Argument: Record "Message Argument ori")
    var
        Cause: Record "Cause of Absence";
        Employee: Record Employee;
        Header: Record "Time Sheet Header";
        Context: Codeunit "TS Absence Context ori";
        Allowed: List of [Text];
        CauseCode: Code[10];
        CauseToken: JsonToken;
        DateToken: JsonToken;
        HoursText: Text;
        HoursToken: JsonToken;
        NonWorking: Boolean;
        QtyToken: JsonToken;
        RequestJson: JsonObject;
        ResourceToken: JsonToken;
        SheetToken: JsonToken;
    begin
        if Deny(Argument) then
            exit;
        RequestJson := Argument.GetRequestJson();
        Allowed.Add('timeSheetNo');
        Allowed.Add('resourceNo');
        Allowed.Add('date');
        Allowed.Add('causeOfAbsenceCode');
        Allowed.Add('hours');
        Allowed.Add('quantity');
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        if not ResolveSheet(Argument, RequestJson, SheetToken, ResourceToken, DateToken, Header) then
            exit;
        if not RequestJson.Get('causeOfAbsenceCode', CauseToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'causeOfAbsenceCode', MissingKeyNextTxt);
            exit;
        end;
        if not IsJsonString(CauseToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'causeOfAbsenceCode', TypeNextTxt);
            exit;
        end;
        CauseCode := CopyStr(CauseToken.AsValue().AsText(), 1, MaxStrLen(CauseCode));
        if not Cause.Get(CauseCode) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, CauseMsg, 'causeOfAbsenceCode', CauseNextTxt);
            exit;
        end;
        if not ReadHours(Argument, RequestJson, Header, HoursToken, QtyToken, DateToken, HoursText, NonWorking) then
            exit;
        if not Employee.ReadPermission() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
            exit;
        end;
        Employee.ReadIsolation := IsolationLevel::ReadCommitted;
        Employee.SetLoadFields("Resource No.");
        Employee.SetRange("Resource No.", Header."Resource No.");
        if Employee.IsEmpty() then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, LinkEmployeeMsg, 'resourceNo', LinkEmployeeNextTxt);
            exit;
        end;
        // Resource has no Base Calendar Code in the BC 28 symbol set this app compiles against.
        // Non-working days are Saturday and Sunday (Date2DWY >= 6) only.
        Context.SetAbsence(Header."No.", CauseCode, HoursText, NonWorking);
        RunAndRespond(Argument);
    end;

    local procedure ResolveSheet(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SheetToken: JsonToken; var ResourceToken: JsonToken; var DateToken: JsonToken; var Header: Record "Time Sheet Header"): Boolean
    var
        HasDate: Boolean;
        HasResource: Boolean;
        HasSheet: Boolean;
        ResourceNo: Code[20];
        SheetDate: Date;
    begin
        HasSheet := RequestJson.Get('timeSheetNo', SheetToken);
        HasResource := RequestJson.Get('resourceNo', ResourceToken);
        HasDate := RequestJson.Get('date', DateToken);
        if HasSheet and HasResource then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'timeSheetNo', OneIdentifierNextTxt);
            exit(false);
        end;
        if HasSheet and HasDate and not RequestJson.Contains('quantity') then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'date', OneIdentifierNextTxt);
            exit(false);
        end;
        if not HasSheet and not HasResource then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'timeSheetNo', MissingKeyNextTxt);
            exit(false);
        end;
        if HasSheet then
            exit(LoadSheetToken(Argument, SheetToken, Header));
        if not HasDate then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'date', MissingKeyNextTxt);
            exit(false);
        end;
        if not IsJsonString(ResourceToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'resourceNo', TypeNextTxt);
            exit(false);
        end;
        if not ReadJsonDate(DateToken, SheetDate) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'date', TypeNextTxt);
            exit(false);
        end;
        ResourceNo := CopyStr(ResourceToken.AsValue().AsText(), 1, MaxStrLen(ResourceNo));
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetFilter("Starting Date", '<=%1', SheetDate);
        Header.SetFilter("Ending Date", '>=%1', SheetDate);
        if Header.Count() > 1 then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'date', OneIdentifierNextTxt);
            exit(false);
        end;
        if not Header.FindFirst() then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, 'resourceNo', IdentifierNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure LoadSheetToken(var Argument: Record "Message Argument ori"; SheetToken: JsonToken; var Header: Record "Time Sheet Header"): Boolean
    var
        SheetNo: Code[20];
    begin
        if not IsJsonString(SheetToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetNo', TypeNextTxt);
            exit(false);
        end;
        SheetNo := CopyStr(SheetToken.AsValue().AsText(), 1, MaxStrLen(SheetNo));
        if not Header.Get(SheetNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, 'timeSheetNo', IdentifierNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadHours(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Header: Record "Time Sheet Header"; var HoursToken: JsonToken; var QtyToken: JsonToken; DateToken: JsonToken; var HoursText: Text; var NonWorking: Boolean): Boolean
    var
        DateText: Text;
        DateValueToken: JsonToken;
        Entry: JsonToken;
        HasHours: Boolean;
        HasQty: Boolean;
        HourDates: List of [Date];
        HourDate: Date;
        Index: Integer;
        QtyValueToken: JsonToken;
        Quantity: Decimal;
    begin
        HasHours := RequestJson.Get('hours', HoursToken);
        HasQty := RequestJson.Get('quantity', QtyToken);
        if HasHours and HasQty then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'hours', OneIdentifierNextTxt);
            exit(false);
        end;
        if not HasHours and not HasQty then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'hours', MissingKeyNextTxt);
            exit(false);
        end;
        if HasQty then begin
            if not RequestJson.Contains('date') then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'date', MissingKeyNextTxt);
                exit(false);
            end;
            if not ReadJsonDecimal(QtyToken, Quantity) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'quantity', TypeNextTxt);
                exit(false);
            end;
            if not ReadJsonDate(DateToken, HourDate) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'date', TypeNextTxt);
                exit(false);
            end;
            if not ValidateHourDate(Argument, Header, HourDate, HourDates) then
                exit(false);
            DateText := Format(HourDate, 0, 9);
            HoursText := DateText + '|' + Format(Quantity, 0, 9);
            NonWorking := Date2DWY(HourDate, 1) >= 6;
            exit(true);
        end;
        if not HoursToken.IsArray() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'hours', TypeNextTxt);
            exit(false);
        end;
        if HoursToken.AsArray().Count() = 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'hours', MissingKeyNextTxt);
            exit(false);
        end;
        for Index := 0 to HoursToken.AsArray().Count() - 1 do begin
            HoursToken.AsArray().Get(Index, Entry);
            if not Entry.IsObject() then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'hours', TypeNextTxt);
                exit(false);
            end;
            if not Entry.AsObject().Get('date', DateValueToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'hours', MissingKeyNextTxt);
                exit(false);
            end;
            if not Entry.AsObject().Get('quantity', QtyValueToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'hours', MissingKeyNextTxt);
                exit(false);
            end;
            if not ReadJsonDate(DateValueToken, HourDate) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'hours', TypeNextTxt);
                exit(false);
            end;
            if not ValidateHourDate(Argument, Header, HourDate, HourDates) then
                exit(false);
            if not ReadJsonDecimal(QtyValueToken, Quantity) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'hours', TypeNextTxt);
                exit(false);
            end;
            if HoursText <> '' then
                HoursText += ';';
            HoursText += Format(HourDate, 0, 9) + '|' + Format(Quantity, 0, 9);
            if Date2DWY(HourDate, 1) >= 6 then
                NonWorking := true;
        end;
        exit(true);
    end;

    local procedure ValidateHourDate(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; HourDate: Date; var HourDates: List of [Date]): Boolean
    begin
        if (HourDate < Header."Starting Date") or (HourDate > Header."Ending Date") or HourDates.Contains(HourDate) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidLine, InvalidHoursMsg, 'hours', InvalidHoursNextTxt);
            exit(false);
        end;
        HourDates.Add(HourDate);
        exit(true);
    end;

    local procedure RunAndRespond(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Absence Context ori";
        Err: Text;
        Response: JsonObject;
    begin
        // Omit Commit stays inside the caller's write transaction. Capturing the return
        // value of Codeunit.Run is illegal there, so a platform error propagates.
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"TS Absence Runner ori");
            Response.ReadFrom(Context.GetResult());
            Context.Clear();
            Argument.SetResponseJson(Response);
            exit;
        end;

        // A captured Codeunit.Run cannot roll a failure back while a write transaction is
        // already open: the platform stops that transaction and hides the cause. Commit
        // first. The runner then has its own transaction, which commits or rolls back.
        if Database.IsInWriteTransaction() then
            Commit();

        if not Codeunit.Run(Codeunit::"TS Absence Runner ori") then begin
            Err := GetLastErrorText();
            Context.Clear();
            if StrPos(Err, 'InvalidLine') > 0 then
                Fail(Argument, "Bifrost Error Code ori"::InvalidLine, FixLineMsg, 'lineNos', FixLineNextTxt)
            else
                Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(Err, 1, 250), '', RetryNextTxt);
            exit;
        end;

        Response.ReadFrom(Context.GetResult());
        Context.Clear();
        Argument.SetResponseJson(Response);
    end;

    local procedure Deny(var Argument: Record "Message Argument ori"): Boolean
    begin
        if CanMaintainSheets() then
            exit(false);
        Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
        exit(true);
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, Parameter, '', '', NextStep);
    end;

    local procedure AllowOnly(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Allowed: List of [Text]): Boolean
    var
        KeyName: Text;
        Keys: List of [Text];
    begin
        Keys := RequestJson.Keys();
        foreach KeyName in Keys do
            if not Allowed.Contains(KeyName) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownKeyMsg, KeyName, UnknownKeyNextTxt);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadJsonDate(Token: JsonToken; var DateValue: Date): Boolean
    begin
        if not IsJsonString(Token) then
            exit(false);
        exit(Evaluate(DateValue, Token.AsValue().AsText(), 9));
    end;

    local procedure ReadJsonDecimal(Token: JsonToken; var DecimalValue: Decimal): Boolean
    begin
        if not IsJsonNumber(Token) then
            exit(false);
        exit(Evaluate(DecimalValue, Token.AsValue().AsText(), 9));
    end;

    local procedure IsJsonString(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        exit(CopyStr(DelChr(Raw, '<>', ' '), 1, 1) = '"');
    end;

    local procedure IsJsonNumber(Token: JsonToken): Boolean
    var
        First: Text[1];
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        First := CopyStr(Raw, 1, 1);
        exit(First in ['-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    end;

}
