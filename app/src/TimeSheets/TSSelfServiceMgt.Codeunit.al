namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>
/// Own-only and approver-only checks for the self-service time-sheet message types (projects#38).
/// The caller is always UserId() of the approved session; no identity is read from the payload.
/// Every call that names a sheet re-checks owner or approver here; the shared native writer
/// re-checks again before it writes.
/// </summary>
codeunit 70013583 "TS Self Service Mgt ori"
{
    Access = Internal;

    var
        RefusedMsg: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        NotOwnerMsg: Label 'The time sheet does not belong to the caller.', Comment = 'is-IS=Tímaskýrslan tilheyrir ekki kallanda.';
        NotApproverMsg: Label 'The caller is not the approver of this time sheet.', Comment = 'is-IS=Kallandi er ekki samþykkjandi þessarar tímaskýrslu.';
        SelfApproveMsg: Label 'The caller cannot approve or reject their own time sheet.', Comment = 'is-IS=Kallandi getur ekki samþykkt eða hafnað eigin tímaskýrslu.';
        UnmappedOwnerMsg: Label 'The caller is not the time sheet owner of any resource.', Comment = 'is-IS=Kallandi er ekki eigandi tímaskýrslu neins forða.';
        UnmappedApproverMsg: Label 'The caller is not a time sheet approver.', Comment = 'is-IS=Kallandi er ekki samþykkjandi tímaskýrslna.';
        PermissionMsg: Label 'The caller lacks access to the time sheet tables.', Comment = 'is-IS=Kallandi hefur ekki aðgang að tímaskýrslutöflunum.';
        NotOwnerNextTxt: Label 'Use one of your own time sheets; read them with Projects.MyTimeSheet.Get.', Comment = 'is-IS=Notaðu eigin tímaskýrslu; lestu þær með Projects.MyTimeSheet.Get.';
        NotApproverNextTxt: Label 'Use a time sheet from your queue; read it with Projects.TimeSheetApproval.Get.', Comment = 'is-IS=Notaðu tímaskýrslu úr þinni biðröð; lestu hana með Projects.TimeSheetApproval.Get.';
        SelfApproveNextTxt: Label 'Ask another approver to decide on your own time sheet.', Comment = 'is-IS=Biddu annan samþykkjanda að taka ákvörðun um eigin tímaskýrslu.';
        UnmappedOwnerNextTxt: Label 'Ask an administrator to set your user as Time Sheet Owner User ID on your resource.', Comment = 'is-IS=Biddu stjórnanda að skrá notandann þinn sem Time Sheet Owner User ID á forðann þinn.';
        UnmappedApproverNextTxt: Label 'Ask an administrator to set your user as Time Sheet Approver User ID on the resources you approve.', Comment = 'is-IS=Biddu stjórnanda að skrá notandann þinn sem Time Sheet Approver User ID á forðana sem þú samþykkir.';
        PermissionNextTxt: Label 'Ask for the time sheet permission set for your role.', Comment = 'is-IS=Biddu um heimildasafn tímaskýrslna fyrir þitt hlutverk.';
        FormatNextTxt: Label 'Use the parameter type, length and range listed in the help.', Comment = 'is-IS=Notaðu gagnategund, lengd og bil viðfangs sem tilgreind eru í hjálpinni.';
        UnknownNextTxt: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        DatesNextTxt: Label 'Supply both from and to, with from <= to.', Comment = 'is-IS=Sendu bæði from og to, með from <= to.';
        NotFoundNextTxt: Label 'Use an existing time sheet number.', Comment = 'is-IS=Notaðu fyrirliggjandi tímaskýrslunúmer.';
        SetupMsg: Label 'Time sheets are not set up: Resources Setup has no Time Sheet Nos.', Comment = 'is-IS=Tímaskýrslur eru ekki uppsettar: Time Sheet Nos. vantar í Resources Setup.';
        SetupNextTxt: Label 'Ask an administrator to set Time Sheet Nos. in Resources Setup.', Comment = 'is-IS=Biddu stjórnanda að setja Time Sheet Nos. í Resources Setup.';
        WeekdayNextTxt: Label 'Use a startingDate on the first weekday of the time sheet period in Resources Setup.', Comment = 'is-IS=Notaðu startingDate á fyrsta vikudegi tímaskýrslutímabils í Resources Setup.';
        ChooseResourceNextTxt: Label 'You own more than one time sheet resource; send resourceNo.', Comment = 'is-IS=Þú átt fleiri en einn tímaskýrsluforða; sendu resourceNo.';
        NotOwnResourceNextTxt: Label 'Use a resource whose Time Sheet Owner User ID is your user.', Comment = 'is-IS=Notaðu forða þar sem Time Sheet Owner User ID er notandinn þinn.';
        NotOwnResourceMsg: Label 'The resource is not a time sheet resource of the caller.', Comment = 'is-IS=Forðinn er ekki tímaskýrsluforði kallanda.';
        LockedLineMsg: Label 'Only open or rejected lines can be changed.', Comment = 'is-IS=Aðeins er hægt að breyta opnum eða höfnuðum línum.';
        LockedLineNextTxt: Label 'Ask the approver to reject the line, then edit it.', Comment = 'is-IS=Biddu samþykkjanda að hafna línunni og breyttu henni síðan.';
        IsolatedMsg: Label 'This operation requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        IsolatedNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        MissingNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeChangeNextTxt: Label 'Keep the line type; add a new line for another type.', Comment = 'is-IS=Haltu tegund línunnar; bættu við nýrri línu fyrir aðra tegund.';
        DayRangeNextTxt: Label 'Use dates inside the time sheet period and hours from 0 to 24.', Comment = 'is-IS=Notaðu dagsetningar innan tímabils tímaskýrslunnar og stundir frá 0 til 24.';
        RetryNextTxt: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';

    /// <summary>True when the caller can read native time sheets.</summary>
    procedure CanReadSheets(): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        CommentLine: Record "Time Sheet Comment Line";
        Resource: Record Resource;
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Detail.ReadPermission() and
             CommentLine.ReadPermission() and Resource.ReadPermission());
    end;

    /// <summary>True when the caller can insert time sheet headers and lines.</summary>
    procedure CanCreateSheets(): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        ResourcesSetup: Record "Resources Setup";
    begin
        exit(Header.WritePermission() and Line.WritePermission() and ResourcesSetup.ReadPermission());
    end;

    /// <summary>Reads the caller's own time sheets (Projects.MyTimeSheet.Get).</summary>
    procedure ExecuteMyGet(var Argument: Record "Message Argument ori")
    begin
        ExecuteGet(Argument, false);
    end;

    /// <summary>Reads the sheets waiting for the caller's approval (Projects.TimeSheetApproval.Get).</summary>
    procedure ExecuteApprovalGet(var Argument: Record "Message Argument ori")
    begin
        ExecuteGet(Argument, true);
    end;

    /// <summary>Submits the caller's own open lines (Projects.MyTimeSheet.Submit).</summary>
    procedure ExecuteMySubmit(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not CanReadSheets() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        if not IsOwnerMapped() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedOwnerMsg, '', UnmappedOwnerNextTxt);
            exit;
        end;
        if FindNamedSheet(Argument.GetRequestJson(), Header) then
            if not SameUser(Header."Owner User ID") then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotOwnerMsg, 'timeSheetNo', NotOwnerNextTxt);
                exit;
            end;
        NativeMgt.ExecuteSubmit(Argument);
    end;

    /// <summary>Approves or rejects lines on a sheet in the caller's queue (Projects.TimeSheetApproval.Approve/Reject).</summary>
    procedure ExecuteApprovalDecision(var Argument: Record "Message Argument ori"; IsReject: Boolean)
    var
        Header: Record "Time Sheet Header";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not CanReadSheets() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        if not IsApproverMapped() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedApproverMsg, '', UnmappedApproverNextTxt);
            exit;
        end;
        if FindNamedSheet(Argument.GetRequestJson(), Header) then begin
            if not SameUser(Header."Approver User ID") then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotApproverMsg, 'timeSheetNo', NotApproverNextTxt);
                exit;
            end;
            if SameUser(Header."Owner User ID") then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, SelfApproveMsg, 'timeSheetNo', SelfApproveNextTxt);
                exit;
            end;
        end;
        if IsReject then
            NativeMgt.ExecuteReject(Argument)
        else
            NativeMgt.ExecuteApprove(Argument);
    end;

    /// <summary>True when the caller is the time sheet owner of at least one resource or sheet.</summary>
    procedure IsOwnerMapped(): Boolean
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
    begin
        if CallerId() = '' then
            exit(false);
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.SetRange("Time Sheet Owner User ID", CallerId());
        if not Resource.IsEmpty() then
            exit(true);
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetRange("Owner User ID", CallerId());
        exit(not Header.IsEmpty());
    end;

    /// <summary>True when the caller is the time sheet approver of at least one resource or sheet.</summary>
    procedure IsApproverMapped(): Boolean
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
    begin
        if CallerId() = '' then
            exit(false);
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.SetRange("Time Sheet Approver User ID", CallerId());
        if not Resource.IsEmpty() then
            exit(true);
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetRange("Approver User ID", CallerId());
        exit(not Header.IsEmpty());
    end;

    /// <summary>Creates the caller's own time sheet for one period through the native report (Projects.MyTimeSheet.Create).</summary>
    procedure ExecuteMyCreate(var Argument: Record "Message Argument ori")
    var
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        Header: Record "Time Sheet Header";
        TempWriteArgument: Record "Message Argument ori" temporary;
        CreateContext: Codeunit "TS My Create Context ori";
        Request: JsonObject;
        Normalized: JsonObject;
        Response: JsonObject;
        SheetNode: JsonObject;
        ResourceNos: JsonArray;
        Token: JsonToken;
        ParameterName: Text;
        ResourceNo: Code[20];
        StartingDate: Date;
        Created: Boolean;
        Succeeded: Boolean;
    begin
        Argument.AssertVersion1();
        if not CanReadSheets() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['startingDate', 'resourceNo']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, RefusedMsg, ParameterName, UnknownNextTxt);
                exit;
            end;
        if not Request.Get('startingDate', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'startingDate', MissingNextTxt);
            exit;
        end;
        if not IsText(Token, 10, false) then begin
            BadFormat(Argument, 'startingDate');
            exit;
        end;
        if not Evaluate(StartingDate, Token.AsValue().AsText(), 9) then begin
            BadFormat(Argument, 'startingDate');
            exit;
        end;
        // Own resources only: Time Sheet Owner User ID is the caller and the resource uses time sheets.
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.SetRange("Time Sheet Owner User ID", CallerId());
        Resource.SetRange("Use Time Sheet", true);
        if CallerId() = '' then
            Resource.SetRange("No.", '');
        if Request.Get('resourceNo', Token) then begin
            if not IsText(Token, MaxStrLen(ResourceNo), false) then begin
                BadFormat(Argument, 'resourceNo');
                exit;
            end;
            ResourceNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ResourceNo));
            Resource.SetRange("No.", ResourceNo);
            if Resource.IsEmpty() then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotOwnResourceMsg, 'resourceNo', NotOwnResourceNextTxt);
                exit;
            end;
        end else begin
            if Resource.IsEmpty() then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedOwnerMsg, '', UnmappedOwnerNextTxt);
                exit;
            end;
            if Resource.Count() > 1 then begin
                Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'resourceNo', ChooseResourceNextTxt);
                exit;
            end;
            Resource.FindFirst();
            ResourceNo := Resource."No.";
        end;
        if not ResourcesSetup.Get() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SetupMsg, '', SetupNextTxt);
            exit;
        end;
        if ResourcesSetup."Time Sheet Nos." = '' then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SetupMsg, '', SetupNextTxt);
            exit;
        end;
        if Date2DWY(StartingDate, 1) <> ResourcesSetup."Time Sheet First Weekday" + 1 then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, RefusedMsg, 'startingDate', WeekdayNextTxt);
            exit;
        end;
        if Argument."Omit Commit" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, IsolatedMsg, '', IsolatedNextTxt);
            exit;
        end;
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetRange("Starting Date", StartingDate);
        Header.SetRange("Ending Date", StartingDate + 6);
        // A sheet that already exists is a typed no-op: return it with created false.
        Created := Header.IsEmpty();
        if Created then begin
            ResourceNos.Add(ResourceNo);
            Normalized.Add('startingDate', Format(StartingDate, 0, 9));
            Normalized.Add('numberOfPeriods', 1);
            Normalized.Add('resourceNos', ResourceNos);
            Normalized.Add('createLinesFromPlanning', false);
            TempWriteArgument := Argument;
            TempWriteArgument.Insert();
            TempWriteArgument.SetRequestJson(Normalized);
            if Database.IsInWriteTransaction() then
                Commit();
            ClearLastError();
            CreateContext.SetOwnResource(ResourceNo);
            Succeeded := Codeunit.Run(Codeunit::"TS Create Writer ori", TempWriteArgument);
            CreateContext.Clear();
            if not Succeeded then begin
                Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(GetLastErrorText(), 1, 250), '', RetryNextTxt);
                exit;
            end;
        end;
        Header.FindFirst();
        // The resource may have been reassigned: a sheet that another user owns is never returned,
        // on the create path or on the no-op path.
        if not SameUser(Header."Owner User ID") then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotOwnerMsg, 'resourceNo', NotOwnerNextTxt);
            exit;
        end;
        SheetNode.Add('timeSheetNo', Header."No.");
        SheetNode.Add('resourceNo', Header."Resource No.");
        SheetNode.Add('startingDate', Format(Header."Starting Date", 0, 9));
        SheetNode.Add('endingDate', Format(Header."Ending Date", 0, 9));
        Response.Add('status', 'Success');
        Response.Add('created', Created);
        Response.Add('timeSheet', SheetNode);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Adds or edits lines and daily hours on the caller's own sheet (Projects.MyTimeSheetLine.Set).</summary>
    procedure ExecuteMyLineSet(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Runner: Codeunit "TS My Line Set Runner ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        ParameterName: Text;
        SheetNo: Code[20];
    begin
        Argument.AssertVersion1();
        if not CanReadSheets() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        if not IsOwnerMapped() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedOwnerMsg, '', UnmappedOwnerNextTxt);
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['timeSheetNo', 'lines']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, RefusedMsg, ParameterName, UnknownNextTxt);
                exit;
            end;
        if not Request.Get('timeSheetNo', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'timeSheetNo', MissingNextTxt);
            exit;
        end;
        if not IsText(Token, MaxStrLen(SheetNo), false) then begin
            BadFormat(Argument, 'timeSheetNo');
            exit;
        end;
        SheetNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(SheetNo));
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Header.Get(SheetNo) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, RefusedMsg, 'timeSheetNo', NotFoundNextTxt);
            exit;
        end;
        if not SameUser(Header."Owner User ID") then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotOwnerMsg, 'timeSheetNo', NotOwnerNextTxt);
            exit;
        end;
        if not Request.Get('lines', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'lines', MissingNextTxt);
            exit;
        end;
        if not Token.IsArray() then begin
            BadFormat(Argument, 'lines');
            exit;
        end;
        if (Token.AsArray().Count() = 0) or (Token.AsArray().Count() > 50) then begin
            BadFormat(Argument, 'lines');
            exit;
        end;
        foreach Entry in Token.AsArray() do
            if not ValidateLineEntry(Argument, Header, Entry) then
                exit;
        if Argument."Omit Commit" then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, IsolatedMsg, '', IsolatedNextTxt);
            exit;
        end;
        // A captured Codeunit.Run cannot roll back inside an open write transaction; commit first,
        // so the runner has its own transaction that commits or rolls back as a whole.
        if Database.IsInWriteTransaction() then
            Commit();
        Runner.SetRequest(Header."No.", Token.AsArray());
        if not Runner.Run() then begin
            Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(GetLastErrorText(), 1, 250), 'lines', RetryNextTxt);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('timeSheetNo', Header."No.");
        Response.Add('lines', Runner.GetResults());
        Argument.SetResponseJson(Response);
    end;

    local procedure ValidateLineEntry(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; Entry: JsonToken): Boolean
    var
        Line: Record "Time Sheet Line";
        EntryObject: JsonObject;
        Token: JsonToken;
        Day: JsonToken;
        DayObject: JsonObject;
        ParameterName: Text;
        LineNo: Integer;
        DayDate: Date;
        Hours: Decimal;
        IsNew: Boolean;
    begin
        if not Entry.IsObject() then
            exit(BadFormat(Argument, 'lines'));
        EntryObject := Entry.AsObject();
        foreach ParameterName in EntryObject.Keys() do
            if not (ParameterName in ['lineNo', 'type', 'projectNo', 'taskNo', 'workTypeCode', 'description', 'days']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, RefusedMsg, 'lines.' + ParameterName, UnknownNextTxt);
                exit(false);
            end;
        IsNew := not EntryObject.Get('lineNo', Token);
        if not IsNew then begin
            if not ReadPositiveInteger(Token, LineNo) then
                exit(BadFormat(Argument, 'lines.lineNo'));
            Line.ReadIsolation := IsolationLevel::ReadCommitted;
            if not Line.Get(Header."No.", LineNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, RefusedMsg, 'lines.lineNo', NotFoundNextTxt);
                exit(false);
            end;
            if not (Line.Status in [Line.Status::Open, Line.Status::Rejected]) then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, LockedLineMsg, 'lines.lineNo', LockedLineNextTxt);
                exit(false);
            end;
        end;
        if EntryObject.Get('type', Token) then begin
            if not IsText(Token, 20, false) then
                exit(BadFormat(Argument, 'lines.type'));
            if not (Token.AsValue().AsText() in ['Job', 'Resource']) then
                exit(BadFormat(Argument, 'lines.type'));
            if not IsNew then
                if Token.AsValue().AsText() <> Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, RefusedMsg, 'lines.type', TypeChangeNextTxt);
                    exit(false);
                end;
        end else
            if IsNew then begin
                Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'lines.type', MissingNextTxt);
                exit(false);
            end;
        // AL does not short-circuit 'and': read the type only for a new line, where it is present.
        if IsNew then
            if EntryObject.GetText('type') = 'Job' then begin
                if not EntryObject.Contains('projectNo') then begin
                    Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'lines.projectNo', MissingNextTxt);
                    exit(false);
                end;
                if not EntryObject.Contains('taskNo') then begin
                    Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'lines.taskNo', MissingNextTxt);
                    exit(false);
                end;
            end;
        if EntryObject.Get('projectNo', Token) then
            if not IsText(Token, 20, false) then
                exit(BadFormat(Argument, 'lines.projectNo'));
        if EntryObject.Get('taskNo', Token) then
            if not IsText(Token, 20, false) then
                exit(BadFormat(Argument, 'lines.taskNo'));
        if EntryObject.Get('workTypeCode', Token) then
            if not IsText(Token, 10, true) then
                exit(BadFormat(Argument, 'lines.workTypeCode'));
        if EntryObject.Get('description', Token) then
            if not IsText(Token, MaxStrLen(Line.Description), true) then
                exit(BadFormat(Argument, 'lines.description'));
        if EntryObject.Get('days', Token) then begin
            if not Token.IsArray() then
                exit(BadFormat(Argument, 'lines.days'));
            foreach Day in Token.AsArray() do begin
                if not Day.IsObject() then
                    exit(BadFormat(Argument, 'lines.days'));
                DayObject := Day.AsObject();
                if (DayObject.Keys().Count() <> 2) or not DayObject.Get('date', Token) then
                    exit(BadFormat(Argument, 'lines.days'));
                if not IsText(Token, 10, false) then
                    exit(BadFormat(Argument, 'lines.days'));
                if not Evaluate(DayDate, Token.AsValue().AsText(), 9) then
                    exit(BadFormat(Argument, 'lines.days'));
                if not DayObject.Get('hours', Token) then
                    exit(BadFormat(Argument, 'lines.days'));
                if not ReadDecimal(Token, Hours) then
                    exit(BadFormat(Argument, 'lines.days'));
                if (DayDate < Header."Starting Date") or (DayDate > Header."Ending Date") or (Hours < 0) or (Hours > 24) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, RefusedMsg, 'lines.days', DayRangeNextTxt);
                    exit(false);
                end;
            end;
        end;
        exit(true);
    end;

    local procedure IsText(Token: JsonToken; MaxLength: Integer; AllowEmpty: Boolean): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then
            exit(false);
        if (not AllowEmpty) and (Token.AsValue().AsText() = '') then
            exit(false);
        exit(StrLen(Token.AsValue().AsText()) <= MaxLength);
    end;

    local procedure ReadDecimal(Token: JsonToken; var Value: Decimal): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') then
            exit(false);
        exit(Evaluate(Value, Raw, 9));
    end;

    local procedure ReadPositiveInteger(Token: JsonToken; var Value: Integer): Boolean
    var
        Number: Decimal;
    begin
        if not ReadDecimal(Token, Number) then
            exit(false);
        if (Number <> Round(Number, 1)) or (Number <= 0) or (Number > 2147483647) then
            exit(false);
        Value := Number;
        exit(true);
    end;

    local procedure ExecuteGet(var Argument: Record "Message Argument ori"; AsApprover: Boolean)
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
        Sheets: JsonArray;
        SheetNo: Code[20];
        FromDate: Date;
        ToDate: Date;
        LineStatus: Enum "Time Sheet Status";
        HasStatus: Boolean;
        TakeCount: Integer;
        SkipCount: Integer;
        HasMore: Boolean;
    begin
        Argument.AssertVersion1();
        if not CanReadSheets() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        if AsApprover then begin
            if not IsApproverMapped() then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedApproverMsg, '', UnmappedApproverNextTxt);
                exit;
            end;
        end else
            if not IsOwnerMapped() then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, UnmappedOwnerMsg, '', UnmappedOwnerNextTxt);
                exit;
            end;
        Request := Argument.GetRequestJson();
        if not ValidateGetRequest(Argument, Request, AsApprover) then
            exit;
        if Request.Contains('from') <> Request.Contains('to') then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, RefusedMsg, 'from,to', DatesNextTxt);
            exit;
        end;
        if Request.Contains('from') then begin
            Evaluate(FromDate, Request.GetText('from'), 9);
            Evaluate(ToDate, Request.GetText('to'), 9);
            if FromDate > ToDate then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, RefusedMsg, 'from,to', DatesNextTxt);
                exit;
            end;
        end;
        if Request.Contains('timeSheetNo') then begin
            SheetNo := CopyStr(Request.GetText('timeSheetNo'), 1, MaxStrLen(SheetNo));
            Header.ReadIsolation := IsolationLevel::ReadCommitted;
            if not Header.Get(SheetNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, RefusedMsg, 'timeSheetNo', NotFoundNextTxt);
                exit;
            end;
            if AsApprover then begin
                if not SameUser(Header."Approver User ID") then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotApproverMsg, 'timeSheetNo', NotApproverNextTxt);
                    exit;
                end;
                if SameUser(Header."Owner User ID") then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, SelfApproveMsg, 'timeSheetNo', SelfApproveNextTxt);
                    exit;
                end;
            end else
                if not SameUser(Header."Owner User ID") then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, NotOwnerMsg, 'timeSheetNo', NotOwnerNextTxt);
                    exit;
                end;
        end;
        if Request.Contains('status') then begin
            HasStatus := true;
            LineStatus := Enum::"Time Sheet Status".FromInteger(LineStatus.Ordinals().Get(LineStatus.Names().IndexOf(Request.GetText('status'))));
        end;
        if AsApprover then begin
            HasStatus := true;
            LineStatus := LineStatus::Submitted;
        end;
        TakeCount := 20;
        if Request.Contains('take') then
            TakeCount := Request.GetInteger('take');
        if Request.Contains('skip') then
            SkipCount := Request.GetInteger('skip');
        HasMore := ReadSheets(AsApprover, SheetNo, FromDate, ToDate, HasStatus, LineStatus, TakeCount, SkipCount, Sheets);
        Response.Add('status', 'Success');
        Response.Add('timeSheets', Sheets);
        Response.Add('hasMore', HasMore);
        Argument.SetResponseJson(Response);
    end;

    local procedure ValidateGetRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; AsApprover: Boolean): Boolean
    var
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
        DateValue: Date;
        NumberValue: Decimal;
        LineStatus: Enum "Time Sheet Status";
    begin
        foreach ParameterName in Request.Keys() do begin
            if not (ParameterName in ['timeSheetNo', 'from', 'to', 'status', 'take', 'skip']) or (AsApprover and (ParameterName = 'status')) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, RefusedMsg, ParameterName, UnknownNextTxt);
                exit(false);
            end;
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
                case ParameterName of
                    'timeSheetNo':
                        if (StrLen(Token.AsValue().AsText()) = 0) or (StrLen(Token.AsValue().AsText()) > 20) then
                            exit(BadFormat(Argument, ParameterName));
                    'from', 'to':
                        if (StrLen(Token.AsValue().AsText()) <> 10) or not Evaluate(DateValue, Token.AsValue().AsText(), 9) or (DateValue = 0D) then
                            exit(BadFormat(Argument, ParameterName));
                    'status':
                        if (Token.AsValue().AsText() = '') or not LineStatus.Names().Contains(Token.AsValue().AsText()) then
                            exit(BadFormat(Argument, ParameterName));
                end;
            end;
        end;
        exit(true);
    end;

    local procedure ReadSheets(AsApprover: Boolean; SheetNo: Code[20]; FromDate: Date; ToDate: Date; HasStatus: Boolean; LineStatus: Enum "Time Sheet Status"; TakeCount: Integer; SkipCount: Integer; var Sheets: JsonArray): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Seen: Integer;
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if AsApprover then begin
            Header.SetRange("Approver User ID", CallerId());
            Header.SetFilter("Owner User ID", '<>%1', CallerId());
        end else
            Header.SetRange("Owner User ID", CallerId());
        if SheetNo <> '' then
            Header.SetRange("No.", SheetNo);
        if FromDate <> 0D then begin
            Header.SetFilter("Starting Date", '<=%1', ToDate);
            Header.SetFilter("Ending Date", '>=%1', FromDate);
        end;
        if Header.FindSet() then
            repeat
                Line.ReadIsolation := IsolationLevel::ReadCommitted;
                Line.SetRange("Time Sheet No.", Header."No.");
                if HasStatus then
                    Line.SetRange(Status, LineStatus);
                // The approver queue lists only sheets with a line waiting for a decision.
                if (SheetNo <> '') or not AsApprover or not Line.IsEmpty() then begin
                    Seen += 1;
                    if Seen > SkipCount then begin
                        if Sheets.Count() = TakeCount then
                            exit(true);
                        Sheets.Add(SheetJson(Header, Line, AsApprover));
                    end;
                end;
            until Header.Next() = 0;
        exit(false);
    end;

    local procedure SheetJson(Header: Record "Time Sheet Header"; var Line: Record "Time Sheet Line"; AsApprover: Boolean) Result: JsonObject
    var
        Lines: JsonArray;
    begin
        Result.Add('timeSheetNo', Header."No.");
        Result.Add('timeSheetId', Format(Header.SystemId, 0, 4).ToLower());
        Result.Add('resourceNo', Header."Resource No.");
        Result.Add('startingDate', Header."Starting Date");
        Result.Add('endingDate', Header."Ending Date");
        if AsApprover then
            Result.Add('ownerUserId', Header."Owner User ID");
        if Line.FindSet() then
            repeat
                Lines.Add(LineJson(Line));
            until Line.Next() = 0;
        Result.Add('lines', Lines);
    end;

    local procedure LineJson(Line: Record "Time Sheet Line") Result: JsonObject
    var
        Detail: Record "Time Sheet Detail";
        CommentLine: Record "Time Sheet Comment Line";
        Days: JsonArray;
        Comments: JsonArray;
        Day: JsonObject;
        CommentNode: JsonObject;
        TotalHours: Decimal;
    begin
        Detail.ReadIsolation := IsolationLevel::ReadCommitted;
        Detail.SetRange("Time Sheet No.", Line."Time Sheet No.");
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        if Detail.FindSet() then
            repeat
                Clear(Day);
                Day.Add('date', Detail.Date);
                Day.Add('hours', Detail.Quantity);
                Days.Add(Day);
                TotalHours += Detail.Quantity;
            until Detail.Next() = 0;
        CommentLine.ReadIsolation := IsolationLevel::ReadCommitted;
        CommentLine.SetRange("No.", Line."Time Sheet No.");
        CommentLine.SetRange("Time Sheet Line No.", Line."Line No.");
        if CommentLine.FindSet() then
            repeat
                Clear(CommentNode);
                CommentNode.Add('date', CommentLine.Date);
                CommentNode.Add('comment', CommentLine.Comment);
                Comments.Add(CommentNode);
            until CommentLine.Next() = 0;
        Result.Add('lineNo', Line."Line No.");
        Result.Add('type', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
        Result.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
        Result.Add('projectNo', Line."Job No.");
        Result.Add('taskNo', Line."Job Task No.");
        Result.Add('causeOfAbsenceCode', Line."Cause of Absence Code");
        Result.Add('workTypeCode', Line."Work Type Code");
        Result.Add('description', Line.Description);
        Result.Add('chargeable', Line.Chargeable);
        Result.Add('posted', Line.Posted);
        Result.Add('days', Days);
        Result.Add('totalHours', TotalHours);
        Result.Add('comments', Comments);
    end;

    /// <summary>Finds the sheet named by timeSheetNo or timeSheetId when the key is well formed; the native manager reports malformed keys.</summary>
    local procedure FindNamedSheet(Request: JsonObject; var Header: Record "Time Sheet Header"): Boolean
    var
        Token: JsonToken;
        SheetId: Guid;
        SheetNo: Code[20];
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if Request.Get('timeSheetNo', Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    if (StrLen(Token.AsValue().AsText()) > 0) and (StrLen(Token.AsValue().AsText()) <= MaxStrLen(SheetNo)) then begin
                        SheetNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(SheetNo));
                        if Header.Get(SheetNo) then
                            exit(true);
                    end;
        if Request.Get('timeSheetId', Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    if Evaluate(SheetId, Token.AsValue().AsText()) then
                        exit(Header.GetBySystemId(SheetId));
        exit(false);
    end;

    local procedure CallerId(): Code[50]
    begin
        exit(CopyStr(UpperCase(UserId()), 1, 50));
    end;

    local procedure SameUser(Stored: Code[50]): Boolean
    begin
        if (Stored = '') or (CallerId() = '') then
            exit(false);
        exit(Stored = CallerId());
    end;

    local procedure BadFormat(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    begin
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, RefusedMsg, ParameterName, FormatNextTxt);
        exit(false);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; ParameterName: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, ParameterName, '', '', NextStep);
    end;
}
