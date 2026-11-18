namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.TimeSheetApproval.Approve: Approves submitted lines on a time sheet in the caller's approval queue. (projects#38)</summary>
codeunit 70013587 "TS Approval Approve Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Approves submitted lines on a time sheet in the caller''s approval queue.', Comment = 'is-IS=Samþykkir innsendar línur á tímaskýrslu í samþykktarbiðröð kallanda.';
        KeywordsLbl: Label 'time sheet, approval, approve, approver', Comment = 'is-IS=tímaskýrsla, samþykki, samþykkja, samþykkjandi';
        RefusedLbl: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        OverviewLbl: Label 'The approver named on the sheet approves submitted lines, per line or for the whole sheet. The caller can never approve their own sheet. Each successful call commits; a failure rolls back every selected line.', Comment = 'is-IS=Samþykkjandi sem er nefndur á skýrslunni samþykkir innsendar línur, eina og eina eða alla skýrsluna. Kallandi getur aldrei samþykkt eigin skýrslu. Hvert heppnað kall staðfestir; mistök afturkalla allar valdar línur.';
        NotesLbl: Label 'Approver only, checked here and again by the native writer. Approving absence lines also posts their absence entries. Role separation is the sheet''s approver identity, not the assigned permission set.', Comment = 'is-IS=Aðeins samþykkjandi, athugað hér og aftur í innbyggða skrifaranum. Samþykki fjarvistarlína bókar einnig fjarvistarfærslur. Aðskilnaður hlutverka byggist á samþykkjanda skýrslunnar, ekki á úthlutuðu heimildasetti.';
        Param0Lbl: Label 'Time sheet number. Send exactly one of timeSheetNo and timeSheetId.', Comment = 'is-IS=Númer tímaskýrslu. Sendu nákvæmlega annað hvort timeSheetNo eða timeSheetId.';
        Param1Lbl: Label 'Time sheet SystemId as a GUID; alternative to timeSheetNo.', Comment = 'is-IS=SystemId tímaskýrslu sem GUID; valkostur við timeSheetNo.';
        Param2Lbl: Label 'Positive integer line numbers. Omit for the whole sheet; an empty array selects none.', Comment = 'is-IS=Jákvæðar heiltölur línunúmera. Sleppt fyrir alla skýrsluna; tómt fylki velur engar.';
        Resp0Lbl: Label 'Selected lines: timeSheetNo, lineNo, status, changed. Already approved selected lines return changed false.', Comment = 'is-IS=Valdar línur: timeSheetNo, lineNo, status, changed. Þegar samþykktar valdar línur skila changed false.';
        PermissionDeniedNextLbl: Label 'Read the refusal message: your own sheet, your queue or the time sheet permission set.', Comment = 'is-IS=Lestu höfnunarskilaboðin: eigin skýrsla, þín biðröð eða heimildasafn tímaskýrslna.';
        MissingParameterNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        InvalidParameterFormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownParameterNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        RecordNotFoundNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictingIdentifiersNextLbl: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        InvalidLineNextLbl: Label 'Select lines in the status the action needs.', Comment = 'is-IS=Veldu línur í þeirri stöðu sem aðgerðin krefst.';
        BusinessCentralErrorNextLbl: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';
        PreconditionFailedNextLbl: Label 'Add lines first, or run outside an uncommitted batch.', Comment = 'is-IS=Bættu við línum fyrst, eða keyrðu utan óstaðfestrar lotu.';

    /// <summary>Shows the type only to callers with the tables it uses.</summary>
    procedure IsEnabled(): Boolean
    var
        SelfMgt: Codeunit "TS Self Service Mgt ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        exit(SelfMgt.CanReadSheets() and NativeMgt.CanMaintainSheets(false));
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
        exit('Projects.TimeSheetApproval.Approve: ' + DescriptionLbl);
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
        Parameters.Add(Contract.Parameter('timeSheetId', 'string', false, Param1Lbl));
        Parameters.Add(Contract.Parameter('lineNos', 'array', false, Param2Lbl));
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
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidLine, RefusedLbl, InvalidLineNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, BusinessCentralErrorNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, PreconditionFailedNextLbl));
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
        Examples.Add(Contract.Example('Projects.TimeSheetApproval.Approve', '{"type":"Projects.TimeSheetApproval.Approve","data":{"timeSheetNo":"TS0002","lineNos":[10000]}}', '{"status":"Success","lines":[{"timeSheetNo":"TS0002","lineNo":10000,"status":"Approved","changed":true}]}'));
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
        SelfMgt.ExecuteApprovalDecision(Argument, false);
    end;
}
