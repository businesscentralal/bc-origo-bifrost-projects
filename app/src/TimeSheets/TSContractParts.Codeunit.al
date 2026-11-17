namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Localized contracts for issue 63 manager decisions.</summary>
codeunit 70013556 "TS Contract Parts ori"
{
    Access = Internal;

    var
        SubmitSheetTxt: Label 'Time sheet number. Send this or resourceNo plus date.', Comment = 'is-IS=Númer tímaskýrslu. Sendu þetta eða resourceNo ásamt date.';
        SubmitResourceTxt: Label 'Resource number, together with date, when timeSheetNo is omitted.', Comment = 'is-IS=Númer auðlindar ásamt date þegar timeSheetNo er sleppt.';
        SubmitDateTxt: Label 'ISO date inside the time sheet, together with resourceNo.', Comment = 'is-IS=ISO-dagsetning innan tímaskýrslunnar ásamt resourceNo.';
        SubmitLinesTxt: Label 'Optional line numbers. Omit for all open lines. An empty array selects none.', Comment = 'is-IS=Valfrjáls línunúmer. Sleppt til að velja allar opnar línur. Tómt fylki velur engar.';
        SubmitSuccessTxt: Label 'Success.', Comment = 'is-IS=Tókst.';
        SubmitResponseTxt: Label 'Lines with timeSheetNo, lineNo, status and changed. Submitted lines return changed false. Empty lines follow the Business Central submission policy.', Comment = 'is-IS=Línur með timeSheetNo, lineNo, status og changed. Innsendar línur skila changed false. Tómar línur fylgja innsendingarstefnu Business Central.';
        SubmitMissingTxt: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        SubmitMissingNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        SubmitTypeTxt: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        SubmitTypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        SubmitUnknownTxt: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        SubmitUnknownNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        SubmitNotFoundTxt: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        SubmitNotFoundNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        SubmitConflictTxt: Label 'The request names the time sheet in more than one way.', Comment = 'is-IS=Beiðnin nefnir tímaskýrsluna á fleiri en einn hátt.';
        SubmitConflictNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        SubmitPermissionTxt: Label 'The caller cannot write time sheets.', Comment = 'is-IS=Kallandinn getur ekki skrifað tímaskýrslur.';
        SubmitPermissionNextTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        SubmitOwnerTxt: Label 'The caller is not the owner of the time sheet.', Comment = 'is-IS=Kallandinn er ekki eigandi tímaskýrslunnar.';
        SubmitOwnerNextTxt: Label 'Only the owner can submit; ask the owner.', Comment = 'is-IS=Aðeins eigandinn getur sent inn. Biddu eigandann.';
        SubmitEmptyTxt: Label 'The time sheet has no open lines.', Comment = 'is-IS=Tímaskýrslan hefur engar opnar línur.';
        SubmitEmptyNextTxt: Label 'Add lines first.', Comment = 'is-IS=Bættu við línum fyrst.';
        SubmitLineTxt: Label 'Business Central rejected the line.', Comment = 'is-IS=Business Central hafnaði línunni.';
        SubmitLineNextTxt: Label 'Fix the line and submit again.', Comment = 'is-IS=Lagfærðu línuna og sendu aftur inn.';
        SubmitEffectTxt: Label 'Submits selected open lines. Each successful call commits. If any line fails, all changes from this call roll back.', Comment = 'is-IS=Sendir valdar opnar línur inn. Hvert heppnað kall staðfestir breytingar. Ef einhver lína bregst eru allar breytingar kallsins afturkallaðar.';
        SubmitOverviewTxt: Label 'Projects.TimeSheet.Submit lets the time sheet owner submit open lines for approval.', Comment = 'is-IS=Projects.TimeSheet.Submit gerir eiganda tímaskýrslu kleift að senda opnar línur til samþykktar.';
        SubmitNotesTxt: Label 'Owner only. Parameters: timeSheetNo, or resourceNo and date; optional lineNos. MissingParameter: Send the missing key. InvalidParameterFormat: Send the key with the documented type. UnknownParameter: Remove the unknown key. RecordNotFound: Use an identifier that exists. ConflictingIdentifiers: Send only one identifier for the time sheet. PermissionDenied: Only the owner can submit; ask the owner. PermissionDenied for missing access: Assign the BIFROST Full ori permission set. PreconditionFailed: Add lines first. InvalidLine: Fix the line and submit again. PreconditionFailed in an uncommitted batch: Submit outside an uncommitted batch. Submitted lines return changed false. Empty lines follow the Business Central submission policy. A successful call commits; a failed submission rolls back every selected line.', Comment = 'is-IS=Aðeins eigandinn getur sent inn. Færibreytur: timeSheetNo eða resourceNo og date; valfrjáls lineNos. MissingParameter: Sendu lykilinn sem vantar. InvalidParameterFormat: Sendu lykilinn með skráðu tagi. UnknownParameter: Fjarlægðu óþekkta lykilinn. RecordNotFound: Notaðu auðkenni sem er til. ConflictingIdentifiers: Sendu aðeins eitt auðkenni fyrir tímaskýrsluna. PermissionDenied: Aðeins eigandinn getur sent inn. Biddu eigandann. PermissionDenied vegna aðgangs: Úthlutaðu heimildasamstæðunni BIFROST Full ori. PreconditionFailed: Bættu við línum fyrst. InvalidLine: Lagfærðu línuna og sendu aftur inn. PreconditionFailed í óstaðfestri lotu: Sendu inn utan óstaðfestrar lotu. Innsendar línur skila changed false. Tómar línur fylgja innsendingarstefnu Business Central. Heppnað kall staðfestir breytingar; misheppnuð innsending afturkallar allar valdar línur.';
        SheetTxt: Label 'Time sheet number. Send exactly one of timeSheetNo and timeSheetId.', Comment = 'is-IS=Númer tímaskýrslu. Sendu nákvæmlega annað hvort timeSheetNo eða timeSheetId.';
        IdTxt: Label 'Time sheet SystemId as a GUID; alternative to timeSheetNo.', Comment = 'is-IS=SystemId tímaskýrslu sem GUID; valkostur við timeSheetNo.';
        LinesTxt: Label 'Positive integer line numbers. Omitted selects all submitted lines; an empty array selects none.', Comment = 'is-IS=Jákvæðar heiltölur línunúmera. Sé sleppt eru allar innsendar línur valdar; tómt fylki velur engar.';
        CommentTxt: Label 'Optional rejection comment, at most 80 characters, stored on every rejected line.', Comment = 'is-IS=Valfrjáls höfnunarathugasemd, að hámarki 80 stafir, vistuð á hverri hafnaðri línu.';
        EnvelopeTxt: Label 'Identify the time sheet in data.', Comment = 'is-IS=Auðkenndu tímaskýrsluna í data.';
        StatusTxt: Label 'Success or Error.', Comment = 'is-IS=Success eða Error.';
        ResponseTxt: Label 'Selected lines: timeSheetNo, lineNo, status (Approved or Rejected), changed. Already approved selected lines return changed false for approval.', Comment = 'is-IS=Valdar línur: timeSheetNo, lineNo, status (Approved eða Rejected), changed. Þegar samþykktar valdar línur skila changed false við samþykki.';
        PermissionTxt: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        ApproverTxt: Label 'Only the approver named on the time sheet can approve.', Comment = 'is-IS=Aðeins samþykktaraðilinn sem er nefndur á tímaskýrslunni getur samþykkt.';
        SubmitTxt: Label 'Submit it first with Projects.TimeSheet.Submit.', Comment = 'is-IS=Sendu hana fyrst inn með Projects.TimeSheet.Submit.';
        MissingTxt: Label 'A required identifier is missing.', Comment = 'is-IS=Nauðsynlegt auðkenni vantar.';
        MissingNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        FormatTxt: Label 'A key has an invalid type, length or value.', Comment = 'is-IS=Lykill er af röngu tagi, lengd eða gildi.';
        FormatNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownTxt: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundTxt: Label 'The time sheet or selected line does not exist.', Comment = 'is-IS=Tímaskýrslan eða valin lína er ekki til.';
        NotFoundNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictTxt: Label 'Both timeSheetNo and timeSheetId were supplied.', Comment = 'is-IS=Bæði timeSheetNo og timeSheetId voru send.';
        ConflictNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        PermissionErrorTxt: Label 'The caller lacks access to a table used by this action.', Comment = 'is-IS=Kallandinn hefur ekki aðgang að töflu sem aðgerðin notar.';
        ApproverErrorTxt: Label 'The caller is not the named approver.', Comment = 'is-IS=Kallandinn er ekki tilgreindur samþykktaraðili.';
        InvalidLineTxt: Label 'The selected line is not Submitted. Approval alone accepts an already Approved line as unchanged.', Comment = 'is-IS=Valin lína er ekki innsend. Aðeins samþykki tekur við þegar samþykktri línu án breytinga.';
        RuntimeTxt: Label 'Business Central refused the action; all selected changes were rolled back.', Comment = 'is-IS=Business Central hafnaði aðgerðinni; allar valdar breytingar voru afturkallaðar.';
        RuntimeNextTxt: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';
        IsolatedTxt: Label 'This action requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        IsolatedNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        EffectTxt: Label 'Approves or rejects selected submitted lines atomically through the native time sheet action. A successful call commits; a failed action rolls back all selected changes. Approving absence lines also posts their absence entries.', Comment = 'is-IS=Samþykkir eða hafnar völdum innsendum línum í einni færslu með innbyggðri tímaskýrsluaðgerð. Heppnað kall staðfestir; misheppnuð aðgerð afturkallar allar valdar breytingar. Samþykki fjarvistarlína bókar einnig fjarvistarfærslur.';
        OverviewTxt: Label 'Manager approval and rejection of submitted time sheet lines. Only the sheet approver may act. Unknown keys are refused.', Comment = 'is-IS=Samþykki stjórnanda og höfnun innsendra tímaskýrslulína. Aðeins samþykktaraðili skýrslunnar má framkvæma aðgerðina. Óþekktum lyklum er hafnað.';
        NotesTxt: Label 'Omitted lineNos selects only submitted lines. Empty lineNos returns an empty list. Approval of an explicitly selected approved line returns changed false. Rejection requires Submitted for every selected line. Status is returned in a language-independent form. A successful action commits.', Comment = 'is-IS=Sé lineNos sleppt eru aðeins innsendar línur valdar. Tómt lineNos skilar tómum lista. Samþykki sérstaklega valinnar samþykktrar línu skilar changed false. Höfnun krefst þess að allar valdar línur séu innsendar. Staða er skilað óháð tungumáli. Heppnuð aðgerð staðfestir.';
        WorkflowTxt: Label 'Submit the lines, then let the sheet approver approve or reject them. Read the returned status and changed flag.', Comment = 'is-IS=Sendu línurnar inn, láttu síðan samþykktaraðila skýrslunnar samþykkja eða hafna þeim. Lestu stöðuna og changed merkið í svarinu.';
        RelatedTxt: Label 'Discover the available time sheet operations.', Comment = 'is-IS=Finndu tiltækar tímaskýrsluaðgerðir.';
        CutoffHelpLbl: Label 'ISO date cutoff. Sheets ending after this date are left out. Defaults to the work date.', Comment = 'is-IS=Lokadagur á ISO-sniði. Tímaskýrslum sem lýkur eftir þann dag er sleppt. Sjálfgefið er vinnudagsetningin.';
        JournalTemplateHelpLbl: Label 'Project journal template (maximum 10 characters). Required.', Comment = 'is-IS=Sniðmát verkbókar (mest 10 stafir). Nauðsynlegt.';
        JournalBatchHelpLbl: Label 'Project journal batch (maximum 10 characters). Required.', Comment = 'is-IS=Keyrsla verkbókar (mest 10 stafir). Nauðsynlegt.';
        BulkSubjectLbl: Label 'The Business Central time sheet operation addressed by the request.', Comment = 'is-IS=Aðgerð tímaskýrslu í Business Central sem beiðnin á við.';
        ReopenedCountLbl: Label 'Lines reopened.', Comment = 'is-IS=Línur sem voru opnaðar aftur.';
        PostedCountLbl: Label 'Project journal lines posted.', Comment = 'is-IS=Línur verkbókar sem voru bókaðar.';
        ArchivedCountLbl: Label 'Time sheets archived.', Comment = 'is-IS=Tímaskýrslur sem voru settar í geymslu.';
        MissingHelpLbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        FormatHelpLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        FormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownHelpLbl: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundHelpLbl: Label 'The journal identifier does not match a record.', Comment = 'is-IS=Auðkenni verkbókar passar ekki við færslu.';
        NotFoundNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictHelpLbl: Label 'The request names a record in more than one way.', Comment = 'is-IS=Beiðnin nefnir færslu á fleiri en einn hátt.';
        ConflictNextLbl: Label 'Send only one identifier.', Comment = 'is-IS=Sendu aðeins eitt auðkenni.';
        PermissionHelpLbl: Label 'The caller cannot write the required time sheet or journal records.', Comment = 'is-IS=Kallandinn getur ekki skrifað nauðsynlegar tímaskýrslu- eða verkbókarfærslur.';
        PermissionNextLbl: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        RuntimeHelpLbl: Label 'Business Central rejected the operation.', Comment = 'is-IS=Business Central hafnaði aðgerðinni.';
        RetryHelpLbl: Label 'Review the time sheet and journal setup, then retry the call.', Comment = 'is-IS=Farðu yfir tímaskýrsluna og uppsetningu verkbókar og reyndu kallið aftur.';
        // LegacyHelpLbl and LegacyNextLbl described the retired Clockify.TimeSheet alias. 28.0.0.0 does not keep that alias.
        BulkPreconditionLbl: Label 'The caller has the BIFROST Full ori permission set.', Comment = 'is-IS=Kallandinn hefur heimildasamstæðuna BIFROST Full ori.';
        BulkChangesLbl: Label 'Changes eligible Business Central time sheets. A refused operation rolls back its own writes.', Comment = 'is-IS=Breytir gjaldgengum tímaskýrslum í Business Central. Ef aðgerð er hafnað eru eigin skrif hennar afturkölluð.';
        PostChangesLbl: Label 'Posts approved time sheet lines through the project journal and commits. Posted entries cannot be undone.', Comment = 'is-IS=Bókar samþykktar tímaskýrslulínur í gegnum verkbók og staðfestir færslurnar. Ekki er hægt að afturkalla bókaðar færslur.';
        BulkRelatedLbl: Label 'Discover the native names alongside the other message types.', Comment = 'is-IS=Finndu innlendu heitin ásamt öðrum skilaboðategundum.';
        BulkStepLbl: Label 'Run the time sheet operation.', Comment = 'is-IS=Keyrðu tímaskýrsluaðgerðina.';
        BulkWorkflowLbl: Label 'Review the returned count before the next call. The operation applies to every eligible time sheet.', Comment = 'is-IS=Farðu yfir fjöldann í svarinu áður en næsta kall er sent. Aðgerðin nær til allra gjaldgengra tímaskýrslna.';
        ReopenOverviewLbl: Label 'Reopens submitted or approved time sheet lines up to a cutoff date. Unknown keys are refused.', Comment = 'is-IS=Opnar aftur innsendar eða samþykktar tímaskýrslulínur til lokadags. Óþekktum lyklum er hafnað.';
        PostOverviewLbl: Label 'Posts approved time sheet lines and commits. This operation is irreversible. Unknown keys are refused.', Comment = 'is-IS=Bókar samþykktar tímaskýrslulínur og staðfestir færslurnar. Aðgerðin er óafturkræf. Óþekktum lyklum er hafnað.';
        ArchiveOverviewLbl: Label 'Archives fully posted time sheets and removes empty eligible sheets. The request has no parameters.', Comment = 'is-IS=Setur fullbókaðar tímaskýrslur í geymslu og fjarlægir tómar gjaldgengar skýrslur. Beiðnin hefur engar færibreytur.';
        ReopenNotesLbl: Label 'Returns reopenedLines. Unknown keys are refused.', Comment = 'is-IS=Skilar reopenedLines. Óþekktum lyklum er hafnað.';
        PostNotesLbl: Label 'Returns postedLines. Posting commits. Posted entries cannot be undone.', Comment = 'is-IS=Skilar postedLines. Bókun staðfestir færslurnar. Ekki er hægt að afturkalla bókaðar færslur.';
        ArchiveNotesLbl: Label 'Returns archived. The request has no parameters.', Comment = 'is-IS=Skilar archived. Beiðnin hefur engar færibreytur.';

    /// <summary>Declares the approval request keys.</summary>
    procedure AddApproveParameters(var Parameters: JsonArray): Boolean
    begin
        AddDecisionParameters(Parameters);
        exit(true);
    end;

    /// <summary>Declares rejection keys including the optional comment.</summary>
    procedure AddRejectParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        AddDecisionParameters(Parameters);
        Parameters.Add(ContractMgt.Parameter('comment', 'string', false, CommentTxt));
        exit(true);
    end;

    local procedure AddDecisionParameters(var Parameters: JsonArray)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('timeSheetNo', 'string', false, SheetTxt));
        Parameters.Add(ContractMgt.Parameter('timeSheetId', 'string', false, IdTxt));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', false, LinesTxt));
    end;

    /// <summary>Describes the versioned JSON envelope.</summary>
    procedure GetEnvelope(MessageType: Enum "Message Type ori"; var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        if IsBulkMessageType(MessageType) then begin
            Forms.Add('data');
            Subject.Add('use', 'optional');
            Subject.Add('forms', Forms);
            Subject.Add('description', BulkSubjectLbl);
            Envelope.Add('subject', Subject);
            Envelope.Add('dataRequired', true);
            Envelope.Add('version', '1.0');
            Envelope.Add('contentType', 'text/json');
            exit(true);
        end;

        Forms.Add('data');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', EnvelopeTxt);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the alternative time sheet identifiers.</summary>
    procedure GetTarget(MessageType: Enum "Message Type ori"; var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if IsBulkMessageType(MessageType) then
            exit(false);

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetTarget(Target));
        Target.Add(ContractMgt.TargetEntry('data.timeSheetNo', 'string', SheetTxt));
        Target.Add(ContractMgt.TargetEntry('data.timeSheetId', 'string', IdTxt));
        exit(true);
    end;

    /// <summary>Describes the returned decision lines.</summary>
    procedure GetResponse(MessageType: Enum "Message Type ori"; var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        if IsBulkMessageType(MessageType) then begin
            Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success'));
            case MessageType of
                MessageType::"Projects.TimeSheet.Reopen":
                    Fields.Add(ContractMgt.ResponseField('reopenedLines', 'integer', ReopenedCountLbl));
                MessageType::"Projects.TimeSheet.Post":
                    Fields.Add(ContractMgt.ResponseField('postedLines', 'integer', PostedCountLbl));
                MessageType::"Projects.TimeSheet.Archive":
                    Fields.Add(ContractMgt.ResponseField('archived', 'integer', ArchivedCountLbl));
            end;
            Response.Add('contentType', 'text/json');
            Response.Add('fields', Fields);
            exit(true);
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetResponse(Response));
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusTxt));
        Fields.Add(ContractMgt.ResponseField('lines', 'array', ResponseTxt));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists refusals and corrective next steps.</summary>
    procedure GetErrors(MessageType: Enum "Message Type ori"; var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if IsBulkMessageType(MessageType) then
            exit(GetBulkErrors(Errors));

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetErrors(Errors));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingTxt, MissingTxt, MissingNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatTxt, FormatTxt, FormatNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownTxt, UnknownTxt, UnknownNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundTxt, NotFoundTxt, NotFoundNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictTxt, ConflictTxt, ConflictNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErrorTxt, PermissionErrorTxt, PermissionTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ApproverErrorTxt, ApproverErrorTxt, ApproverTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidLineTxt, InvalidLineTxt, SubmitTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RuntimeTxt, RuntimeTxt, RuntimeNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, IsolatedTxt, IsolatedTxt, IsolatedNextTxt));
        exit(true);
    end;

    /// <summary>Documents commits and native absence posting side effects.</summary>
    procedure GetEffect(MessageType: Enum "Message Type ori"; var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        if IsBulkMessageType(MessageType) then
            exit(GetBulkEffect(MessageType, Effect));

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetEffect(Effect));
        Preconditions.Add(PermissionTxt);
        Preconditions.Add(ApproverTxt);
        Effect.Add('effect', 'write');
        Effect.Add('changes', EffectTxt);
        Effect.Add('idempotent', MessageType = MessageType::"Projects.TimeSheet.Approve");
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Links available message discovery.</summary>
    procedure GetRelated(MessageType: Enum "Message Type ori"; var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if IsBulkMessageType(MessageType) then begin
            Related.Add(ContractMgt.RelatedEntry('Help.MessageTypes.Get', BulkRelatedLbl));
            exit(true);
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(false);
        Related.Add(ContractMgt.RelatedEntry('Help.MessageTypes.Get', RelatedTxt));
        exit(true);
    end;

    /// <summary>Explains the manager decision workflow.</summary>
    procedure GetWorkflow(MessageType: Enum "Message Type ori"; var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        if IsBulkMessageType(MessageType) then begin
            Steps.Add(ContractMgt.WorkflowStep(MessageTypeName(MessageType), BulkStepLbl));
            Workflow.Add('steps', Steps);
            Workflow.Add('text', BulkWorkflowLbl);
            exit(true);
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetWorkflow(Workflow));
        Steps.Add(ContractMgt.WorkflowStep(MessageTypeName(MessageType), WorkflowTxt));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', WorkflowTxt);
        exit(true);
    end;

    /// <summary>Provides the action's request and response example.</summary>
    procedure GetExamples(MessageType: Enum "Message Type ori"; var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TypeName: Text;
        RequestText: Text;
        ResponseText: Text;
    begin
        if IsBulkMessageType(MessageType) then begin
            TypeName := MessageTypeName(MessageType);
            Examples.Add(ContractMgt.Example(TypeName, '{"type":"' + TypeName + '","data":' + ExampleRequest(MessageType) + '}', ExampleResponse(MessageType)));
            exit(true);
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetExamples(Examples));
        TypeName := MessageTypeName(MessageType);
        RequestText := '{"type":"' + TypeName + '","data":{"timeSheetNo":"TS0001","lineNos":[10000]}}';
        if MessageType = MessageType::"Projects.TimeSheet.Reject" then
            ResponseText := '{"status":"Success","lines":[{"timeSheetNo":"TS0001","lineNo":10000,"status":"Rejected","changed":true}]}'
        else
            ResponseText := '{"status":"Success","lines":[{"timeSheetNo":"TS0001","lineNo":10000,"status":"Approved","changed":true}]}';
        Examples.Add(ContractMgt.Example(TypeName, RequestText, ResponseText));
        exit(true);
    end;

    /// <summary>Returns the localized purpose.</summary>
    procedure GetOverview(MessageType: Enum "Message Type ori"; var Overview: Text): Boolean
    begin
        if IsBulkMessageType(MessageType) then begin
            case MessageType of
                MessageType::"Projects.TimeSheet.Reopen":
                    Overview := ReopenOverviewLbl;
                MessageType::"Projects.TimeSheet.Post":
                    Overview := PostOverviewLbl;
                MessageType::"Projects.TimeSheet.Archive":
                    Overview := ArchiveOverviewLbl;
            end;
            exit(true);
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetOverview(Overview));
        Overview := OverviewTxt;
        exit(true);
    end;

    /// <summary>Returns edge cases and transaction limitations.</summary>
    procedure GetNotes(MessageType: Enum "Message Type ori"; var Notes: Text): Boolean
    begin
        if IsBulkMessageType(MessageType) then begin
            Notes := NotesFor(MessageType);
            exit(Notes <> '');
        end;

        if MessageType = MessageType::"Projects.TimeSheet.Submit" then
            exit(SubmitGetNotes(Notes));
        Notes := NotesTxt;
        exit(true);
    end;

    local procedure MessageTypeName(MessageType: Enum "Message Type ori"): Text
    begin
        exit(MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger())));
    end;

    /// <summary>Provides the AddReopenParameters contract chapter for the native aliases.</summary>
    procedure AddReopenParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('endingDateTo', 'string', false, CutoffHelpLbl));
        exit(true);
    end;

    /// <summary>Provides the AddPostParameters contract chapter for the native aliases.</summary>
    procedure AddPostParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('journalTemplate', 'string', true, JournalTemplateHelpLbl));
        Parameters.Add(ContractMgt.Parameter('journalBatch', 'string', true, JournalBatchHelpLbl));
        exit(true);
    end;

    /// <summary>Provides the AddArchiveParameters contract chapter for the native aliases.</summary>
    procedure AddArchiveParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    local procedure GetBulkErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingHelpLbl, MissingHelpLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatHelpLbl, FormatHelpLbl, FormatNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownHelpLbl, UnknownHelpLbl, UnknownNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundHelpLbl, NotFoundHelpLbl, NotFoundNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictHelpLbl, ConflictHelpLbl, ConflictNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionHelpLbl, PermissionHelpLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RuntimeHelpLbl, RuntimeHelpLbl, RetryHelpLbl));
        exit(true);
    end;

    local procedure GetBulkEffect(MessageType: Enum "Message Type ori"; var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        if MessageType = MessageType::"Projects.TimeSheet.Post" then begin
            Effect.Add('effect', 'irreversible');
            Effect.Add('changes', PostChangesLbl);
        end else begin
            Effect.Add('effect', 'write');
            Effect.Add('changes', BulkChangesLbl);
        end;
        Preconditions.Add(BulkPreconditionLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    local procedure ExampleRequest(MessageType: Enum "Message Type ori"): Text
    begin
        case MessageType of
            MessageType::"Projects.TimeSheet.Reopen":
                exit('{"endingDateTo":"2026-06-30"}');
            MessageType::"Projects.TimeSheet.Post":
                exit('{"journalTemplate":"JOB","journalBatch":"DEFAULT"}');
            MessageType::"Projects.TimeSheet.Archive":
                exit('{}');
        end;
    end;

    local procedure ExampleResponse(MessageType: Enum "Message Type ori"): Text
    begin
        case MessageType of
            MessageType::"Projects.TimeSheet.Reopen":
                exit('{"status":"Success","reopenedLines":0}');
            MessageType::"Projects.TimeSheet.Post":
                exit('{"status":"Success","postedLines":0}');
            MessageType::"Projects.TimeSheet.Archive":
                exit('{"status":"Success","archived":0}');
        end;
    end;

    local procedure NotesFor(MessageType: Enum "Message Type ori"): Text
    begin
        case MessageType of
            MessageType::"Projects.TimeSheet.Reopen":
                exit(ReopenNotesLbl);
            MessageType::"Projects.TimeSheet.Post":
                exit(PostNotesLbl);
            MessageType::"Projects.TimeSheet.Archive":
                exit(ArchiveNotesLbl);
        end;
    end;

    local procedure IsBulkMessageType(MessageType: Enum "Message Type ori"): Boolean
    begin
        exit(MessageType in [MessageType::"Projects.TimeSheet.Reopen", MessageType::"Projects.TimeSheet.Post", MessageType::"Projects.TimeSheet.Archive"]);
    end;

    /// <summary>Handles AddSubmitParameters for the Submit message contract.</summary>
    procedure AddSubmitParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('timeSheetNo', 'string', false, SubmitSheetTxt));
        Parameters.Add(ContractMgt.Parameter('resourceNo', 'string', false, SubmitResourceTxt));
        Parameters.Add(ContractMgt.Parameter('date', 'string', false, SubmitDateTxt));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', false, SubmitLinesTxt));
        exit(true);
    end;

    /// <summary>Returns GetTarget for the Submit message contract.</summary>
    local procedure SubmitGetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.timeSheetNo', 'string', SubmitSheetTxt));
        exit(true);
    end;

    /// <summary>Returns GetResponse for the Submit message contract.</summary>
    local procedure SubmitGetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', SubmitSuccessTxt));
        Fields.Add(ContractMgt.ResponseField('lines', 'array', SubmitResponseTxt));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns GetErrors for the Submit message contract.</summary>
    local procedure SubmitGetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, SubmitMissingTxt, SubmitMissingTxt, SubmitMissingNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, SubmitTypeTxt, SubmitTypeTxt, SubmitTypeNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, SubmitUnknownTxt, SubmitUnknownTxt, SubmitUnknownNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, SubmitNotFoundTxt, SubmitNotFoundTxt, SubmitNotFoundNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, SubmitConflictTxt, SubmitConflictTxt, SubmitConflictNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, SubmitPermissionTxt, SubmitPermissionTxt, SubmitPermissionNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, SubmitOwnerTxt, SubmitOwnerTxt, SubmitOwnerNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, SubmitEmptyTxt, SubmitEmptyTxt, SubmitEmptyNextTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, SubmitLineTxt, SubmitLineTxt, SubmitLineNextTxt));
        exit(true);
    end;

    /// <summary>Returns GetEffect for the Submit message contract.</summary>
    local procedure SubmitGetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', SubmitEffectTxt);
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        exit(true);
    end;

    /// <summary>Returns GetWorkflow for the Submit message contract.</summary>
    local procedure SubmitGetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Projects.TimeSheet.Submit', SubmitOverviewTxt));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', SubmitResponseTxt);
        exit(true);
    end;

    /// <summary>Returns GetExamples for the Submit message contract.</summary>
    local procedure SubmitGetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Projects.TimeSheet.Submit', '{"type":"Projects.TimeSheet.Submit","data":{"timeSheetNo":"TS0001","lineNos":[10000]}}', '{"status":"Success","lines":[{"timeSheetNo":"TS0001","lineNo":10000,"status":"Submitted","changed":true}]}'));
        exit(true);
    end;

    /// <summary>Returns GetOverview for the Submit message contract.</summary>
    local procedure SubmitGetOverview(var Overview: Text): Boolean
    begin
        Overview := SubmitOverviewTxt;
        exit(true);
    end;

    /// <summary>Returns GetNotes for the Submit message contract.</summary>
    local procedure SubmitGetNotes(var Notes: Text): Boolean
    begin
        Notes := SubmitNotesTxt;
        exit(true);
    end;
}
