namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Reads time sheets for their authenticated owner or approver (projects #49).</summary>
codeunit 70013596 "TS Sheet Get Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        PermissionLbl: Label 'Read only sheets you own or approve, and request native time sheet read permissions.', Comment = 'is-IS=Lestu aðeins tímaskýrslur sem þú átt eða samþykkir og óskaðu eftir lesheimildum fyrir tímaskýrslur.';
        DateLbl: Label 'Use from <= to.', Comment = 'is-IS=Notaðu from <= to.';
        FormatLbl: Label 'Use the parameter type, length and range listed in the help.', Comment = 'is-IS=Notaðu gagnategund, lengd og bil viðfangs sem tilgreind eru í hjálpinni.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        MissingLbl: Label 'Supply resourceNo with date, or both from and to for a date range.', Comment = 'is-IS=Sendu resourceNo með date eða bæði from og to fyrir dagsetningarbil.';
        RecordLbl: Label 'Use an existing time sheet number or resource and date.', Comment = 'is-IS=Notaðu fyrirliggjandi tímaskýrslunúmer eða forða og dagsetningu.';
        ConflictLbl: Label 'Use timeSheetNo alone, resourceNo with date, or list filters from, to, resourceNo, take and skip.', Comment = 'is-IS=Notaðu timeSheetNo eitt og sér, resourceNo með date eða listasíurnar from, to, resourceNo, take og skip.';
        RefusedLbl: Label 'The time sheet read request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr lesbeiðni tímaskýrslu.';

    /// <summary>Checks all native tables used by the query.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.TimeSheet.Get") then
            exit(false);
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
        DescriptionLbl: Label 'Reads time sheet headers, lines, daily hours and status for the owner or approver.', Comment = 'is-IS=Les hausa tímaskýrslna, línur, daglegar stundir og stöðu fyrir eiganda eða samþykkjanda.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, hours, owner, approver, status', Comment = 'is-IS=tímaskýrsla, stundir, eigandi, samþykkjandi, staða';
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

    /// <summary>The caller identity supplies the read scope.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares the exact accepted keys and stable enum names.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        ResourceLbl: Label 'Resource number, maximum 20 characters. With date selects a sheet; otherwise filters the list.', Comment = 'is-IS=Forðanúmer, mest 20 stafir. Með date velur það skýrslu; annars síar það listann.';
        ResourceIdLbl: Label 'Time sheet number, maximum 20 characters. Cannot be combined with other selectors or paging.', Comment = 'is-IS=Tímaskýrslunúmer, mest 20 stafir. Ekki má sameina það öðrum valviðföngum eða síðuskiptingu.';
        FromLbl: Label 'First included date, YYYY-MM-DD; requires to. Lists sheets whose periods overlap the range; returns all their hours.', Comment = 'is-IS=Fyrsti dagur, YYYY-MM-DD; krefst to. Sýnir skýrslur með tímabil sem skarast við bilið; skilar öllum stundum þeirra.';
        ToLbl: Label 'Last included date, YYYY-MM-DD; requires from.', Comment = 'is-IS=Síðasti dagur, YYYY-MM-DD; krefst from.';
        TypeLbl: Label 'Date within the requested sheet period, YYYY-MM-DD. Requires resourceNo; excludes list filters and paging.', Comment = 'is-IS=Dagsetning innan tímabils umbeðinnar skýrslu, YYYY-MM-DD. Krefst resourceNo; útilokar listasíur og síðuskiptingu.';
        TakeLbl: Label 'Page size, integer 1..100, default 20. Sheets are ordered by time sheet number.', Comment = 'is-IS=Síðustærð, heiltala 1..100, sjálfgefið 20. Skýrslum er raðað eftir tímaskýrslunúmeri.';
        SkipLbl: Label 'Number of authorized matching sheets to skip, integer >= 0, default 0.', Comment = 'is-IS=Fjöldi samsvarandi skýrslna með heimild sem sleppt er, heiltala >= 0, sjálfgefið 0.';
    begin
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, ResourceLbl));
        Parameters.Add(Contract.Parameter('timeSheetNo', 'string', false, ResourceIdLbl));
        Parameters.Add(Contract.Parameter('from', 'date', false, FromLbl));
        Parameters.Add(Contract.Parameter('to', 'date', false, ToLbl));
        Parameters.Add(Contract.Parameter('date', 'date', false, TypeLbl));
        Parameters.Add(Contract.Parameter('take', 'integer', false, TakeLbl));
        Parameters.Add(Contract.Parameter('skip', 'integer', false, SkipLbl));
        exit(true);
    end;

    /// <summary>Documents the sheet projection and paging result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LinesLbl: Label 'Authorized sheets: timeSheetNo, resourceNo, from, to, ownerUserId, approverUserId, lines [{lineNo,type,description,status,projectNo,taskNo,days [{date,hours,status}],totalHours}]. Status uses stable English enum names.', Comment = 'is-IS=Skýrslur með heimild: timeSheetNo, resourceNo, from, to, ownerUserId, approverUserId, lines [{lineNo,type,description,status,projectNo,taskNo,days [{date,hours,status}],totalHours}]. Staða notar föst ensk upptalningarheiti.';
        MoreLbl: Label 'Whether more authorized sheets exist after this page. Continue with skip plus the number returned.', Comment = 'is-IS=Hvort fleiri skýrslur með heimild eru á eftir síðunni. Haltu áfram með skip að viðbættum fjölda sem skilað var.';
    begin
        Fields.Add(Contract.ResponseField('timeSheets', 'array', LinesLbl));
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
        OverviewLbl: Label 'Reads only sheets whose nonblank owner or approver is the authenticated caller. Select by timeSheetNo or resourceNo with date; omit both selectors for a paged list. List date filters select overlapping sheet periods and never trim daily hours. No matching authorized sheets is a successful empty list; an unmapped caller is refused. No records are changed.', Comment = 'is-IS=Les aðeins skýrslur þar sem eigandi eða samþykkjandi er ekki auður og er auðkenndur kallandi. Veldu með timeSheetNo eða resourceNo með date; slepptu báðum valviðföngum fyrir síðuskiptan lista. Dagsetningarsíur lista velja tímabil sem skarast og skerða aldrei daglegar stundir. Engar samsvarandi skýrslur með heimild skila tómun lista; kallanda án tengingar er hafnað. Engum færslum er breytt.';
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

    /// <summary>Validates selectors and authorizes the caller before returning any sheet data.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Header: Record "Time Sheet Header";
        Resource: Record Resource;
        Request: JsonObject;
        Response: JsonObject;
        Sheets: JsonArray;
        ResourceNo: Code[20];
        FromDate: Date;
        ToDate: Date;
        TakeCount: Integer;
        SkipCount: Integer;
        Seen: Integer;
        HasMore: Boolean;
        SingleSheet: Boolean;
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.TimeSheet.Get") then
            exit;
        Argument.AssertVersion1();
        if not IsEnabled() or (UserId() = '') then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request) then
            exit;
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        if Request.Contains('timeSheetNo') then begin
            if not Header.Get(CopyStr(Request.GetText('timeSheetNo'), 1, 20)) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'timeSheetNo', RecordLbl);
                exit;
            end;
            SingleSheet := true;
        end else begin
            if Request.Contains('resourceNo') then begin
                ResourceNo := CopyStr(Request.GetText('resourceNo'), 1, MaxStrLen(ResourceNo));
                if not Resource.Get(ResourceNo) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo', RecordLbl);
                    exit;
                end;
            end;
            if Request.Contains('date') then begin
                Evaluate(FromDate, Request.GetText('date'), 9);
                Header.SetRange("Resource No.", ResourceNo);
                Header.SetFilter("Starting Date", '<=%1', FromDate);
                Header.SetFilter("Ending Date", '>=%1', FromDate);
                if not Header.FindFirst() then begin
                    Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo,date', RecordLbl);
                    exit;
                end;
                SingleSheet := true;
            end;
        end;
        if SingleSheet then begin
            if not CanReadHeader(Header) then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'timeSheetNo', PermissionLbl);
                exit;
            end;
            Sheets.Add(SheetJson(Header));
        end else begin
            if not CanReadScope(ResourceNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'resourceNo', PermissionLbl);
                exit;
            end;
            Header.SetCurrentKey("No.");
            Header.SetLoadFields("No.", "Resource No.", "Starting Date", "Ending Date", "Owner User ID", "Approver User ID");
            FilterCaller(Header);
            if ResourceNo <> '' then
                Header.SetRange("Resource No.", ResourceNo);
            if Request.Contains('from') then begin
                Evaluate(FromDate, Request.GetText('from'), 9);
                Evaluate(ToDate, Request.GetText('to'), 9);
                Header.SetFilter("Starting Date", '<=%1', ToDate);
                Header.SetFilter("Ending Date", '>=%1', FromDate);
            end;
            TakeCount := 20;
            if Request.Contains('take') then
                TakeCount := Request.GetInteger('take');
            if Request.Contains('skip') then
                SkipCount := Request.GetInteger('skip');
            if Header.FindSet() then
                repeat
                    // Recheck at projection time as well as applying the server-side caller filter.
                    if CanReadHeader(Header) then begin
                        Seen += 1;
                        if Seen > SkipCount then
                            if Sheets.Count() = TakeCount then
                                HasMore := true
                            else
                                Sheets.Add(SheetJson(Header));
                    end;
                until (Header.Next() = 0) or HasMore;
        end;
        Response.Add('status', 'Success');
        Response.Add('timeSheets', Sheets);
        Response.Add('hasMore', HasMore);
        Argument.SetResponseJson(Response);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
        DateValue: Date;
        FromDate: Date;
        ToDate: Date;
        NumberValue: Decimal;
    begin
        foreach ParameterName in Request.Keys() do begin
            if not (ParameterName in ['timeSheetNo', 'resourceNo', 'date', 'from', 'to', 'take', 'skip']) then
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
                if (ParameterName = 'take') and ((NumberValue < 1) or (NumberValue > 100)) then
                    exit(BadFormat(Argument, ParameterName));
            end else begin
                if not Raw.StartsWith('"') then
                    exit(BadFormat(Argument, ParameterName));
                if ParameterName in ['timeSheetNo', 'resourceNo'] then begin
                    if (Token.AsValue().AsText().Trim() = '') or (StrLen(Token.AsValue().AsText()) > 20) then
                        exit(BadFormat(Argument, ParameterName));
                end else
                    if (StrLen(Token.AsValue().AsText()) <> 10) or not Evaluate(DateValue, Token.AsValue().AsText(), 9) or (DateValue = 0D) then
                        exit(BadFormat(Argument, ParameterName));
            end;
        end;
        if Request.Contains('timeSheetNo') and (Request.Keys().Count() > 1) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'timeSheetNo', ConflictLbl));
        if Request.Contains('date') then begin
            if not Request.Contains('resourceNo') then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'resourceNo', MissingLbl));
            if Request.Keys().Count() > 2 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'date', ConflictLbl));
        end;
        if Request.Contains('from') <> Request.Contains('to') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'from,to', MissingLbl));
        if Request.Contains('from') then begin
            Evaluate(FromDate, Request.GetText('from'), 9);
            Evaluate(ToDate, Request.GetText('to'), 9);
            if FromDate > ToDate then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'from,to', DateLbl));
        end;
        exit(true);
    end;

    local procedure CanReadHeader(Header: Record "Time Sheet Header"): Boolean
    begin
        exit(SameUser(Header."Owner User ID") or SameUser(Header."Approver User ID"));
    end;

    local procedure SameUser(AssignedUser: Text): Boolean
    begin
        exit((AssignedUser <> '') and (UpperCase(AssignedUser) = UpperCase(UserId())));
    end;

    local procedure FilterCaller(var Header: Record "Time Sheet Header")
    begin
        Header.FilterGroup(-1);
        Header.SetRange("Owner User ID", UpperCase(UserId()));
        Header.SetRange("Approver User ID", UpperCase(UserId()));
        Header.FilterGroup(0);
    end;

    local procedure CanReadScope(ResourceNo: Code[20]): Boolean
    var
        Header: Record "Time Sheet Header";
        Resource: Record Resource;
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        FilterCaller(Header);
        if ResourceNo <> '' then
            Header.SetRange("Resource No.", ResourceNo);
        if not Header.IsEmpty() then
            exit(true);
        Resource.FilterGroup(-1);
        Resource.SetRange("Time Sheet Owner User ID", UpperCase(UserId()));
        Resource.SetRange("Time Sheet Approver User ID", UpperCase(UserId()));
        Resource.FilterGroup(0);
        if ResourceNo <> '' then
            Resource.SetRange("No.", ResourceNo);
        exit(not Resource.IsEmpty());
    end;

    local procedure SheetJson(Header: Record "Time Sheet Header") Result: JsonObject
    var
        Line: Record "Time Sheet Line";
        Lines: JsonArray;
    begin
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        Line.SetLoadFields("Time Sheet No.", "Line No.", Type, Description, Status, "Job No.", "Job Task No.");
        Line.SetRange("Time Sheet No.", Header."No.");
        if Line.FindSet() then
            repeat
                Lines.Add(LineJson(Line));
            until Line.Next() = 0;
        Result.Add('timeSheetNo', Header."No.");
        Result.Add('resourceNo', Header."Resource No.");
        Result.Add('from', Header."Starting Date");
        Result.Add('to', Header."Ending Date");
        Result.Add('ownerUserId', Header."Owner User ID");
        Result.Add('approverUserId', Header."Approver User ID");
        Result.Add('lines', Lines);
    end;

    local procedure LineJson(Line: Record "Time Sheet Line") Result: JsonObject
    var
        Detail: Record "Time Sheet Detail";
        Days: JsonArray;
        Day: JsonObject;
        TotalHours: Decimal;
    begin
        Detail.ReadIsolation := IsolationLevel::ReadCommitted;
        Detail.SetLoadFields("Time Sheet No.", "Time Sheet Line No.", Date, Quantity, Status);
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        if Detail.FindSet() then
            repeat
                Clear(Day);
                Day.Add('date', Detail.Date);
                Day.Add('hours', Detail.Quantity);
                Day.Add('status', Detail.Status.Names().Get(Detail.Status.Ordinals().IndexOf(Detail.Status.AsInteger())));
                Days.Add(Day);
                TotalHours += Detail.Quantity;
            until Detail.Next() = 0;
        Result.Add('lineNo', Line."Line No.");
        Result.Add('type', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
        Result.Add('description', Line.Description);
        Result.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
        Result.Add('projectNo', Line."Job No.");
        Result.Add('taskNo', Line."Job Task No.");
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
