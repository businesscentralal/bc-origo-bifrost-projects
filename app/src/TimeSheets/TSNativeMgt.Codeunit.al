namespace Origo.Bifrost.Projects;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using System.Security.User;

/// <summary>
/// Request checks and dispatch for the native Timesheets message types.
/// Each Execute procedure reads only that type's keys. Writes run in
/// "TS Native Runner ori" so a failure rolls back.
/// </summary>
codeunit 70013566 "TS Native Mgt ori"
{
    Access = Internal;

    var
        BatchMsg: Label 'Submit needs its own write transaction.', Comment = 'is-IS=Innsending þarf eigin skrifaðgerð.';
        BatchNextTxt: Label 'Submit outside an uncommitted batch.', Comment = 'is-IS=Sendu inn utan óstaðfestrar lotu.';
        OwnerSubmitNextTxt: Label 'Only the owner can submit; ask the owner.', Comment = 'is-IS=Aðeins eigandinn getur sent inn. Biddu eigandann.';
        AddLinesNextTxt: Label 'Add lines first.', Comment = 'is-IS=Bættu við línum fyrst.';
        FixLineNextTxt: Label 'Fix the line and submit again.', Comment = 'is-IS=Lagfærðu línuna og sendu aftur inn.';
        OwnerSubmitMsg: Label 'The caller is not the owner of the time sheet.', Comment = 'is-IS=Kallandinn er ekki eigandi tímaskýrslunnar.';
        AddLinesMsg: Label 'The time sheet has no open lines.', Comment = 'is-IS=Tímaskýrslan hefur engar opnar línur.';
        IsolatedMsg: Label 'This operation requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        IsolatedNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        MissingKeyNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownKeyNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        IdentifierNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        OneIdentifierNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        ApproverNextTxt: Label 'Only the approver named on the time sheet can approve.', Comment = 'is-IS=Aðeins samþykktaraðilinn sem er nefndur á tímaskýrslunni getur samþykkt.';
        SubmitFirstNextTxt: Label 'Submit it first with Projects.TimeSheet.Submit.', Comment = 'is-IS=Sendu hana fyrst inn með Projects.TimeSheet.Submit.';
        AssignSetNextTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        RetryNextTxt: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';
        MissingKeyMsg: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        TypeMsg: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        UnknownKeyMsg: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        IdentifierMsg: Label 'The identifier does not match a record in %1.', Comment = '%1 = table caption; is-IS=Auðkennið passar ekki við færslu í %1.';
        OneIdentifierMsg: Label 'The request names the time sheet in more than one way.', Comment = 'is-IS=Beiðnin nefnir tímaskýrsluna á fleiri en einn hátt.';
        ApproverMsg: Label 'The caller is not the approver named on the time sheet.', Comment = 'is-IS=Kallandinn er ekki samþykktaraðilinn sem er nefndur á tímaskýrslunni.';
        SubmitFirstMsg: Label 'The line is not submitted.', Comment = 'is-IS=Línan hefur ekki verið send inn.';
        AssignSetMsg: Label 'The caller cannot write time sheets.', Comment = 'is-IS=Kallandinn getur ekki skrifað tímaskýrslur.';
        MissingJournalMsg: Label 'No Job Journal target was supplied. Send journalTemplate and journalBatch.', Comment = 'is-IS=Engin verkbók var send. Sendu journalTemplate og journalBatch.';
        JournalLengthMsg: Label 'A journal identifier exceeds the maximum length of 10 characters.', Comment = 'is-IS=Auðkenni verkbókar er lengra en 10 stafir sem eru hámarkslengd.';
        // NativeNameNextTxt: Label 'Use the native name.', Comment = 'is-IS=Notaðu innlenda heitið.';
        JournalIdentifierMsg: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        FixLineMsg: Label 'Business Central rejected the line.', Comment = 'is-IS=Business Central hafnaði línunni.';
        // LegacyMsg: Label 'The Clockify.TimeSheet name still runs. Use the native name.', Comment = 'is-IS=Clockify.TimeSheet heitið keyrir enn. Notaðu innlenda heitið.';

    /// <summary>Checks access to the native action's reads and writes before discovery or execution.</summary>
    procedure CanMaintainSheets(IsReject: Boolean): Boolean
    var
        CauseOfAbsence: Record "Cause of Absence";
        HumanResourcesSetup: Record "Human Resources Setup";
        HumanResourceUom: Record "Human Resource Unit of Measure";
        EmployeeAbsence: Record "Employee Absence";
        Employee: Record Employee;
        Resource: Record Resource;
        CommentLine: Record "Time Sheet Comment Line";
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        PostingEntry: Record "Time Sheet Posting Entry";
        UserSetup: Record "User Setup";
    begin
        if not (Header.ReadPermission() and Line.ReadPermission() and Line.WritePermission() and
                Detail.ReadPermission() and Detail.WritePermission() and Resource.ReadPermission() and UserSetup.ReadPermission()) then
            exit(false);
        if IsReject then
            exit(CommentLine.ReadPermission() and CommentLine.WritePermission());
        exit(CauseOfAbsence.ReadPermission() and HumanResourcesSetup.ReadPermission() and HumanResourceUom.ReadPermission() and
            Employee.ReadPermission() and EmployeeAbsence.ReadPermission() and EmployeeAbsence.WritePermission() and
            PostingEntry.ReadPermission() and PostingEntry.WritePermission());
    end;

    /// <summary>Approves submitted lines, preserving an explicitly selected already approved line.</summary>
    procedure ExecuteApprove(var Argument: Record "Message Argument ori")
    begin
        ExecuteDecision(Argument, false, '');
    end;

    /// <summary>Rejects submitted lines with an optional bounded comment.</summary>
    procedure ExecuteReject(var Argument: Record "Message Argument ori")
    var
        CommentLine: Record "Time Sheet Comment Line";
        Comment: Text;
        CommentToken: JsonToken;
        RequestJson: JsonObject;
    begin
        if Deny(Argument, true) then
            exit;
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('comment', CommentToken) then begin
            if not IsJsonString(CommentToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'comment', TypeNextTxt);
                exit;
            end;
            Comment := CommentToken.AsValue().AsText();
            if StrLen(Comment) > MaxStrLen(CommentLine.Comment) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'comment', TypeNextTxt);
                exit;
            end;
        end;
        ExecuteDecision(Argument, true, Comment);
    end;

    local procedure ExecuteDecision(var Argument: Record "Message Argument ori"; IsReject: Boolean; Comment: Text)
    var
        Header: Record "Time Sheet Header";
        Context: Codeunit "TS Native Context ori";
        Actionable: Integer;
        Allowed: List of [Text];
        LineFilter: Text;
        LinesToken: JsonToken;
        Numbers: List of [Integer];
        RequestJson: JsonObject;
    begin
        if Deny(Argument, IsReject) then
            exit;
        RequestJson := Argument.GetRequestJson();
        Allowed.Add('timeSheetNo');
        Allowed.Add('timeSheetId');
        Allowed.Add('lineNos');
        if IsReject then
            Allowed.Add('comment');
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        if not ResolveSheet(Argument, RequestJson, Header) then
            exit;
        if not SameUser(Header."Approver User ID") then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, ApproverMsg, 'timeSheetNo', ApproverNextTxt);
            exit;
        end;
        if not ReadLineSelection(Argument, RequestJson, LinesToken, Numbers, LineFilter) then
            exit;
        if not DecisionSelection(Argument, Header, Numbers, LineFilter, Actionable, IsReject) then
            exit;
        if Actionable = 0 then begin
            RespondExisting(Argument, Header."No.", LineFilter, true);
            exit;
        end;
        if IsReject then
            Context.SetReject(Header."No.", LineFilter, Comment)
        else
            Context.SetApprove(Header."No.", LineFilter);
        RunAndRespond(Argument);
    end;

    local procedure ResolveSheet(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Header: Record "Time Sheet Header"): Boolean
    var
        SheetToken: JsonToken;
        IdToken: JsonToken;
        SheetId: Guid;
        HasNo: Boolean;
        HasId: Boolean;
    begin
        HasNo := RequestJson.Get('timeSheetNo', SheetToken);
        HasId := RequestJson.Get('timeSheetId', IdToken);
        if HasNo and HasId then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'timeSheetNo', OneIdentifierNextTxt);
            exit(false);
        end;
        if not (HasNo or HasId) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, 'timeSheetNo', MissingKeyNextTxt);
            exit(false);
        end;
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if HasNo then
            exit(LoadSheetToken(Argument, SheetToken, Header));
        if not IsJsonString(IdToken) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetId', TypeNextTxt);
            exit(false);
        end;
        if not Evaluate(SheetId, IdToken.AsValue().AsText()) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetId', TypeNextTxt);
            exit(false);
        end;
        if not Header.GetBySystemId(SheetId) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(IdentifierMsg, Header.TableCaption()), 'timeSheetId', IdentifierNextTxt);
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
        if (StrLen(SheetToken.AsValue().AsText()) = 0) or (StrLen(SheetToken.AsValue().AsText()) > MaxStrLen(SheetNo)) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'timeSheetNo', TypeNextTxt);
            exit(false);
        end;
        SheetNo := CopyStr(SheetToken.AsValue().AsText(), 1, MaxStrLen(SheetNo));
        if not Header.Get(SheetNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(IdentifierMsg, Header.TableCaption()), 'timeSheetNo', IdentifierNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadLineSelection(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var LinesToken: JsonToken; var Numbers: List of [Integer]; var LineFilter: Text): Boolean
    var
        Entry: JsonToken;
        Index: Integer;
        LineNo: Integer;
    begin
        if not RequestJson.Get('lineNos', LinesToken) then begin
            LineFilter := '*';
            exit(true);
        end;
        if not LinesToken.IsArray() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'lineNos', TypeNextTxt);
            exit(false);
        end;
        LineFilter := '';
        for Index := 0 to LinesToken.AsArray().Count() - 1 do begin
            LinesToken.AsArray().Get(Index, Entry);
            if not ReadJsonInteger(Entry, LineNo) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'lineNos', TypeNextTxt);
                exit(false);
            end;
            if LineNo <= 0 then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'lineNos', TypeNextTxt);
                exit(false);
            end;
            if Numbers.Contains(LineNo) then
                continue;
            Numbers.Add(LineNo);
            if LineFilter <> '' then
                LineFilter += '|';
            LineFilter += Format(LineNo, 0, 9);
        end;
        exit(true);
    end;

    local procedure DecisionSelection(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; Numbers: List of [Integer]; var LineFilter: Text; var Actionable: Integer; IsReject: Boolean): Boolean
    var
        Line: Record "Time Sheet Line";
        LineNo: Integer;
    begin
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        Actionable := 0;
        if LineFilter = '*' then begin
            Line.SetRange("Time Sheet No.", Header."No.");
            Line.SetRange(Status, Line.Status::Submitted);
            Actionable := Line.Count();
            LineFilter := FilterOf(Line);
            exit(true);
        end;
        if Numbers.Count() = 0 then
            exit(true);
        foreach LineNo in Numbers do begin
            if not Line.Get(Header."No.", LineNo) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(IdentifierMsg, Line.TableCaption()), 'lineNos', IdentifierNextTxt);
                exit(false);
            end;
            if Line.Status = Line.Status::Submitted then
                Actionable += 1
            else
                if IsReject or (Line.Status <> Line.Status::Approved) then begin
                    Fail(Argument, "Bifrost Error Code ori"::InvalidLine, SubmitFirstMsg, 'lineNos', SubmitFirstNextTxt);
                    exit(false);
                end;
        end;
        exit(true);
    end;

    local procedure FilterOf(var Line: Record "Time Sheet Line") Result: Text
    begin
        if Line.FindSet() then
            repeat
                if Result <> '' then
                    Result += '|';
                Result += Format(Line."Line No.", 0, 9);
            until Line.Next() = 0;
    end;

    local procedure RespondExisting(var Argument: Record "Message Argument ori"; SheetNo: Code[20]; LineFilter: Text; Decision: Boolean)
    var
        Line: Record "Time Sheet Line";
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        if LineFilter <> '' then begin
            Line.SetRange("Time Sheet No.", SheetNo);
            if LineFilter <> '*' then
                Line.SetFilter("Line No.", LineFilter);
            if Line.FindSet() then
                repeat
                    Lines.Add(ExistingNode(Line, Decision));
                until Line.Next() = 0;
        end;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Argument.SetResponseJson(Response);
    end;

    local procedure ExistingNode(Line: Record "Time Sheet Line"; Decision: Boolean) Node: JsonObject
    begin
        Node.Add('timeSheetNo', Line."Time Sheet No.");
        Node.Add('lineNo', Line."Line No.");
        Node.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
        Node.Add('changed', false);
        if Decision then
            Node.Add('decision', true)
        else
            Node.Add('lineType', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
    end;

    local procedure RunAndRespond(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Native Context ori";
        Err: Text;
        Response: JsonObject;
        SheetNo: Code[20];
        IsSubmit: Boolean;
    begin
        IsSubmit := Context.GetOperation() = 1;
        if Argument."Omit Commit" then begin
            Context.Clear();
            if IsSubmit then
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, BatchMsg, '', BatchNextTxt)
            else
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, IsolatedMsg, '', IsolatedNextTxt);
            exit;
        end;

        // A captured Codeunit.Run cannot roll a failure back while a write transaction is
        // already open: the platform stops that transaction and hides the cause. Commit
        // first. The runner then has its own transaction, which commits or rolls back.
        if Database.IsInWriteTransaction() then
            Commit();

        if not Codeunit.Run(Codeunit::"TS Native Runner ori") then begin
            Err := GetLastErrorText();
            SheetNo := Context.GetSheetNo();
            Context.Clear();
            if IsSubmit and not IsCurrentOwner(SheetNo) then
                Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, OwnerSubmitMsg, 'timeSheetNo', OwnerSubmitNextTxt)
            else
                if IsSubmit then
                    Fail(Argument, "Bifrost Error Code ori"::InvalidLine, FixLineMsg, 'lineNos', FixLineNextTxt)
                else
                    Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(Err, 1, 250), '', RetryNextTxt);
            exit;
        end;

        Response.ReadFrom(Context.GetResult());
        Context.Clear();
        Argument.SetResponseJson(Response);
    end;

    local procedure IsCurrentOwner(SheetNo: Code[20]): Boolean
    var
        Header: Record "Time Sheet Header";
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Header.Get(SheetNo) then
            exit(false);
        exit(SameUser(Header."Owner User ID"));
    end;

    local procedure Deny(var Argument: Record "Message Argument ori"; IsReject: Boolean): Boolean
    begin
        if CanMaintainSheets(IsReject) then
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

    local procedure SameUser(Stored: Code[50]): Boolean
    begin
        if Stored = '' then
            exit(false);
        exit(Stored = CopyStr(UserId(), 1, MaxStrLen(Stored)));
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

    local procedure ReadJsonInteger(Token: JsonToken; var IntValue: Integer): Boolean
    var
        DecimalValue: Decimal;
    begin
        if not IsJsonNumber(Token) then
            exit(false);
        if not Evaluate(DecimalValue, Token.AsValue().AsText(), 9) then
            exit(false);
        if (DecimalValue > 2147483647) or (DecimalValue < 1) then
            exit(false);
        if DecimalValue <> Round(DecimalValue, 1) then
            exit(false);
        IntValue := DecimalValue;
        exit(true);
    end;

    /// <summary>True when the caller may insert or modify time sheet header, line and detail.</summary>
    local procedure CanMaintainBulkSheets(): Boolean
    var
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        exit(Header.WritePermission() and Line.WritePermission() and Detail.WritePermission());
    end;

    /// <summary>True when the caller may read time sheet header, line and detail.</summary>
    procedure CanReadSheets(): Boolean
    var
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Detail.ReadPermission());
    end;

    /// <summary>Checks the base records used by bulk reopening.</summary>
    procedure CanReopenSheets(): Boolean
    var
        Resource: Record Resource;
        PostingEntry: Record "Time Sheet Posting Entry";
        UserSetup: Record "User Setup";
    begin
        exit(CanMaintainBulkSheets() and CanReadSheets() and Resource.ReadPermission() and
             UserSetup.ReadPermission() and PostingEntry.ReadPermission());
    end;

    /// <summary>Checks the directly accessed journal records used by bulk posting.</summary>
    procedure CanPostSheets(): Boolean
    var
        Batch: Record "Job Journal Batch";
        JournalLine: Record "Job Journal Line";
        JournalTemplateRecord: Record "Job Journal Template";
    begin
        exit(CanMaintainBulkSheets() and CanReadSheets() and Batch.ReadPermission() and
             JournalTemplateRecord.ReadPermission() and JournalLine.ReadPermission() and JournalLine.WritePermission() and CanPostLedgerRecords());
    end;

    local procedure CanPostLedgerRecords(): Boolean
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        Job: Record Job;
        JobLedgerEntry: Record "Job Ledger Entry";
        JobPlanningLine: Record "Job Planning Line";
        JobRegister: Record "Job Register";
        JobTask: Record "Job Task";
        JobsSetup: Record "Jobs Setup";
        SeriesLine: Record "No. Series Line";
        Resource: Record Resource;
        ResourceLedgerEntry: Record "Res. Ledger Entry";
        ResourceRegister: Record "Resource Register";
        PostingEntry: Record "Time Sheet Posting Entry";
    begin
        exit(GeneralLedgerSetup.ReadPermission() and JobsSetup.ReadPermission() and
             Job.ReadPermission() and Job.WritePermission() and JobTask.ReadPermission() and
             JobLedgerEntry.ReadPermission() and JobLedgerEntry.WritePermission() and
             JobPlanningLine.ReadPermission() and JobPlanningLine.WritePermission() and
             JobRegister.ReadPermission() and JobRegister.WritePermission() and
             SeriesLine.ReadPermission() and SeriesLine.WritePermission() and Resource.ReadPermission() and
             ResourceLedgerEntry.ReadPermission() and ResourceLedgerEntry.WritePermission() and
             ResourceRegister.ReadPermission() and ResourceRegister.WritePermission() and
             PostingEntry.ReadPermission() and PostingEntry.WritePermission());
    end;

    /// <summary>Checks the active and archive records used by bulk archiving.</summary>
    procedure CanArchiveSheets(): Boolean
    var
        CommentLine: Record "Time Sheet Comment Line";
        CommentArchive: Record "Time Sheet Cmt. Line Archive";
        DetailArchive: Record "Time Sheet Detail Archive";
        HeaderArchive: Record "Time Sheet Header Archive";
        LineArchive: Record "Time Sheet Line Archive";
    begin
        exit(CanMaintainBulkSheets() and CanReadSheets() and CommentLine.ReadPermission() and
             CommentLine.WritePermission() and CommentArchive.ReadPermission() and CommentArchive.WritePermission() and
             DetailArchive.ReadPermission() and DetailArchive.WritePermission() and
             HeaderArchive.ReadPermission() and HeaderArchive.WritePermission() and
             LineArchive.ReadPermission() and LineArchive.WritePermission());
    end;

    /// <summary>Clockify.TimeSheet names are not aliases in 28.0.0.0, so this path adds no warning.</summary>
    procedure AddLegacyNameWarning(var ResponseJson: JsonObject)
    begin
        // The old Clockify.TimeSheet names are commented out of the message enum and must not warn or run.
        if ResponseJson.Contains('warnings') then
            exit;
    end;

    /// <summary>Reopens submitted or approved lines under the native name.</summary>
    procedure ExecuteReopen(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Native Context ori";
        Allowed: List of [Text];
        DateToken: JsonToken;
        EndingDateTo: Date;
        RequestJson: JsonObject;
    begin
        if not CanReopenSheets() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        Allowed.Add('endingDateTo');
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        if RequestJson.Get('endingDateTo', DateToken) then
            if not ReadJsonDate(DateToken, EndingDateTo) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'endingDateTo', TypeNextTxt);
                exit;
            end;
        Context.SetReopen(EndingDateTo);
        RunBulkAndRespond(Argument);
    end;

    /// <summary>Posts approved lines under the native name.</summary>
    procedure ExecutePost(var Argument: Record "Message Argument ori")
    var
        Batch: Record "Job Journal Batch";
        JournalTemplateRecord: Record "Job Journal Template";
        Context: Codeunit "TS Native Context ori";
        Allowed: List of [Text];
        BatchToken: JsonToken;
        JournalBatch: Code[10];
        JournalTemplate: Code[10];
        RequestJson: JsonObject;
        TemplateToken: JsonToken;
    begin
        if not CanPostSheets() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        Allowed.Add('journalTemplate');
        Allowed.Add('journalBatch');
        // Foundation validates confirmation before dispatching irreversible operations.
        Allowed.Add('expectedCount');
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        if RequestJson.Get('journalTemplate', TemplateToken) then begin
            if not IsJsonString(TemplateToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'journalTemplate', TypeNextTxt);
                exit;
            end;
            if StrLen(TemplateToken.AsValue().AsText()) > MaxStrLen(JournalTemplate) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, JournalLengthMsg, 'journalTemplate', TypeNextTxt);
                exit;
            end;
            JournalTemplate := CopyStr(TemplateToken.AsValue().AsText(), 1, MaxStrLen(JournalTemplate));
        end;
        if RequestJson.Get('journalBatch', BatchToken) then begin
            if not IsJsonString(BatchToken) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'journalBatch', TypeNextTxt);
                exit;
            end;
            if StrLen(BatchToken.AsValue().AsText()) > MaxStrLen(JournalBatch) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, JournalLengthMsg, 'journalBatch', TypeNextTxt);
                exit;
            end;
            JournalBatch := CopyStr(BatchToken.AsValue().AsText(), 1, MaxStrLen(JournalBatch));
        end;
        if JournalTemplate = '' then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingJournalMsg, 'journalTemplate', MissingKeyNextTxt);
            exit;
        end;
        if JournalBatch = '' then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingJournalMsg, 'journalBatch', MissingKeyNextTxt);
            exit;
        end;
        JournalTemplateRecord.ReadIsolation := IsolationLevel::ReadCommitted;
        Batch.ReadIsolation := IsolationLevel::ReadCommitted;
        if not JournalTemplateRecord.Get(JournalTemplate) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, JournalIdentifierMsg, 'journalTemplate', IdentifierNextTxt);
            exit;
        end;
        if not Batch.Get(JournalTemplate, JournalBatch) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, JournalIdentifierMsg, 'journalBatch', IdentifierNextTxt);
            exit;
        end;
        Context.SetPost(JournalTemplate, JournalBatch);
        RunBulkAndRespond(Argument);
    end;

    /// <summary>Archives posted time sheets under the native name.</summary>
    procedure ExecuteArchive(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Native Context ori";
        Allowed: List of [Text];
        RequestJson: JsonObject;
    begin
        if not CanArchiveSheets() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        Context.SetArchive();
        RunBulkAndRespond(Argument);
    end;

    local procedure RunBulkAndRespond(var Argument: Record "Message Argument ori")
    var
        Context: Codeunit "TS Native Context ori";
        Response: JsonObject;
    begin
        // Keep Omit Commit in the caller's transaction, as the existing native writes do.
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"TS Native Runner ori");
            Response.ReadFrom(Context.GetResult());
            Context.Clear();
            Argument.SetResponseJson(Response);
            exit;
        end;

        if Database.IsInWriteTransaction() then
            Commit();
        if not Codeunit.Run(Codeunit::"TS Native Runner ori") then begin
            Context.Clear();
            // The platform diagnostic may contain internal object and record information.
            // Return a structured refusal instead of exposing the runtime error to callers.
            Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, FixLineMsg, '', RetryNextTxt);
            exit;
        end;
        Response.ReadFrom(Context.GetResult());
        Context.Clear();
        Argument.SetResponseJson(Response);
    end;


    /// <summary>Checks every native read and the line write used by Submit.</summary>
    procedure CanMaintainSheets(): Boolean
    var
        Detail: Record "Time Sheet Detail";
        Job: Record Job;
        AccountingPeriod: Record "Accounting Period";
        Resource: Record Resource;
        ResourcesSetup: Record "Resources Setup";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        exit(Header.ReadPermission() and Line.ReadPermission() and Detail.ReadPermission() and
             Resource.ReadPermission() and ResourcesSetup.ReadPermission() and Job.ReadPermission() and
             AccountingPeriod.ReadPermission() and Line.WritePermission() and Detail.WritePermission());
    end;

    /// <summary>Handles ExecuteSubmit for the Submit message contract.</summary>
    procedure ExecuteSubmit(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Context: Codeunit "TS Native Context ori";
        Allowed: List of [Text];
        DateToken: JsonToken;
        LineFilter: Text;
        LinesToken: JsonToken;
        Numbers: List of [Integer];
        OpenCount: Integer;
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
        Allowed.Add('lineNos');
        if not AllowOnly(Argument, RequestJson, Allowed) then
            exit;
        if not ResolveSubmitSheet(Argument, RequestJson, SheetToken, ResourceToken, DateToken, Header) then
            exit;
        if not SameUser(Header."Owner User ID") then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, OwnerSubmitMsg, 'timeSheetNo', OwnerSubmitNextTxt);
            exit;
        end;
        if not ReadLineSelection(Argument, RequestJson, LinesToken, Numbers, LineFilter) then
            exit;
        if not SubmitSelection(Argument, Header, Numbers, LineFilter, OpenCount) then
            exit;
        if OpenCount = 0 then begin
            RespondExisting(Argument, Header."No.", LineFilter, false);
            exit;
        end;
        Context.SetSubmit(Header."No.", LineFilter);
        RunAndRespond(Argument);
    end;

    local procedure ResolveSubmitSheet(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SheetToken: JsonToken; var ResourceToken: JsonToken; var DateToken: JsonToken; var Header: Record "Time Sheet Header"): Boolean
    var
        HasDate: Boolean;
        HasResource: Boolean;
        HasSheet: Boolean;
        ResourceNo: Code[20];
        SheetDate: Date;
    begin
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        HasSheet := RequestJson.Get('timeSheetNo', SheetToken);
        HasResource := RequestJson.Get('resourceNo', ResourceToken);
        HasDate := RequestJson.Get('date', DateToken);
        if HasSheet and (HasResource or HasDate) then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'timeSheetNo', OneIdentifierNextTxt);
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
        if StrLen(ResourceToken.AsValue().AsText()) > MaxStrLen(ResourceNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'resourceNo', TypeNextTxt);
            exit(false);
        end;
        ResourceNo := CopyStr(ResourceToken.AsValue().AsText(), 1, MaxStrLen(ResourceNo));
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetFilter("Starting Date", '<=%1', SheetDate);
        Header.SetFilter("Ending Date", '>=%1', SheetDate);
        if Header.Count() > 1 then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, OneIdentifierMsg, 'date', OneIdentifierNextTxt);
            exit(false);
        end;
        if not Header.FindFirst() then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(IdentifierMsg, Header.TableCaption()), 'resourceNo', IdentifierNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure SubmitSelection(var Argument: Record "Message Argument ori"; Header: Record "Time Sheet Header"; Numbers: List of [Integer]; var LineFilter: Text; var OpenCount: Integer): Boolean
    var
        Line: Record "Time Sheet Line";
        LineNo: Integer;
    begin
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        OpenCount := 0;
        if LineFilter = '*' then begin
            Line.SetRange("Time Sheet No.", Header."No.");
            if Line.IsEmpty() then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, AddLinesMsg, 'lineNos', AddLinesNextTxt);
                exit(false);
            end;
            Line.SetRange(Status, Line.Status::Open);
            OpenCount := Line.Count();
            // No open line left: list the lines that are already submitted as unchanged.
            if OpenCount = 0 then
                Line.SetRange(Status, Line.Status::Submitted);
            if Line.IsEmpty() then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, AddLinesMsg, 'lineNos', AddLinesNextTxt);
                exit(false);
            end;
            LineFilter := FilterOf(Line);
            exit(true);
        end;
        if Numbers.Count() = 0 then begin
            Line.SetRange("Time Sheet No.", Header."No.");
            Line.SetRange(Status, Line.Status::Open);
            if Line.IsEmpty() then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, AddLinesMsg, 'lineNos', AddLinesNextTxt);
                exit(false);
            end;
            exit(true);
        end;
        foreach LineNo in Numbers do begin
            if not Line.Get(Header."No.", LineNo) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(IdentifierMsg, Line.TableCaption()), 'lineNos', IdentifierNextTxt);
                exit(false);
            end;
            if Line.Status = Line.Status::Open then
                OpenCount += 1
            else
                if Line.Status <> Line.Status::Submitted then begin
                    Fail(Argument, "Bifrost Error Code ori"::InvalidLine, FixLineMsg, 'lineNos', FixLineNextTxt);
                    exit(false);
                end;
        end;
        exit(true);
    end;

    local procedure ReadJsonDate(Token: JsonToken; var DateValue: Date): Boolean
    begin
        if not IsJsonString(Token) then
            exit(false);
        exit(Evaluate(DateValue, Token.AsValue().AsText(), 9));
    end;

    local procedure Deny(var Argument: Record "Message Argument ori"): Boolean
    begin
        if CanMaintainSheets() then
            exit(false);
        Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, AssignSetMsg, '', AssignSetNextTxt);
        exit(true);
    end;
}
