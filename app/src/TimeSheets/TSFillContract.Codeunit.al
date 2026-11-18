namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Bilingual contracts for copying and planning time-sheet lines.</summary>
codeunit 70013560 "TS Fill Contract ori"
{
    Access = Internal;

    var
        CopyTxt: Label 'Copy line definitions from the resource''s immediately preceding time sheet. Daily hours remain empty. The operation commits its isolated changes. Repeating a copy adds the lines again.', Comment = 'is-IS=Afritaðu línuskilgreiningar úr næstu fyrri tímaskýrslu auðlindarinnar. Daglegar klukkustundir haldast tómar. Aðgerðin staðfestir einangraðar breytingar. Endurtekin afritun bætir línunum við aftur.';
        PlanningTxt: Label 'Create lines from project planning for the resource within the time sheet period. Existing project/task combinations are skipped. Daily hours remain empty. The operation commits its isolated changes.', Comment = 'is-IS=Búðu til línur úr verkáætlun fyrir auðlindina innan tímabils tímaskýrslunnar. Fyrirliggjandi samsetningum verks og verkhluta er sleppt. Daglegar klukkustundir haldast tómar. Aðgerðin staðfestir einangraðar breytingar.';
        NumberTxt: Label 'Destination time sheet number. Send exactly one of timeSheetNo and timeSheetId.', Comment = 'is-IS=Númer tímaskýrslunnar sem tekur við línunum. Sendu nákvæmlega annað af timeSheetNo og timeSheetId.';
        IdTxt: Label 'Destination time sheet system ID (GUID), instead of timeSheetNo.', Comment = 'is-IS=Kerfisauðkenni tímaskýrslunnar (GUID), í stað timeSheetNo.';
        EnvelopeTxt: Label 'Parameters are supplied in data. The subject is not an identifier.', Comment = 'is-IS=Stikar eru sendir í data. Subject er ekki auðkenni.';
        LinesTxt: Label 'Only newly added lines, with timeSheetNo, lineNo, status, lineType and changed=true. Empty when none were added.', Comment = 'is-IS=Aðeins nýjar línur, með timeSheetNo, lineNo, status, lineType og changed=true. Tómt þegar engum línum var bætt við.';
        CountTxt: Label 'Number of newly added lines. Zero is success.', Comment = 'is-IS=Fjöldi nýrra lína. Núll er árangursrík niðurstaða.';
        SuccessTxt: Label 'Success on completion.', Comment = 'is-IS=Success þegar aðgerð er lokið.';
        PermissionTxt: Label 'The caller must own the time sheet and have permission to read the source and write time-sheet lines and details.', Comment = 'is-IS=Kallandinn verður að eiga tímaskýrsluna og hafa heimild til að lesa upprunann og skrifa tímaskýrslulínur og sundurliðun.';
        EffectTxt: Label 'Adds time-sheet lines atomically and commits. A refused call adds no lines. This action requires an isolated transaction. Pending work is committed before the isolated operation.', Comment = 'is-IS=Bætir tímaskýrslulínum við í einangraðri heild og staðfestir. Höfnun bætir engum línum við. Þessi aðgerð krefst einangraðrar færslu. Biðandi breytingar eru staðfestar fyrir einangruðu aðgerðina.';
        MissingTxt: Label 'A required identifier is missing.', Comment = 'is-IS=Nauðsynlegt auðkenni vantar.';
        MissingNextTxt: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeTxt: Label 'An identifier has the wrong JSON type or format.', Comment = 'is-IS=Auðkenni er af röngu JSON-tagi eða sniði.';
        TypeNextTxt: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownTxt: Label 'An unknown parameter was supplied.', Comment = 'is-IS=Óþekktur stiki var sendur.';
        UnknownNextTxt: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        MissingRecordTxt: Label 'The time sheet does not exist.', Comment = 'is-IS=Tímaskýrslan er ekki til.';
        MissingRecordNextTxt: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictTxt: Label 'Both timeSheetNo and timeSheetId were supplied.', Comment = 'is-IS=Bæði timeSheetNo og timeSheetId voru send.';
        ConflictNextTxt: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        OwnerTxt: Label 'The caller is not the owner.', Comment = 'is-IS=Kallandinn er ekki eigandinn.';
        OwnerNextTxt: Label 'Ask the owner.', Comment = 'is-IS=Biddu eigandann.';
        PermissionNextTxt: Label 'Assign the BIFROST Full ori and PROJ TS ADMIN permission sets.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunum BIFROST Full ori og PROJ TS ADMIN.';
        PreviousTxt: Label 'There is no previous time sheet for the resource.', Comment = 'is-IS=Engin fyrri tímaskýrsla er til fyrir auðlindina.';
        PreviousNextTxt: Label 'Add lines by hand.', Comment = 'is-IS=Bættu við línum handvirkt.';
        TransactionTxt: Label 'This action requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        TransactionNextTxt: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        NativeTxt: Label 'Business Central rejected the source lines. No lines were added.', Comment = 'is-IS=Business Central hafnaði upprunalínunum. Engum línum var bætt við.';
        NativeNextTxt: Label 'Check the time sheet and source lines in Business Central, then retry.', Comment = 'is-IS=Athugaðu tímaskýrsluna og upprunalínurnar í Business Central og reyndu aftur.';
        ExampleTxt: Label 'Fill an owned time sheet.', Comment = 'is-IS=Fylltu út tímaskýrslu í þinni eigu.';

    /// <summary>Declares the copy identifiers.</summary>
    procedure AddCopyParameters(var Parameters: JsonArray): Boolean
    begin
        exit(AddParameters(Parameters));
    end;

    /// <summary>Declares the planning identifiers.</summary>
    procedure AddPlanningParameters(var Parameters: JsonArray): Boolean
    begin
        exit(AddParameters(Parameters));
    end;

    local procedure AddParameters(var Parameters: JsonArray): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Mgt.Parameter('timeSheetNo', 'string', false, NumberTxt));
        Parameters.Add(Mgt.Parameter('timeSheetId', 'string', false, IdTxt));
        exit(true);
    end;

    /// <summary>Declares the request envelope.</summary>
    procedure GetEnvelope(MessageType: Enum "Message Type ori"; var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
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

    /// <summary>Describes the destination identifiers.</summary>
    procedure GetTarget(MessageType: Enum "Message Type ori"; var Target: JsonArray): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Mgt.TargetEntry('data.timeSheetNo', 'string', NumberTxt));
        Target.Add(Mgt.TargetEntry('data.timeSheetId', 'string', IdTxt));
        exit(true);
    end;

    /// <summary>Documents new line counts and returned rows.</summary>
    procedure GetResponse(MessageType: Enum "Message Type ori"; var Response: JsonObject): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Mgt.ResponseField('status', 'string', SuccessTxt));
        if MessageType = MessageType::"Projects.TimeSheetLine.CopyFromPrevious" then
            Fields.Add(Mgt.ResponseField('copied', 'integer', CountTxt))
        else
            Fields.Add(Mgt.ResponseField('created', 'integer', CountTxt));
        Fields.Add(Mgt.ResponseField('lines', 'array', LinesTxt));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists every refusal and actionable next step.</summary>
    procedure GetErrors(MessageType: Enum "Message Type ori"; var Errors: JsonArray): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingTxt, MissingTxt, MissingNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, TypeTxt, TypeTxt, TypeNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownTxt, UnknownTxt, UnknownNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingRecordTxt, MissingRecordTxt, MissingRecordNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictTxt, ConflictTxt, ConflictNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, OwnerTxt, OwnerTxt, OwnerNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionTxt, PermissionTxt, PermissionNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, TransactionTxt, TransactionTxt, TransactionNextTxt));
        Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeTxt, NativeTxt, NativeNextTxt));
        if MessageType = MessageType::"Projects.TimeSheetLine.CopyFromPrevious" then
            Errors.Add(Mgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreviousTxt, PreviousTxt, PreviousNextTxt));
        exit(true);
    end;

    /// <summary>Documents isolated committed writes and ownership.</summary>
    procedure GetEffect(MessageType: Enum "Message Type ori"; var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add(PermissionTxt);
        Effect.Add('effect', 'write');
        Effect.Add('changes', EffectTxt);
        Effect.Add('idempotent', MessageType = MessageType::"Projects.TimeSheetLine.CreateFromPlanning");
        Effect.Add('permissionSet', 'BIFROST Full ori, PROJ TS ADMIN');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Links the complementary fill operation.</summary>
    procedure GetRelated(MessageType: Enum "Message Type ori"; var Related: JsonArray): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType = MessageType::"Projects.TimeSheetLine.CopyFromPrevious" then
            Related.Add(Mgt.RelatedEntry('Projects.TimeSheetLine.CreateFromPlanning', PlanningTxt))
        else
            Related.Add(Mgt.RelatedEntry('Projects.TimeSheetLine.CopyFromPrevious', CopyTxt));
        exit(true);
    end;

    /// <summary>No multi-step workflow is required.</summary>
    procedure GetWorkflow(MessageType: Enum "Message Type ori"; var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a request and a valid empty success response.</summary>
    procedure GetExamples(MessageType: Enum "Message Type ori"; var Examples: JsonArray): Boolean
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
        TypeName: Text;
        ResponseText: Text;
    begin
        TypeName := MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger()));
        if MessageType = MessageType::"Projects.TimeSheetLine.CopyFromPrevious" then
            ResponseText := '{"status":"Success","copied":0,"lines":[]}'
        else
            ResponseText := '{"status":"Success","created":0,"lines":[]}';
        Examples.Add(Mgt.Example(ExampleTxt, '{"type":"' + TypeName + '","data":{"timeSheetNo":"TS0001"}}', ResponseText));
        exit(true);
    end;

    /// <summary>Explains the operation in the current language.</summary>
    procedure GetOverview(MessageType: Enum "Message Type ori"; var Overview: Text): Boolean
    begin
        if MessageType = MessageType::"Projects.TimeSheetLine.CopyFromPrevious" then
            Overview := CopyTxt
        else
            Overview := PlanningTxt;
        exit(true);
    end;

    /// <summary>Explains transaction and ownership restrictions.</summary>
    procedure GetNotes(MessageType: Enum "Message Type ori"; var Notes: Text): Boolean
    begin
        Notes := EffectTxt + ' ' + PermissionTxt;
        exit(true);
    end;
}
