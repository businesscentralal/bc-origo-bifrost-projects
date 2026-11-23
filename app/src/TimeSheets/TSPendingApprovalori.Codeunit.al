namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Lists submitted lines addressed to the calling time-sheet approver without changing records.</summary>
codeunit 70013568 "TS Pending Approval ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        PermissionLbl: Label 'Assign the PROJ TS ADMIN ori permission set together with BIFROST Read ori or BIFROST Full ori.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni PROJ TS ADMIN ori ásamt BIFROST Read ori eða BIFROST Full ori.';
        DateLbl: Label 'Use from <= to.', Comment = 'is-IS=Notaðu from <= to.';
        FormatLbl: Label 'Use the parameter type, length and range listed in the help.', Comment = 'is-IS=Notaðu gagnategund, lengd og bil viðfangs sem tilgreind eru í hjálpinni.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        MissingLbl: Label 'Supply both from and to when filtering by date.', Comment = 'is-IS=Sendu bæði from og to þegar síað er eftir dagsetningu.';
        RecordLbl: Label 'Use an existing resource number or SystemId.', Comment = 'is-IS=Notaðu fyrirliggjandi forðanúmer eða SystemId.';
        ConflictLbl: Label 'Use resourceNo and resourceId belonging to the same resource.', Comment = 'is-IS=Notaðu resourceNo og resourceId sem tilheyra sama forða.';
        RefusedLbl: Label 'The pending approval request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna beiðni um línur sem bíða samþykkis.';

    /// <summary>Checks all native tables used by the query.</summary>
    procedure IsEnabled(): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Detail.ReadPermission() and Resource.ReadPermission());
    end;

    /// <summary>Uses explicit filters rather than a generic table-filter envelope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the localized purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lists submitted time sheet lines waiting for the calling manager, with daily hours and totals.', Comment = 'is-IS=Sýnir innsendar tímaskýrslulínur sem bíða samþykkis stjórnandans sem kallar, með daglegum stundum og samtölum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, pending approval, manager, submitted, hours', Comment = 'is-IS=tímaskýrsla, bíður samþykkis, stjórnandi, innsendar, stundir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes selection.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares a read-only outbound query.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Declares the optional version-one JSON request.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', false);
        exit(true);
    end;

    /// <summary>The caller identity supplies the approval target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares the exact accepted keys and stable enum names.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        ResourceLbl: Label 'Optional resource number, maximum 20 characters. May be combined with resourceId only for the same resource.', Comment = 'is-IS=Valfrjálst forðanúmer, mest 20 stafir. Má aðeins sameina resourceId fyrir sama forða.';
        ResourceIdLbl: Label 'Optional resource SystemId (GUID).', Comment = 'is-IS=Valfrjálst SystemId forða (GUID).';
        FromLbl: Label 'First included date, YYYY-MM-DD; requires to. Sheet periods must overlap the range and daily hours are limited to it.', Comment = 'is-IS=Fyrsti dagur, YYYY-MM-DD; krefst to. Tímabil skýrslu verður að skarast við bilið og daglegar stundir takmarkast við það.';
        ToLbl: Label 'Last included date, YYYY-MM-DD; requires from.', Comment = 'is-IS=Síðasti dagur, YYYY-MM-DD; krefst from.';
        TypeLbl: Label 'Optional stable line type name: Resource, Job, Service, Absence or Assembly Order.', Comment = 'is-IS=Valfrjálst fast tegundarheiti línu: Resource, Job, Service, Absence eða Assembly Order.';
        TakeLbl: Label 'Page size, integer 1..1000, default 100. Ordered by time sheet number and line number.', Comment = 'is-IS=Síðustærð, heiltala 1..1000, sjálfgefið 100. Raðað eftir tímaskýrslunúmeri og línunúmeri.';
        SkipLbl: Label 'Number of matching lines to skip, integer >= 0, default 0.', Comment = 'is-IS=Fjöldi samsvarandi lína sem sleppt er, heiltala >= 0, sjálfgefið 0.';
    begin
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, ResourceLbl));
        Parameters.Add(Contract.Parameter('resourceId', 'guid', false, ResourceIdLbl));
        Parameters.Add(Contract.Parameter('from', 'date', false, FromLbl));
        Parameters.Add(Contract.Parameter('to', 'date', false, ToLbl));
        Parameters.Add(Contract.Parameter('type', 'string', false, TypeLbl));
        Parameters.Add(Contract.Parameter('take', 'integer', false, TakeLbl));
        Parameters.Add(Contract.Parameter('skip', 'integer', false, SkipLbl));
        exit(true);
    end;

    /// <summary>Documents the line projection and paging result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LinesLbl: Label 'Submitted lines for the caller: timeSheetNo, lineNo, resourceNo, from, to, type, projectNo, taskNo, causeOfAbsenceCode, days [{date,hours}] and totalHours. Only requested dates contribute to totalHours.', Comment = 'is-IS=Innsendar línur fyrir kallanda: timeSheetNo, lineNo, resourceNo, from, to, type, projectNo, taskNo, causeOfAbsenceCode, days [{date,hours}] og totalHours. Aðeins umbeðnir dagar telja í totalHours.';
        MoreLbl: Label 'Whether more matching lines exist after this page. Continue with skip plus the number returned.', Comment = 'is-IS=Hvort fleiri samsvarandi línur eru á eftir síðunni. Haltu áfram með skip að viðbættum fjölda sem skilað var.';
    begin
        Fields.Add(Contract.ResponseField('lines', 'array', LinesLbl));
        Fields.Add(Contract.ResponseField('hasMore', 'boolean', MoreLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents every refusal with a corrective next step.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, RefusedLbl, DateLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, RecordLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictLbl));
        exit(true);
    end;

    /// <summary>Declares a repeatable read operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('idempotent', true);
        exit(true);
    end;

    /// <summary>Uses standard Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No related write operation is required.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No workflow is required.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a minimal read-only example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Request: JsonObject;
    begin
        Request.Add('take', 10);
        Example.Add('data', Request);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Describes caller isolation and an empty result.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Returns only submitted lines whose time sheet approver is the authenticated caller. No approvals or other writes occur. No pending approvals is a successful empty list. Filters are optional; when supplied, both dates are required.', Comment = 'is-IS=Skilar aðeins innsendum línum þar sem samþykkjandi tímaskýrslunnar er auðkenndur kallandi. Engar samþykktir eða aðrar breytingar fara fram. Engar línur í bið skila tómun lista með árangri. Síur eru valfrjálsar; ef dagsetning er send þarf að senda báðar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>No additional notes are needed.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;

    /// <summary>Validates all input and permissions before reading matching submitted lines.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        ResourceNo: Code[20];
        FromDate: Date;
        ToDate: Date;
        LineType: Enum "Time Sheet Line Type";
        TakeCount: Integer;
        SkipCount: Integer;
        HasMore: Boolean;
    begin
        Argument.AssertVersion1();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request) then
            exit;
        if not ResolveResource(Argument, Request, ResourceNo) then
            exit;
        if Request.Contains('from') <> Request.Contains('to') then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'from,to', MissingLbl);
            exit;
        end;
        if Request.Contains('from') then begin
            Evaluate(FromDate, Request.GetText('from'), 9);
            Evaluate(ToDate, Request.GetText('to'), 9);
            if FromDate > ToDate then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'from,to', DateLbl);
                exit;
            end;
        end;
        if Request.Contains('type') then
            LineType := Enum::"Time Sheet Line Type".FromInteger(LineType.Ordinals().Get(LineType.Names().IndexOf(Request.GetText('type'))));
        TakeCount := 100;
        if Request.Contains('take') then
            TakeCount := Request.GetInteger('take');
        if Request.Contains('skip') then
            SkipCount := Request.GetInteger('skip');
        HasMore := ReadLines(ResourceNo, FromDate, ToDate, Request.Contains('type'), LineType, TakeCount, SkipCount, Lines);
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Response.Add('hasMore', HasMore);
        Argument.SetResponseJson(Response);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
        DateValue: Date;
        GuidValue: Guid;
        NumberValue: Decimal;
        LineType: Enum "Time Sheet Line Type";
    begin
        foreach ParameterName in Request.Keys() do begin
            if not (ParameterName in ['resourceNo', 'resourceId', 'from', 'to', 'type', 'take', 'skip']) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName, UnknownLbl));
            Request.Get(ParameterName, Token);
            if not Token.IsValue() then
                exit(BadFormat(Argument, ParameterName));
            if Token.AsValue().IsNull() then
                exit(BadFormat(Argument, ParameterName));
            Token.WriteTo(Raw);
            if ParameterName in ['take', 'skip'] then begin
                if Raw.StartsWith('"') or not Evaluate(NumberValue, Raw, 9) then
                    exit(BadFormat(Argument, ParameterName));
                if (NumberValue <> Round(NumberValue, 1)) or (NumberValue < 0) or (NumberValue > 2147483647) then
                    exit(BadFormat(Argument, ParameterName));
                if (ParameterName = 'take') and ((NumberValue < 1) or (NumberValue > 1000)) then
                    exit(BadFormat(Argument, ParameterName));
            end else begin
                if not Raw.StartsWith('"') then
                    exit(BadFormat(Argument, ParameterName));
                case ParameterName of
                    'resourceNo':
                        if (StrLen(Token.AsValue().AsText()) = 0) or (StrLen(Token.AsValue().AsText()) > 20) then
                            exit(BadFormat(Argument, ParameterName));
                    'resourceId':
                        if not Evaluate(GuidValue, Token.AsValue().AsText()) or IsNullGuid(GuidValue) then
                            exit(BadFormat(Argument, ParameterName));
                    'from', 'to':
                        if (StrLen(Token.AsValue().AsText()) <> 10) or not Evaluate(DateValue, Token.AsValue().AsText(), 9) or (DateValue = 0D) then
                            exit(BadFormat(Argument, ParameterName));
                    'type':
                        if (Token.AsValue().AsText() = '') or not LineType.Names().Contains(Token.AsValue().AsText()) then
                            exit(BadFormat(Argument, ParameterName));
                end;
            end;
        end;
        exit(true);
    end;

    local procedure ResolveResource(var Argument: Record "Message Argument ori"; Request: JsonObject; var ResourceNo: Code[20]): Boolean
    var
        Resource: Record Resource;
        ResourceId: Guid;
    begin
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        if Request.Contains('resourceNo') then begin
            ResourceNo := CopyStr(Request.GetText('resourceNo'), 1, MaxStrLen(ResourceNo));
            if not Resource.Get(ResourceNo) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo', RecordLbl));
        end;
        if Request.Contains('resourceId') then begin
            Evaluate(ResourceId, Request.GetText('resourceId'));
            if not Resource.GetBySystemId(ResourceId) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceId', RecordLbl));
            if (ResourceNo <> '') and (ResourceNo <> Resource."No.") then
                exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'resourceNo,resourceId', ConflictLbl));
            ResourceNo := Resource."No.";
        end;
        exit(true);
    end;

    local procedure ReadLines(ResourceNo: Code[20]; FromDate: Date; ToDate: Date; FilterType: Boolean; LineType: Enum "Time Sheet Line Type"; TakeCount: Integer; SkipCount: Integer; var Lines: JsonArray): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Seen: Integer;
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetLoadFields("No.", "Resource No.", "Starting Date", "Ending Date", "Approver User ID");
        Header.SetRange("Approver User ID", UserId());
        if ResourceNo <> '' then
            Header.SetRange("Resource No.", ResourceNo);
        if FromDate <> 0D then begin
            Header.SetFilter("Starting Date", '<=%1', ToDate);
            Header.SetFilter("Ending Date", '>=%1', FromDate);
        end;
        if Header.FindSet() then
            repeat
                Line.ReadIsolation := IsolationLevel::ReadCommitted;
                Line.SetLoadFields("Time Sheet No.", "Line No.", Type, "Job No.", "Job Task No.", "Cause of Absence Code", Status);
                Line.SetRange("Time Sheet No.", Header."No.");
                Line.SetRange(Status, Line.Status::Submitted);
                if FilterType then
                    Line.SetRange(Type, LineType);
                if Line.FindSet() then
                    repeat
                        Seen += 1;
                        if Seen > SkipCount then begin
                            if Lines.Count() = TakeCount then
                                exit(true);
                            Lines.Add(LineJson(Header, Line, FromDate, ToDate));
                        end;
                    until Line.Next() = 0;
            until Header.Next() = 0;
        exit(false);
    end;

    local procedure LineJson(Header: Record "Time Sheet Header"; Line: Record "Time Sheet Line"; FromDate: Date; ToDate: Date) Result: JsonObject
    var
        Detail: Record "Time Sheet Detail";
        Days: JsonArray;
        Day: JsonObject;
        TotalHours: Decimal;
    begin
        Detail.ReadIsolation := IsolationLevel::ReadCommitted;
        Detail.SetLoadFields("Time Sheet No.", "Time Sheet Line No.", Date, Quantity);
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        if FromDate <> 0D then
            Detail.SetRange(Date, FromDate, ToDate);
        if Detail.FindSet() then
            repeat
                Clear(Day);
                Day.Add('date', Detail.Date);
                Day.Add('hours', Detail.Quantity);
                Days.Add(Day);
                TotalHours += Detail.Quantity;
            until Detail.Next() = 0;
        Result.Add('timeSheetNo', Header."No.");
        Result.Add('lineNo', Line."Line No.");
        Result.Add('resourceNo', Header."Resource No.");
        Result.Add('from', Header."Starting Date");
        Result.Add('to', Header."Ending Date");
        Result.Add('type', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
        Result.Add('projectNo', Line."Job No.");
        Result.Add('taskNo', Line."Job Task No.");
        Result.Add('causeOfAbsenceCode', Line."Cause of Absence Code");
        Result.Add('days', Days);
        Result.Add('totalHours', TotalHours);
    end;

    local procedure BadFormat(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    begin
        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, FormatLbl));
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, RefusedLbl, ParameterName, '', '', NextStep);
        exit(false);
    end;
}
