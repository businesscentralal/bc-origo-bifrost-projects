namespace Origo.Bifrost.Projects;

using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>
/// Request checks for Projects.TimeSheetLine.Set. Every line of the call is checked
/// before anything is written; the writes run in "TS Line Set Runner ori" so a
/// failure on any line rolls the whole call back.
/// </summary>
codeunit 70013593 "TS Line Set Mgt ori"
{
    Access = Internal;

    var
        MissingKeyNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownKeyNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        IdentifierNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        DuplicateLineNextTxt: Label 'Send each lineNo once.', Comment = 'is-IS=Sendu hvert lineNo einu sinni.';
        LineTypeNextTxt: Label 'Use project, resource, absence or service.', Comment = 'is-IS=Notaðu project, resource, absence eða service.';
        KeyForTypeNextTxt: Label 'Send only the keys that belong to the line type.', Comment = 'is-IS=Sendu aðeins lyklana sem eiga við tegund línunnar.';
        DescriptionNextTxt: Label 'Send a description of at most 100 characters.', Comment = 'is-IS=Sendu lýsingu sem er í mesta lagi 100 stafir.';
        HoursNextTxt: Label 'Send each date once, keep every date inside the time sheet period and use zero or more hours.', Comment = 'is-IS=Sendu hverja dagsetningu einu sinni, haltu öllum dagsetningum innan tímabils tímaskýrslunnar og notaðu núll eða fleiri klukkustundir.';
        ReopenNextTxt: Label 'Reopen the line with Projects.TimeSheet.Reopen, then send the change again.', Comment = 'is-IS=Opnaðu línuna aftur með Projects.TimeSheet.Reopen og sendu svo breytinguna aftur.';
        PostedNextTxt: Label 'Posted lines cannot change. Add a new line instead.', Comment = 'is-IS=Bókuðum línum er ekki hægt að breyta. Bættu frekar við nýrri línu.';
        TypeChangeNextTxt: Label 'Keep the line type, or add a new line with the other type.', Comment = 'is-IS=Haltu tegund línunnar eða bættu við nýrri línu með hinni tegundinni.';
        AssemblyNextTxt: Label 'Assembly lines come from assembly orders. Change their hours with lineNo.', Comment = 'is-IS=Samsetningarlínur koma úr samsetningarpöntunum. Breyttu klukkustundum þeirra með lineNo.';
        LinkEmployeeNextTxt: Label 'Link the resource to an employee in BC.', Comment = 'is-IS=Tengdu auðlindina við starfsmann í BC.';
        LimitNextTxt: Label 'Send at most 100 lines per call.', Comment = 'is-IS=Sendu að hámarki 100 línur í hverju kalli.';
        AssignSetNextTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        FixLineNextTxt: Label 'Fix the line and send the call again.', Comment = 'is-IS=Lagfærðu línuna og sendu kallið aftur.';
        MissingKeyMsg: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        TypeMsg: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        UnknownKeyMsg: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        IdentifierMsg: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        DuplicateLineMsg: Label 'The request names the same line more than once.', Comment = 'is-IS=Beiðnin nefnir sömu línu oftar en einu sinni.';
        LineTypeMsg: Label 'The line type is not supported.', Comment = 'is-IS=Tegund línunnar er ekki studd.';
        KeyForTypeMsg: Label 'The key does not belong to this line type.', Comment = 'is-IS=Lykillinn á ekki við þessa tegund línu.';
        DescriptionMsg: Label 'The description is too long.', Comment = 'is-IS=Lýsingin er of löng.';
        HoursMsg: Label 'Hours dates must be unique and inside the time sheet period, and hours cannot be negative.', Comment = 'is-IS=Dagsetningar klukkustunda verða að vera einstakar og innan tímabils tímaskýrslunnar og klukkustundir mega ekki vera neikvæðar.';
        LockedLineMsg: Label 'The line is submitted or approved and cannot change.', Comment = 'is-IS=Línan hefur verið send inn eða samþykkt og er ekki hægt að breyta.';
        PostedLineMsg: Label 'The line is posted and cannot change.', Comment = 'is-IS=Línan er bókuð og er ekki hægt að breyta.';
        TypeChangeMsg: Label 'The type of an existing line cannot change.', Comment = 'is-IS=Ekki er hægt að breyta tegund línu sem er til.';
        AssemblyMsg: Label 'Assembly lines cannot be added through this type.', Comment = 'is-IS=Ekki er hægt að bæta við samsetningarlínum með þessari tegund.';
        LinkEmployeeMsg: Label 'The resource is not linked to an employee.', Comment = 'is-IS=Auðlindin er ekki tengd við starfsmann.';
        LimitMsg: Label 'The request has too many lines.', Comment = 'is-IS=Beiðnin hefur of margar línur.';
        AssignSetMsg: Label 'The caller cannot write time sheets.', Comment = 'is-IS=Kallandinn getur ekki skrifað tímaskýrslur.';
        FixLineMsg: Label 'Business Central rejected a line: %1', Comment = 'is-IS=Business Central hafnaði línu: %1';
        LinesTok: Label 'lines', Locked = true;
        PathTok: Label 'lines[%1].%2', Locked = true;
        LineTok: Label 'lines[%1]', Locked = true;
        LinePrefixTok: Label 'lines[%1].', Locked = true;
        HourPrefixTok: Label '%1[%2].', Locked = true;

    /// <summary>True when the caller can read a header and write its lines and details.</summary>
    procedure CanMaintainSheets(): Boolean
    var
        Cause: Record "Cause of Absence";
        Job: Record Job;
        JobTask: Record "Job Task";
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Line.WritePermission() and
            Detail.ReadPermission() and Detail.WritePermission() and Cause.ReadPermission() and
            Job.ReadPermission() and JobTask.ReadPermission() and Resource.ReadPermission() and ResourcesSetup.ReadPermission());
    end;

    /// <summary>Checks the request, then inserts or updates the lines and their daily hours.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Context: Codeunit "TS Line Set Context ori";
        Allowed: List of [Text];
        SeenLineNos: List of [Integer];
        Entry: JsonToken;
        LinesToken: JsonToken;
        SheetToken: JsonToken;
        RequestJson: JsonObject;
        LinesText: Text;
        Index: Integer;
    begin
        if Deny(Argument) then
            exit;
        RequestJson := Argument.GetRequestJson();
        Allowed.Add('timeSheetNo');
        Allowed.Add(LinesTok);
        if not AllowOnly(Argument, RequestJson, Allowed, '') then
            exit;
        if not RequestJson.Get('timeSheetNo', SheetToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'timeSheetNo', MissingKeyNextTxt);
            exit;
        end;
        if not IsJsonString(SheetToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetNo', TypeNextTxt);
            exit;
        end;
        if not Header.Get(CopyStr(SheetToken.AsValue().AsText(), 1, MaxStrLen(Header."No."))) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, 'timeSheetNo', IdentifierNextTxt);
            exit;
        end;
        if not RequestJson.Get(LinesTok, LinesToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, LinesTok, MissingKeyNextTxt);
            exit;
        end;
        if not LinesToken.IsArray() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, LinesTok, TypeNextTxt);
            exit;
        end;
        if LinesToken.AsArray().Count() = 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, LinesTok, MissingKeyNextTxt);
            exit;
        end;
        if LinesToken.AsArray().Count() > 100 then begin
            Fail(Argument, "Bifrost Error Code ori"::LimitExceeded, LimitMsg, LinesTok, LimitNextTxt);
            exit;
        end;
        for Index := 0 to LinesToken.AsArray().Count() - 1 do begin
            LinesToken.AsArray().Get(Index, Entry);
            if not Entry.IsObject() then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, StrSubstNo(LineTok, Index), TypeNextTxt);
                exit;
            end;
            if not CheckLine(Argument, Header, Entry.AsObject(), Index, SeenLineNos) then
                exit;
        end;
        LinesToken.WriteTo(LinesText);
        Context.SetRequest(Header."No.", LinesText);
        RunAndRespond(Argument);
    end;

    local procedure CheckLine(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; LineJson: JsonObject; Index: Integer; var SeenLineNos: List of [Integer]): Boolean
    var
        Line: Record "Time Sheet Line";
        Allowed: List of [Text];
        LineType: Enum "Time Sheet Line Type";
        RequestedType: Enum "Time Sheet Line Type";
        Token: JsonToken;
        IsNew: Boolean;
        LineNo: Integer;
    begin
        Allowed.Add('lineNo');
        Allowed.Add('type');
        Allowed.Add('projectNo');
        Allowed.Add('projectTaskNo');
        Allowed.Add('causeOfAbsenceCode');
        Allowed.Add('serviceOrderNo');
        Allowed.Add('workTypeCode');
        Allowed.Add('description');
        Allowed.Add('chargeable');
        Allowed.Add('hours');
        if not AllowOnly(Argument, LineJson, Allowed, StrSubstNo(LinePrefixTok, Index)) then
            exit(false);
        IsNew := not LineJson.Get('lineNo', Token);
        if not IsNew then begin
            if not ReadJsonInteger(Token, LineNo) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'lineNo'), TypeNextTxt));
            if SeenLineNos.Contains(LineNo) then
                exit(Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, DuplicateLineMsg, Path(Index, 'lineNo'), DuplicateLineNextTxt));
            SeenLineNos.Add(LineNo);
            if not Line.Get(Header."No.", LineNo) then
                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, Path(Index, 'lineNo'), IdentifierNextTxt));
            if Line.Posted then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, PostedLineMsg, Path(Index, 'lineNo'), PostedNextTxt));
            if Line.Status in [Line.Status::Submitted, Line.Status::Approved] then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, LockedLineMsg, Path(Index, 'lineNo'), ReopenNextTxt));
            LineType := Line.Type;
        end;
        if LineJson.Get('type', Token) then begin
            if not IsJsonString(Token) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'type'), TypeNextTxt));
            if not TryParseLineType(Token.AsValue().AsText(), RequestedType) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, LineTypeMsg, Path(Index, 'type'), LineTypeNextTxt));
            if not IsNew and (RequestedType <> LineType) then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, TypeChangeMsg, Path(Index, 'type'), TypeChangeNextTxt));
            if IsNew and (RequestedType = RequestedType::"Assembly Order") then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, AssemblyMsg, Path(Index, 'type'), AssemblyNextTxt));
            LineType := RequestedType;
        end else
            if IsNew then
                exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'type'), MissingKeyNextTxt));

        if not CheckTypeKeys(Argument, Header, LineJson, Index, LineType, IsNew) then
            exit(false);
        if not CheckCommonKeys(Argument, LineJson, Index) then
            exit(false);
        exit(CheckHours(Argument, Header, LineJson, Index));
    end;

    local procedure CheckTypeKeys(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; LineJson: JsonObject; Index: Integer; LineType: Enum "Time Sheet Line Type"; IsNew: Boolean): Boolean
    var
        Cause: Record "Cause of Absence";
        Employee: Record Employee;
        Job: Record Job;
        JobTask: Record "Job Task";
        ServiceHeader: Record "Service Header";
        ProjectToken: JsonToken;
        TaskToken: JsonToken;
        Token: JsonToken;
        HasProject: Boolean;
        HasTask: Boolean;
    begin
        HasProject := LineJson.Get('projectNo', ProjectToken);
        HasTask := LineJson.Get('projectTaskNo', TaskToken);
        if (HasProject or HasTask) and (LineType <> LineType::Job) then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, KeyForTypeMsg, Path(Index, KeyOf(HasProject, 'projectNo', 'projectTaskNo')), KeyForTypeNextTxt));
        if LineJson.Contains('causeOfAbsenceCode') and (LineType <> LineType::Absence) then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, KeyForTypeMsg, Path(Index, 'causeOfAbsenceCode'), KeyForTypeNextTxt));
        if LineJson.Contains('serviceOrderNo') and (LineType <> LineType::Service) then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, KeyForTypeMsg, Path(Index, 'serviceOrderNo'), KeyForTypeNextTxt));
        if LineJson.Contains('workTypeCode') and not (LineType in [LineType::Job, LineType::Resource]) then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, KeyForTypeMsg, Path(Index, 'workTypeCode'), KeyForTypeNextTxt));

        case LineType of
            LineType::Job:
                begin
                    // A changed project clears the task in Business Central, so both travel together.
                    if IsNew and not HasProject then
                        exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'projectNo'), MissingKeyNextTxt));
                    if (IsNew or HasProject) and not HasTask then
                        exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'projectTaskNo'), MissingKeyNextTxt));
                    if HasTask and not HasProject then
                        exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'projectNo'), MissingKeyNextTxt));
                    if HasProject then begin
                        if not IsJsonString(ProjectToken) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'projectNo'), TypeNextTxt));
                        if not IsJsonString(TaskToken) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'projectTaskNo'), TypeNextTxt));
                        if not Job.Get(CopyStr(ProjectToken.AsValue().AsText(), 1, MaxStrLen(Job."No."))) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, Path(Index, 'projectNo'), IdentifierNextTxt));
                        if not JobTask.Get(Job."No.", CopyStr(TaskToken.AsValue().AsText(), 1, MaxStrLen(JobTask."Job Task No."))) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, Path(Index, 'projectTaskNo'), IdentifierNextTxt));
                    end;
                end;
            LineType::Absence:
                begin
                    if LineJson.Get('causeOfAbsenceCode', Token) then begin
                        if not IsJsonString(Token) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'causeOfAbsenceCode'), TypeNextTxt));
                        if not Cause.Get(CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Cause.Code))) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, Path(Index, 'causeOfAbsenceCode'), IdentifierNextTxt));
                    end else
                        if IsNew then
                            exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'causeOfAbsenceCode'), MissingKeyNextTxt));
                    if IsNew then begin
                        Employee.ReadIsolation := IsolationLevel::ReadCommitted;
                        Employee.SetRange("Resource No.", Header."Resource No.");
                        if Employee.IsEmpty() then
                            exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, LinkEmployeeMsg, Path(Index, 'type'), LinkEmployeeNextTxt));
                    end;
                end;
            LineType::Service:
                if LineJson.Get('serviceOrderNo', Token) then begin
                    if not IsJsonString(Token) then
                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'serviceOrderNo'), TypeNextTxt));
                    if not ServiceHeader.Get(ServiceHeader."Document Type"::Order, CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ServiceHeader."No."))) then
                        exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, IdentifierMsg, Path(Index, 'serviceOrderNo'), IdentifierNextTxt));
                end else
                    if IsNew then
                        exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, Path(Index, 'serviceOrderNo'), MissingKeyNextTxt));
        end;
        exit(true);
    end;

    local procedure CheckCommonKeys(var Argument: Record "Message Argument ori"; LineJson: JsonObject; Index: Integer): Boolean
    var
        Line: Record "Time Sheet Line";
        Token: JsonToken;
    begin
        if LineJson.Get('workTypeCode', Token) then
            if not IsJsonString(Token) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'workTypeCode'), TypeNextTxt));
        if LineJson.Get('description', Token) then begin
            if not IsJsonString(Token) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'description'), TypeNextTxt));
            if StrLen(Token.AsValue().AsText()) > MaxStrLen(Line.Description) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameter, DescriptionMsg, Path(Index, 'description'), DescriptionNextTxt));
        end;
        if LineJson.Get('chargeable', Token) then
            if not IsJsonBoolean(Token) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, Path(Index, 'chargeable'), TypeNextTxt));
        exit(true);
    end;

    local procedure CheckHours(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; LineJson: JsonObject; Index: Integer): Boolean
    var
        Allowed: List of [Text];
        HourDates: List of [Date];
        DateToken: JsonToken;
        Entry: JsonToken;
        HoursToken: JsonToken;
        QtyToken: JsonToken;
        HourDate: Date;
        Quantity: Decimal;
        HourIndex: Integer;
        HoursPath: Text;
    begin
        if not LineJson.Get('hours', HoursToken) then
            exit(true);
        HoursPath := Path(Index, 'hours');
        if not HoursToken.IsArray() then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, HoursPath, TypeNextTxt));
        Allowed.Add('date');
        Allowed.Add('quantity');
        for HourIndex := 0 to HoursToken.AsArray().Count() - 1 do begin
            HoursToken.AsArray().Get(HourIndex, Entry);
            if not Entry.IsObject() then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, HoursPath, TypeNextTxt));
            if not AllowOnly(Argument, Entry.AsObject(), Allowed, StrSubstNo(HourPrefixTok, HoursPath, HourIndex)) then
                exit(false);
            if not Entry.AsObject().Get('date', DateToken) then
                exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, HoursPath, MissingKeyNextTxt));
            if not Entry.AsObject().Get('quantity', QtyToken) then
                exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, HoursPath, MissingKeyNextTxt));
            if not ReadJsonDate(DateToken, HourDate) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, HoursPath, TypeNextTxt));
            if not ReadJsonDecimal(QtyToken, Quantity) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, HoursPath, TypeNextTxt));
            if (HourDate < Header."Starting Date") or (HourDate > Header."Ending Date") or HourDates.Contains(HourDate) or (Quantity < 0) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidLine, HoursMsg, HoursPath, HoursNextTxt));
            HourDates.Add(HourDate);
        end;
        exit(true);
    end;

    /// <summary>Maps the request token to the Business Central line type.</summary>
    procedure TryParseLineType(TypeText: Text; var LineType: Enum "Time Sheet Line Type"): Boolean
    begin
        case LowerCase(TypeText) of
            'project':
                LineType := LineType::Job;
            'resource':
                LineType := LineType::Resource;
            'absence':
                LineType := LineType::Absence;
            'service':
                LineType := LineType::Service;
            'assembly':
                LineType := LineType::"Assembly Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>Maps a Business Central line type to the token used in requests and responses.</summary>
    procedure LineTypeToken(LineType: Enum "Time Sheet Line Type"): Text
    begin
        case LineType of
            LineType::Job:
                exit('project');
            LineType::Resource:
                exit('resource');
            LineType::Absence:
                exit('absence');
            LineType::Service:
                exit('service');
            LineType::"Assembly Order":
                exit('assembly');
        end;
        exit('');
    end;

    local procedure RunAndRespond(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Line Set Context ori";
        Err: Text;
        Response: JsonObject;
    begin
        // Omit Commit stays inside the caller's write transaction. Capturing the return
        // value of Codeunit.Run is illegal there, so a platform error propagates.
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"TS Line Set Runner ori");
            Response.ReadFrom(Context.GetResult());
            Context.Clear();
            Argument.SetResponseJson(Response);
            exit;
        end;

        // A captured Codeunit.Run cannot roll back while a write transaction is open. Commit
        // first, so the runner has its own transaction that commits or rolls back as a whole.
        if Database.IsInWriteTransaction() then
            Commit();

        if not Codeunit.Run(Codeunit::"TS Line Set Runner ori") then begin
            Err := GetLastErrorText();
            Context.Clear();
            Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(StrSubstNo(FixLineMsg, Err), 1, 250), LinesTok, FixLineNextTxt);
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

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, Message, Parameter, '', '', NextStep);
        exit(false);
    end;

    local procedure AllowOnly(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Allowed: List of [Text]; Prefix: Text): Boolean
    var
        KeyName: Text;
    begin
        foreach KeyName in RequestJson.Keys() do
            if not Allowed.Contains(KeyName) then
                exit(Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownKeyMsg, Prefix + KeyName, UnknownKeyNextTxt));
        exit(true);
    end;

    local procedure Path(Index: Integer; KeyName: Text): Text
    begin
        exit(StrSubstNo(PathTok, Index, KeyName));
    end;

    local procedure KeyOf(First: Boolean; FirstName: Text; SecondName: Text): Text
    begin
        if First then
            exit(FirstName);
        exit(SecondName);
    end;

    local procedure ReadJsonInteger(Token: JsonToken; var IntValue: Integer): Boolean
    var
        Raw: Text;
    begin
        if not IsJsonNumber(Token) then
            exit(false);
        Token.WriteTo(Raw);
        if StrPos(Raw, '.') > 0 then
            exit(false);
        if not Evaluate(IntValue, DelChr(Raw, '<>', ' '), 9) then
            exit(false);
        exit(IntValue > 0);
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

    local procedure IsJsonBoolean(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        exit(Raw in ['true', 'false']);
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
