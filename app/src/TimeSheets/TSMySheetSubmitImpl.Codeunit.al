namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.MyTimeSheet.Submit: Submits the caller's own open time sheet lines for approval. (projects#38)</summary>
codeunit 70013585 "TS My Sheet Submit Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Submits the caller''s own open time sheet lines for approval.', Comment = 'is-IS=Sendir opnar línur í eigin tímaskýrslu kallanda til samþykktar.';
        KeywordsLbl: Label 'time sheet, my time sheet, submit, own', Comment = 'is-IS=tímaskýrsla, mín tímaskýrsla, senda inn, eigin';
        RefusedLbl: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        OverviewLbl: Label 'Submits open lines on a time sheet whose Owner User ID is the authenticated caller. Another user''s sheet is refused before any write. Each successful call commits; a failed line rolls back the call.', Comment = 'is-IS=Sendir inn opnar línur á tímaskýrslu þar sem Owner User ID er auðkenndur kallandi. Tímaskýrslu annars notanda er hafnað fyrir öll skrif. Hvert heppnað kall staðfestir; mistök í línu afturkalla kallið.';
        NotesLbl: Label 'Owner only, checked here and again by the native writer. Rejected lines are edited and then submitted again.', Comment = 'is-IS=Aðeins eigandi, athugað hér og aftur í innbyggða skrifaranum. Hafnaðar línur eru lagfærðar og sendar inn aftur.';
        Param0Lbl: Label 'Own time sheet number. Send this or resourceNo plus date.', Comment = 'is-IS=Númer eigin tímaskýrslu. Sendu þetta eða resourceNo ásamt date.';
        Param1Lbl: Label 'Own resource number, together with date, when timeSheetNo is omitted.', Comment = 'is-IS=Númer eigin forða ásamt date þegar timeSheetNo er sleppt.';
        Param2Lbl: Label 'ISO date inside the time sheet, together with resourceNo.', Comment = 'is-IS=ISO-dagsetning innan tímaskýrslunnar ásamt resourceNo.';
        Param3Lbl: Label 'Optional line numbers. Omit for all open lines. An empty array selects none.', Comment = 'is-IS=Valfrjáls línunúmer. Sleppt til að velja allar opnar línur. Tómt fylki velur engar.';
        Resp0Lbl: Label 'Lines with timeSheetNo, lineNo, status, changed and lineType. Already submitted lines return changed false.', Comment = 'is-IS=Línur með timeSheetNo, lineNo, status, changed og lineType. Þegar innsendar línur skila changed false.';
        PermissionDeniedNextLbl: Label 'Read the refusal message: your own sheet, your queue or the time sheet permission set.', Comment = 'is-IS=Lestu höfnunarskilaboðin: eigin skýrsla, þín biðröð eða heimildasafn tímaskýrslna.';
        MissingParameterNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        InvalidParameterFormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownParameterNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        RecordNotFoundNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictingIdentifiersNextLbl: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        PreconditionFailedNextLbl: Label 'Add lines first, or run outside an uncommitted batch.', Comment = 'is-IS=Bættu við línum fyrst, eða keyrðu utan óstaðfestrar lotu.';
        InvalidLineNextLbl: Label 'Select lines in the status the action needs.', Comment = 'is-IS=Veldu línur í þeirri stöðu sem aðgerðin krefst.';

    /// <summary>Shows the type only to callers with the tables it uses.</summary>
    procedure IsEnabled(): Boolean
    var
        SelfMgt: Codeunit "TS Self Service Mgt ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        exit(SelfMgt.CanReadSheets() and NativeMgt.CanMaintainSheets());
    end;

    /// <summary>Uses explicit keys rather than a table-filter envelope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the localized purpose.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns discovery terms.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes selection.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Projects.MyTimeSheet.Submit: ' + DescriptionLbl);
    end;

    /// <summary>Declares the message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the version-one JSON request in data.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', true);
        exit(true);
    end;

    /// <summary>The caller identity supplies the scope.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares the accepted keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('timeSheetNo', 'string', false, Param0Lbl));
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, Param1Lbl));
        Parameters.Add(Contract.Parameter('date', 'date', false, Param2Lbl));
        Parameters.Add(Contract.Parameter('lineNos', 'array', false, Param3Lbl));
        exit(true);
    end;

    /// <summary>Documents the response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('lines', 'array', Resp0Lbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents every refusal with a next step.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionDeniedNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingParameterNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, InvalidParameterFormatNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownParameterNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, RecordNotFoundNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictingIdentifiersNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, PreconditionFailedNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidLine, RefusedLbl, InvalidLineNextLbl));
        exit(true);
    end;

    /// <summary>Declares the effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', true);
        exit(true);
    end;

    /// <summary>Uses standard Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Points to the other self-service and approval types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Help.MessageTypes.Get', KeywordsLbl));
        exit(true);
    end;

    /// <summary>No workflow beyond the single call.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a request and response example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Projects.MyTimeSheet.Submit', '{"type":"Projects.MyTimeSheet.Submit","data":{"timeSheetNo":"TS0001"}}', '{"status":"Success","lines":[{"timeSheetNo":"TS0001","lineNo":10000,"status":"Submitted","changed":true,"lineType":"Job"}]}'));
        exit(true);
    end;

    /// <summary>Describes caller isolation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns edge cases.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Runs the own-only or approver-only check, then the call.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        SelfMgt: Codeunit "TS Self Service Mgt ori";
    begin
        Argument.AssertVersion1();
        SelfMgt.ExecuteMySubmit(Argument);
    end;
}
