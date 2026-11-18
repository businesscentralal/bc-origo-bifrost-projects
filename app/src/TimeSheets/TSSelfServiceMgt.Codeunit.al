namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
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
