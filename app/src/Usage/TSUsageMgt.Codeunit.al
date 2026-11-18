namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>
/// Request checks, dispatch and reads for the Projects.Usage.* message types. Writes run in
/// "TS Usage Runner ori" so a failure rolls back every change of the request.
/// </summary>
codeunit 70013400 "TS Usage Mgt ori"
{
    Access = Internal;

    var
        MissingKeyMsg: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingKeyNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeMsg: Label 'A key has the wrong JSON type or value.', Comment = 'is-IS=Lykill er af röngu JSON-tagi eða með rangt gildi.';
        TypeNextTxt: Label 'Send the key with the documented type and value.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi og gildi.';
        UnknownKeyMsg: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownKeyNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundMsg: Label 'The key %1 does not match an existing record.', Comment = '%1 = key name; is-IS=Lykillinn %1 passar ekki við færslu sem er til.';
        NotFoundNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        BlockedMsg: Label 'The key %1 names a blocked record.', Comment = '%1 = key name; is-IS=Lykillinn %1 vísar á lokaða færslu.';
        BlockedNextTxt: Label 'Use a record that is not blocked.', Comment = 'is-IS=Notaðu færslu sem er ekki lokuð.';
        WeekMsg: Label 'The key date is outside the week of the time sheet.', Comment = 'is-IS=Lykillinn date er utan viku tímaskýrslunnar.';
        WeekNextTxt: Label 'Use a date between the start and the end of the time sheet.', Comment = 'is-IS=Notaðu dagsetningu milli upphafs og loka tímaskýrslunnar.';
        QuantityMsg: Label 'The key quantity must be greater than zero.', Comment = 'is-IS=Lykillinn quantity verður að vera stærri en núll.';
        QuantityNextTxt: Label 'Send a quantity greater than zero.', Comment = 'is-IS=Sendu magn sem er stærra en núll.';
        OwnerMsg: Label 'The caller is not the owner of the time sheet.', Comment = 'is-IS=Kallandinn er ekki eigandi tímaskýrslunnar.';
        OwnerNextTxt: Label 'Only the owner of the time sheet can do this.', Comment = 'is-IS=Aðeins eigandi tímaskýrslunnar getur gert þetta.';
        ApproverMsg: Label 'The caller is not the approver named on the time sheet, or is its owner.', Comment = 'is-IS=Kallandinn er ekki samþykktaraðilinn sem er nefndur á tímaskýrslunni, eða er eigandi hennar.';
        ApproverNextTxt: Label 'Only the approver named on the time sheet, never its owner, can do this.', Comment = 'is-IS=Aðeins samþykktaraðilinn sem er nefndur á tímaskýrslunni, aldrei eigandinn, getur gert þetta.';
        StateMsg: Label 'The usage line is in a state that does not allow this action.', Comment = 'is-IS=Notkunarlínan er í stöðu sem leyfir ekki þessa aðgerð.';
        StateNextTxt: Label 'Check the state with Projects.Usage.List.', Comment = 'is-IS=Athugaðu stöðuna með Projects.Usage.List.';
        PermissionMsg: Label 'The caller lacks permission for this usage action.', Comment = 'is-IS=Kallandi hefur ekki heimild fyrir þessari notkunaraðgerð.';
        PermissionNextTxt: Label 'Assign the BIFROST Full ori and PROJ USAGE permission sets (BIFROST Read ori and PROJ USAGE for List), or the journal permissions the transfer needs.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunum BIFROST Full ori og PROJ USAGE (BIFROST Read ori og PROJ USAGE fyrir List) eða færslubókarheimildunum sem flutningurinn þarfnast.';
        IsolatedMsg: Label 'This operation requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        IsolatedNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        RetryNextTxt: Label 'Correct the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur. Engu var breytt.';
        TooLongMsg: Label 'The key %1 is longer than allowed.', Comment = '%1 = key name; is-IS=Lykillinn %1 er lengri en leyfilegt er.';

    /// <summary>Checks the permissions the message type needs for discovery. List reads; the others write usage lines.</summary>
    procedure CanUse(Operation: Integer): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
    begin
        if not (Header.ReadPermission() and Line.ReadPermission() and Usage.ReadPermission()) then
            exit(false);
        if Operation = 7 then
            exit(true);
        exit(Usage.WritePermission());
    end;

    /// <summary>Runs one usage message type (1 register, 2 submit, 3 approve, 4 reject, 5 transfer, 6 reverse, 7 list).</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Operation: Integer)
    begin
        if not CanUse(Operation) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
            exit;
        end;
        case Operation of
            1:
                Register(Argument);
            2, 3, 4:
                Decide(Argument, Operation);
            5:
                Transfer(Argument);
            6:
                Reverse(Argument);
            7:
                List(Argument);
        end;
    end;

    local procedure Register(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Item: Record Item;
        Line: Record "Time Sheet Line";
        Resource: Record Resource;
        Params: JsonObject;
        Request: JsonObject;
        Allowed: List of [Text];
        DateText: Text;
        DescriptionText: Text;
        NoText: Text;
        QuantityText: Text;
        SheetNo: Text;
        TypeText: Text;
        UnitText: Text;
        Quantity: Decimal;
        UsageDate: Date;
        LineNo: Integer;
    begin
        Request := Argument.GetRequestJson();
        Allowed.AddRange('timeSheetNo', 'lineNo', 'type', 'no', 'date', 'quantity', 'unitOfMeasure', 'description');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        if not (ReadString(Argument, Request, 'timeSheetNo', true, 20, SheetNo) and
                ReadInteger(Argument, Request, 'lineNo', LineNo) and
                ReadString(Argument, Request, 'type', true, 10, TypeText) and
                ReadString(Argument, Request, 'no', true, 20, NoText) and
                ReadString(Argument, Request, 'date', true, 10, DateText) and
                ReadNumber(Argument, Request, 'quantity', QuantityText) and
                ReadString(Argument, Request, 'unitOfMeasure', false, 10, UnitText) and
                ReadString(Argument, Request, 'description', false, 100, DescriptionText))
        then
            exit;
        if not (TypeText in ['Item', 'Resource']) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'type', TypeNextTxt);
            exit;
        end;
        if not Evaluate(UsageDate, DateText, 9) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'date', TypeNextTxt);
            exit;
        end;
        Evaluate(Quantity, QuantityText, 9);
        if Quantity <= 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, QuantityMsg, 'quantity', QuantityNextTxt);
            exit;
        end;
        Header.SetLoadFields("No.", "Owner User ID", "Resource No.", "Starting Date", "Ending Date", "Approver User ID");
        if not Header.Get(CopyStr(SheetNo, 1, MaxStrLen(Header."No."))) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'timeSheetNo'), 'timeSheetNo', NotFoundNextTxt);
            exit;
        end;
        if not SameUser(Header."Owner User ID") then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, OwnerMsg, 'timeSheetNo', OwnerNextTxt);
            exit;
        end;
        Line.SetLoadFields("Time Sheet No.", "Line No.");
        if not Line.Get(Header."No.", LineNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'lineNo'), 'lineNo', NotFoundNextTxt);
            exit;
        end;
        if (UsageDate < Header."Starting Date") or (UsageDate > Header."Ending Date") then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, WeekMsg, 'date', WeekNextTxt);
            exit;
        end;
        if TypeText = 'Item' then begin
            Item.SetLoadFields("No.", Blocked, "Base Unit of Measure");
            if not Item.Get(CopyStr(NoText, 1, MaxStrLen(Item."No."))) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'no'), 'no', NotFoundNextTxt);
                exit;
            end;
            if Item.Blocked then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(BlockedMsg, 'no'), 'no', BlockedNextTxt);
                exit;
            end;
            if UnitText = '' then
                UnitText := Item."Base Unit of Measure";
        end else begin
            Resource.SetLoadFields("No.", Blocked, "Base Unit of Measure");
            if not Resource.Get(CopyStr(NoText, 1, MaxStrLen(Resource."No."))) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'no'), 'no', NotFoundNextTxt);
                exit;
            end;
            if Resource.Blocked then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(BlockedMsg, 'no'), 'no', BlockedNextTxt);
                exit;
            end;
            if UnitText = '' then
                UnitText := Resource."Base Unit of Measure";
        end;
        Params.Add('timeSheetNo', Header."No.");
        Params.Add('lineNo', LineNo);
        Params.Add('resourceNo', Header."Resource No.");
        Params.Add('type', TypeText);
        Params.Add('no', NoText);
        Params.Add('date', Format(UsageDate, 0, 9));
        Params.Add('quantity', Format(Quantity, 0, 9));
        Params.Add('unitOfMeasure', UnitText);
        Params.Add('description', DescriptionText);
        RunWrite(Argument, 1, Params);
    end;

    local procedure Decide(var Argument: Record "Message Argument ori"; Operation: Integer)
    var
        Header: Record "Time Sheet Header";
        Usage: Record "TS Usage Line ori";
        Allowed: List of [Text];
        EntryNos: List of [Integer];
        Selected: JsonArray;
        Params: JsonObject;
        Request: JsonObject;
        Comment: Text;
        SheetNo: Text;
        EntryNo: Integer;
        HasEntries: Boolean;
    begin
        Request := Argument.GetRequestJson();
        Allowed.AddRange('timeSheetNo', 'entryNos');
        if Operation = 4 then
            Allowed.Add('comment');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        if not ReadString(Argument, Request, 'timeSheetNo', true, 20, SheetNo) then
            exit;
        if not ReadEntryNos(Argument, Request, EntryNos, HasEntries) then
            exit;
        if Operation = 4 then
            if not ReadString(Argument, Request, 'comment', false, 250, Comment) then
                exit;
        if not LoadSheet(Argument, SheetNo, Header) then
            exit;
        if Operation = 2 then begin
            if not SameUser(Header."Owner User ID") then begin
                Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, OwnerMsg, 'timeSheetNo', OwnerNextTxt);
                exit;
            end;
        end else
            if not IsApprover(Header) then begin
                Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, ApproverMsg, 'timeSheetNo', ApproverNextTxt);
                exit;
            end;
        Usage.ReadIsolation := IsolationLevel::ReadCommitted;
        if not HasEntries then begin
            Usage.SetRange("Time Sheet No.", Header."No.");
            if Operation = 2 then
                Usage.SetFilter(Status, '%1|%2', Usage.Status::Open, Usage.Status::Rejected)
            else
                Usage.SetRange(Status, Usage.Status::Submitted);
            if Usage.FindSet() then
                repeat
                    Selected.Add(Usage."Entry No.");
                until Usage.Next() = 0;
        end else
            foreach EntryNo in EntryNos do begin
                if not Usage.Get(EntryNo) or (Usage."Time Sheet No." <> Header."No.") then begin
                    Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'entryNos'), 'entryNos', NotFoundNextTxt);
                    exit;
                end;
                if not CanDecide(Usage, Operation) then begin
                    Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateMsg, 'entryNos', StateNextTxt);
                    exit;
                end;
                Selected.Add(EntryNo);
            end;
        Params.Add('timeSheetNo', Header."No.");
        Params.Add('entryNos', Selected);
        Params.Add('comment', Comment);
        RunWrite(Argument, Operation, Params);
    end;

    /// <summary>Revalidates a decision against the locked sheet and current usage state inside the write transaction.</summary>
    internal procedure ValidateDecision(Usage: Record "TS Usage Line ori"; Operation: Integer; SheetNo: Code[20])
    var
        Header: Record "Time Sheet Header";
    begin
        Usage.TestField("Time Sheet No.", SheetNo);
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(SheetNo);
        if Operation = 2 then begin
            if not SameUser(Header."Owner User ID") then
                Error(OwnerMsg);
        end else
            if not IsApprover(Header) then
                Error(ApproverMsg);
        if not CanDecide(Usage, Operation) then
            Error(StateMsg);
    end;

    local procedure CanDecide(Usage: Record "TS Usage Line ori"; Operation: Integer): Boolean
    begin
        if Operation = 2 then
            exit(Usage.Status in [Usage.Status::Open, Usage.Status::Rejected]);
        exit(Usage.Status = Usage.Status::Submitted);
    end;

    local procedure Transfer(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Usage: Record "TS Usage Line ori";
        Allowed: List of [Text];
        EntryNos: List of [Integer];
        Selected: JsonArray;
        Params: JsonObject;
        Request: JsonObject;
        Ignored: Text;
        KeyName: Text;
        SheetNo: Text;
        EntryNo: Integer;
        HasEntries: Boolean;
        HasSheet: Boolean;
        Skipped: Boolean;
    begin
        Request := Argument.GetRequestJson();
        Allowed.AddRange('timeSheetNo', 'entryNos', 'itemTemplate', 'itemBatch', 'resourceTemplate', 'resourceBatch', 'jobTemplate', 'jobBatch');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        HasSheet := Request.Contains('timeSheetNo');
        if HasSheet then
            if not ReadString(Argument, Request, 'timeSheetNo', true, 20, SheetNo) then
                exit;
        if not ReadEntryNos(Argument, Request, EntryNos, HasEntries) then
            exit;
        foreach KeyName in Request.Keys() do
            if KeyName.EndsWith('Template') or KeyName.EndsWith('Batch') then
                if not ReadString(Argument, Request, KeyName, true, 10, Ignored) then
                    exit;
        Usage.ReadIsolation := IsolationLevel::ReadCommitted;
        if HasSheet then begin
            if not LoadSheet(Argument, SheetNo, Header) then
                exit;
            Usage.SetRange("Time Sheet No.", Header."No.");
        end;
        if HasEntries then
            foreach EntryNo in EntryNos do begin
                if not Usage.Get(EntryNo) then begin
                    Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'entryNos'), 'entryNos', NotFoundNextTxt);
                    exit;
                end;
                if HasSheet and (Usage."Time Sheet No." <> Header."No.") then begin
                    Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'entryNos'), 'entryNos', NotFoundNextTxt);
                    exit;
                end;
                if Usage.Status in [Usage.Status::Transferred, Usage.Status::Posted] then
                    continue;
                if Usage.Status <> Usage.Status::Approved then begin
                    Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateMsg, 'entryNos', StateNextTxt);
                    exit;
                end;
                if not CheckTransferLine(Argument, Request, Usage, true, Skipped) then
                    exit;
                Selected.Add(EntryNo);
            end
        else begin
            Usage.SetRange(Status, Usage.Status::Approved);
            if Usage.FindSet() then
                repeat
                    if not CheckTransferLine(Argument, Request, Usage, false, Skipped) then
                        exit;
                    if not Skipped then
                        Selected.Add(Usage."Entry No.");
                until Usage.Next() = 0;
        end;
        Params := Request;
        if Params.Contains('entryNos') then
            Params.Replace('entryNos', Selected)
        else
            Params.Add('entryNos', Selected);
        RunWrite(Argument, 5, Params);
    end;

    // Explicit lines must pass or the request fails. Selected-by-filter lines the caller does not approve are skipped.
    local procedure CheckTransferLine(var Argument: Record "Message Argument ori"; Request: JsonObject; Usage: Record "TS Usage Line ori"; Explicit: Boolean; var Skipped: Boolean): Boolean
    var
        Header: Record "Time Sheet Header";
    begin
        Skipped := false;
        Header.SetLoadFields("No.", "Owner User ID", "Approver User ID");
        Header.Get(Usage."Time Sheet No.");
        if not IsApprover(Header) then begin
            if Explicit then begin
                Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, ApproverMsg, 'entryNos', ApproverNextTxt);
                exit(false);
            end;
            Skipped := true;
            exit(true);
        end;
        exit(CheckJournalTarget(Argument, Request, Usage));
    end;

    local procedure CheckJournalTarget(var Argument: Record "Message Argument ori"; Request: JsonObject; Usage: Record "TS Usage Line ori"): Boolean
    var
        ItemTemplate: Record "Item Journal Template";
        ItemBatch: Record "Item Journal Batch";
        JobTemplate: Record "Job Journal Template";
        JobBatch: Record "Job Journal Batch";
        ResTemplate: Record "Res. Journal Template";
        ResBatch: Record "Res. Journal Batch";
        Journal: Codeunit "TS Usage Journal ori";
        Token: JsonToken;
        BatchKey: Text;
        TemplateKey: Text;
        TemplateName: Code[10];
        BatchName: Code[10];
        Found: Boolean;
    begin
        TargetKeys(Usage, TemplateKey, BatchKey);
        if not Request.Get(TemplateKey, Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, TemplateKey, MissingKeyNextTxt);
            exit(false);
        end;
        TemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TemplateName));
        if not Request.Get(BatchKey, Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, BatchKey, MissingKeyNextTxt);
            exit(false);
        end;
        BatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(BatchName));
        if Journal.GoesToJobJournal(Usage) then begin
            JobTemplate.SetLoadFields(Name);
            JobBatch.SetLoadFields(Name);
            Found := JobTemplate.Get(TemplateName) and JobBatch.Get(TemplateName, BatchName);
            if not (CanWriteJobJournal() and JobTemplate.ReadPermission() and JobBatch.ReadPermission()) then
                exit(DenyJournal(Argument));
        end else
            if Usage.Type = Usage.Type::Item then begin
                ItemTemplate.SetLoadFields(Name);
                ItemBatch.SetLoadFields(Name);
                Found := ItemTemplate.Get(TemplateName) and ItemBatch.Get(TemplateName, BatchName);
                if not CanWriteItemJournal() then
                    exit(DenyJournal(Argument));
            end else begin
                ResTemplate.SetLoadFields(Name);
                ResBatch.SetLoadFields(Name);
                Found := ResTemplate.Get(TemplateName) and ResBatch.Get(TemplateName, BatchName);
                if not CanWriteResourceJournal() then
                    exit(DenyJournal(Argument));
            end;
        if not Found then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, TemplateKey), TemplateKey, NotFoundNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure CanWriteJobJournal(): Boolean
    var
        Line: Record "Job Journal Line";
    begin
        exit(Line.WritePermission());
    end;

    local procedure CanWriteItemJournal(): Boolean
    var
        Line: Record "Item Journal Line";
    begin
        exit(Line.WritePermission());
    end;

    local procedure CanWriteResourceJournal(): Boolean
    var
        Line: Record "Res. Journal Line";
    begin
        exit(Line.WritePermission());
    end;

    local procedure DenyJournal(var Argument: Record "Message Argument ori"): Boolean
    begin
        Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionMsg, '', PermissionNextTxt);
        exit(false);
    end;

    local procedure TargetKeys(Usage: Record "TS Usage Line ori"; var TemplateKey: Text; var BatchKey: Text)
    var
        Journal: Codeunit "TS Usage Journal ori";
    begin
        if Journal.GoesToJobJournal(Usage) then begin
            TemplateKey := 'jobTemplate';
            BatchKey := 'jobBatch';
        end else
            if Usage.Type = Usage.Type::Item then begin
                TemplateKey := 'itemTemplate';
                BatchKey := 'itemBatch';
            end else begin
                TemplateKey := 'resourceTemplate';
                BatchKey := 'resourceBatch';
            end;
    end;

    /// <summary>Reads the journal template and batch the request names for this usage line. False when a key is missing.</summary>
    procedure JournalTarget(Params: JsonObject; Usage: Record "TS Usage Line ori"; var Template: Code[10]; var Batch: Code[10]): Boolean
    var
        BatchKey: Text;
        TemplateKey: Text;
    begin
        TargetKeys(Usage, TemplateKey, BatchKey);
        Template := CopyStr(GetText(Params, TemplateKey), 1, MaxStrLen(Template));
        Batch := CopyStr(GetText(Params, BatchKey), 1, MaxStrLen(Batch));
        if (Template = '') or (Batch = '') then
            Error(MissingKeyMsg);
        exit(true);
    end;

    local procedure Reverse(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Usage: Record "TS Usage Line ori";
        Allowed: List of [Text];
        Request: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
    begin
        Request := Argument.GetRequestJson();
        Allowed.AddRange('entryNo', 'createJournalLine', 'itemTemplate', 'itemBatch', 'resourceTemplate', 'resourceBatch', 'jobTemplate', 'jobBatch');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        if not ReadInteger(Argument, Request, 'entryNo', EntryNo) then
            exit;
        if Request.Get('createJournalLine', Token) then
            if not (Token.IsValue() and (Format(Token.AsValue().AsText()) in ['true', 'false', 'True', 'False'])) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'createJournalLine', TypeNextTxt);
                exit;
            end;
        Usage.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Usage.Get(EntryNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'entryNo'), 'entryNo', NotFoundNextTxt);
            exit;
        end;
        Header.SetLoadFields("No.", "Owner User ID", "Approver User ID");
        Header.Get(Usage."Time Sheet No.");
        if not IsApprover(Header) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, ApproverMsg, 'entryNo', ApproverNextTxt);
            exit;
        end;
        if (Usage.Status <> Usage.Status::Posted) or Usage.Reversed then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateMsg, 'entryNo', StateNextTxt);
            exit;
        end;
        if Request.Get('createJournalLine', Token) then
            if Token.AsValue().AsBoolean() then
                if not CheckJournalTarget(Argument, Request, Usage) then
                    exit;
        RunWrite(Argument, 6, Request);
    end;

    local procedure List(var Argument: Record "Message Argument ori")
    var
        Header: Record "Time Sheet Header";
        Usage: Record "TS Usage Line ori";
        Allowed: List of [Text];
        Lines: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        StatusText: Text;
        SheetNo: Text;
        Skip: Integer;
        Take: Integer;
        Seen: Integer;
        Pending: Boolean;
        StatusFilter: Integer;
        HasStatus: Boolean;
        HasMore: Boolean;
        Token: JsonToken;
        Include: Boolean;
    begin
        Request := Argument.GetRequestJson();
        Allowed.AddRange('timeSheetNo', 'status', 'pending', 'skip', 'take');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        Take := 50;
        if Request.Contains('timeSheetNo') then
            if not ReadString(Argument, Request, 'timeSheetNo', true, 20, SheetNo) then
                exit;
        if Request.Contains('status') then begin
            if not ReadString(Argument, Request, 'status', true, 20, StatusText) then
                exit;
            if not StatusFromName(StatusText, StatusFilter) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'status', TypeNextTxt);
                exit;
            end;
            HasStatus := true;
        end;
        if Request.Get('pending', Token) then
            Pending := Token.IsValue() and (Token.AsValue().AsText() in ['true', 'True']);
        if Request.Contains('skip') then
            if not ReadInteger(Argument, Request, 'skip', Skip) then
                exit;
        if Request.Contains('take') then
            if not ReadInteger(Argument, Request, 'take', Take) then
                exit;
        if (Take < 1) or (Take > 200) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'take', TypeNextTxt);
            exit;
        end;
        Usage.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        Header.SetLoadFields("No.", "Owner User ID", "Approver User ID");
        if SheetNo <> '' then
            Usage.SetRange("Time Sheet No.", CopyStr(SheetNo, 1, MaxStrLen(Usage."Time Sheet No.")));
        if HasStatus then
            Usage.SetRange(Status, StatusFromOrdinal(StatusFilter));
        if Pending then
            Usage.SetRange(Status, Usage.Status::Submitted);
        if Usage.FindSet() then
            repeat
                Include := false;
                if Header.Get(Usage."Time Sheet No.") then
                    if Pending then
                        Include := IsApprover(Header)
                    else
                        Include := SameUser(Header."Owner User ID") or (IsApprover(Header) and (Usage.Status <> Usage.Status::Open));
                if Include then begin
                    Seen += 1;
                    if Seen > Skip then
                        if Lines.Count() < Take then
                            Lines.Add(LineNode(Usage, false))
                        else
                            HasMore := true;
                end;
            until (Usage.Next() = 0) or HasMore;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Response.Add('hasMore', HasMore);
        Argument.SetResponseJson(Response);
    end;

    local procedure StatusFromName(StatusName: Text; var Ordinal: Integer): Boolean
    var
        Usage: Record "TS Usage Line ori";
        Index: Integer;
    begin
        Index := Usage.Status.Names().IndexOf(StatusName);
        if Index = 0 then
            exit(false);
        Ordinal := Usage.Status.Ordinals().Get(Index);
        exit(true);
    end;

    local procedure StatusFromOrdinal(Ordinal: Integer): Enum "TS Usage Status ori"
    begin
        exit(Enum::"TS Usage Status ori".FromInteger(Ordinal));
    end;

    local procedure RunWrite(var Argument: Record "Message Argument ori"; Operation: Integer; Params: JsonObject)
    var
        Context: Codeunit "TS Usage Context ori";
        Response: JsonObject;
        Err: Text;
    begin
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, IsolatedMsg, '', IsolatedNextTxt);
            exit;
        end;
        Context.SetOperation(Operation, Params);
        // A captured Codeunit.Run cannot roll back while a write transaction is open: commit first.
        if Database.IsInWriteTransaction() then
            Commit();
        if not Codeunit.Run(Codeunit::"TS Usage Runner ori") then begin
            Err := GetLastErrorText();
            Context.Clear();
            Fail(Argument, "Bifrost Error Code ori"::BusinessCentralError, CopyStr(Err, 1, 250), '', RetryNextTxt);
            exit;
        end;
        Response.ReadFrom(Context.GetResult());
        Context.Clear();
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Builds the JSON node of one usage line for a response.</summary>
    procedure LineNode(Usage: Record "TS Usage Line ori"; Changed: Boolean) Node: JsonObject
    begin
        Node.Add('entryNo', Usage."Entry No.");
        Node.Add('timeSheetNo', Usage."Time Sheet No.");
        Node.Add('lineNo', Usage."Time Sheet Line No.");
        Node.Add('type', Usage.Type.Names().Get(Usage.Type.Ordinals().IndexOf(Usage.Type.AsInteger())));
        Node.Add('no', Usage."No.");
        Node.Add('date', Format(Usage.Date, 0, 9));
        Node.Add('quantity', Usage.Quantity);
        Node.Add('unitOfMeasure', Usage."Unit of Measure Code");
        Node.Add('status', Usage.Status.Names().Get(Usage.Status.Ordinals().IndexOf(Usage.Status.AsInteger())));
        Node.Add('reversed', Usage.Reversed);
        Node.Add('journalTemplate', Usage."Journal Template Name");
        Node.Add('journalBatch', Usage."Journal Batch Name");
        Node.Add('journalLineNo', Usage."Journal Line No.");
        Node.Add('ledgerEntryNo', Usage."Ledger Entry No.");
        Node.Add('changed', Changed);
    end;

    /// <summary>Returns the JSON text of an object.</summary>
    procedure JsonText(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
    end;

    /// <summary>Returns a value of a JSON object as text, or an empty text.</summary>
    procedure GetText(Params: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Params.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    /// <summary>Returns a value of a JSON object as integer, or zero.</summary>
    procedure GetInt(Params: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if Params.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Builds a document number such as TSU000123 from a prefix and an entry number.</summary>
    procedure DocumentNo(Prefix: Text; EntryNo: Integer): Code[20]
    begin
        exit(CopyStr(Prefix + Format(EntryNo, 0, '<Integer,9><Filler Character,0>'), 1, 20));
    end;

    local procedure LoadSheet(var Argument: Record "Message Argument ori"; SheetNo: Text; var Header: Record "Time Sheet Header"): Boolean
    begin
        Header.SetLoadFields("No.", "Owner User ID", "Approver User ID", "Resource No.", "Starting Date", "Ending Date");
        if Header.Get(CopyStr(SheetNo, 1, MaxStrLen(Header."No."))) then
            exit(true);
        Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundMsg, 'timeSheetNo'), 'timeSheetNo', NotFoundNextTxt);
        exit(false);
    end;

    local procedure IsApprover(Header: Record "Time Sheet Header"): Boolean
    begin
        if Header."Approver User ID" = '' then
            exit(false);
        exit(SameUser(Header."Approver User ID") and not SameUser(Header."Owner User ID"));
    end;

    local procedure SameUser(Stored: Code[50]): Boolean
    begin
        if Stored = '' then
            exit(false);
        exit(UpperCase(Stored) = UpperCase(CopyStr(UserId(), 1, MaxStrLen(Stored))));
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, Parameter, '', '', NextStep);
    end;

    local procedure AllowOnly(var Argument: Record "Message Argument ori"; Request: JsonObject; Allowed: List of [Text]): Boolean
    var
        KeyName: Text;
    begin
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownKeyMsg, KeyName, UnknownKeyNextTxt);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadString(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Required: Boolean; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not Request.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, KeyName, MissingKeyNextTxt);
            exit(false);
        end;
        if not Token.IsValue() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, KeyName, TypeNextTxt);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if CopyStr(DelChr(Raw, '<>', ' '), 1, 1) <> '"' then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, KeyName, TypeNextTxt);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if (Required and (Value = '')) or (StrLen(Value) > MaxLength) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongMsg, KeyName), KeyName, TypeNextTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadNumber(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Number: Decimal;
        Raw: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingKeyMsg, KeyName, MissingKeyNextTxt);
            exit(false);
        end;
        if Token.IsValue() then begin
            Token.WriteTo(Raw);
            Raw := DelChr(Raw, '<>', ' ');
            if (CopyStr(Raw, 1, 1) <> '"') and Evaluate(Number, Raw, 9) then begin
                Value := Raw;
                exit(true);
            end;
        end;
        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, KeyName, TypeNextTxt);
        exit(false);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Value: Integer): Boolean
    var
        Text: Text;
        Number: Decimal;
    begin
        if not ReadNumber(Argument, Request, KeyName, Text) then
            exit(false);
        Evaluate(Number, Text, 9);
        if (Number < 0) or (Number <> Round(Number, 1)) or (Number > 2147483647) or ((Number = 0) and (KeyName <> 'skip')) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, KeyName, TypeNextTxt);
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure ReadEntryNos(var Argument: Record "Message Argument ori"; Request: JsonObject; var EntryNos: List of [Integer]; var Present: Boolean): Boolean
    var
        Entry: JsonToken;
        Token: JsonToken;
        Index: Integer;
        Number: Decimal;
        Raw: Text;
    begin
        Present := Request.Get('entryNos', Token);
        if not Present then
            exit(true);
        if not Token.IsArray() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'entryNos', TypeNextTxt);
            exit(false);
        end;
        for Index := 0 to Token.AsArray().Count() - 1 do begin
            Token.AsArray().Get(Index, Entry);
            Raw := '';
            if Entry.IsValue() then
                Entry.WriteTo(Raw);
            if (CopyStr(Raw, 1, 1) = '"') or (Raw = '') or not Evaluate(Number, Raw, 9) or (Number < 1) or (Number <> Round(Number, 1)) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeMsg, 'entryNos', TypeNextTxt);
                exit(false);
            end;
            if not EntryNos.Contains(Number) then
                EntryNos.Add(Number);
        end;
        exit(true);
    end;
}
