namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.TimeSheetApproval.Get: Reads the time sheets waiting for the caller's approval, with their submitted lines. (projects#38)</summary>
codeunit 70013586 "TS Approval Get Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads the time sheets waiting for the caller''s approval, with their submitted lines.', Comment = 'is-IS=Les tímaskýrslur sem bíða samþykkis kallanda, með innsendum línum.';
        KeywordsLbl: Label 'time sheet, approval, approver, queue, submitted', Comment = 'is-IS=tímaskýrsla, samþykki, samþykkjandi, biðröð, innsendar';
        RefusedLbl: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        OverviewLbl: Label 'Returns only sheets whose Approver User ID is the authenticated caller and that hold submitted lines. The caller''s own sheets are never in the queue. A caller who approves no resource or sheet is refused. No writes occur.', Comment = 'is-IS=Skilar aðeins skýrslum þar sem Approver User ID er auðkenndur kallandi og sem hafa innsendar línur. Eigin skýrslur kallanda eru aldrei í biðröðinni. Kallanda sem samþykkir engan forða eða skýrslu er hafnað. Engin skrif fara fram.';
        NotesLbl: Label 'Approver only. A named sheet outside the queue is refused with no data. Item and resource usage lines are not part of this version.', Comment = 'is-IS=Aðeins samþykkjandi. Nefndri skýrslu utan biðraðar er hafnað án gagna. Notkunarlínur vara og forða eru ekki hluti af þessari útgáfu.';
        Param0Lbl: Label 'Optional time sheet number in the caller''s queue, maximum 20 characters.', Comment = 'is-IS=Valfrjálst tímaskýrslunúmer í biðröð kallanda, mest 20 stafir.';
        Param1Lbl: Label 'First included date, YYYY-MM-DD; requires to.', Comment = 'is-IS=Fyrsti dagur, YYYY-MM-DD; krefst to.';
        Param2Lbl: Label 'Last included date, YYYY-MM-DD; requires from.', Comment = 'is-IS=Síðasti dagur, YYYY-MM-DD; krefst from.';
        Param3Lbl: Label 'Sheets per page, integer 1..100, default 20.', Comment = 'is-IS=Skýrslur á síðu, heiltala 1..100, sjálfgefið 20.';
        Param4Lbl: Label 'Number of matching sheets to skip, integer >= 0, default 0.', Comment = 'is-IS=Fjöldi samsvarandi skýrslna sem sleppt er, heiltala >= 0, sjálfgefið 0.';
        Resp0Lbl: Label 'Sheets in the caller''s queue: timeSheetNo, timeSheetId, resourceNo, startingDate, endingDate, ownerUserId and the submitted lines with days, totalHours and comments.', Comment = 'is-IS=Skýrslur í biðröð kallanda: timeSheetNo, timeSheetId, resourceNo, startingDate, endingDate, ownerUserId og innsendar línur með days, totalHours og comments.';
        Resp1Lbl: Label 'Whether more matching sheets exist after this page.', Comment = 'is-IS=Hvort fleiri samsvarandi skýrslur eru á eftir síðunni.';
        PermissionDeniedNextLbl: Label 'Read the refusal message: your own sheet, your queue or the time sheet permission set.', Comment = 'is-IS=Lestu höfnunarskilaboðin: eigin skýrsla, þín biðröð eða heimildasafn tímaskýrslna.';
        MissingParameterNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        InvalidParameterNextLbl: Label 'Use from <= to.', Comment = 'is-IS=Notaðu from <= to.';
        InvalidParameterFormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownParameterNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        RecordNotFoundNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';

    /// <summary>Shows the type only to callers with the tables it uses.</summary>
    procedure IsEnabled(): Boolean
    var
        SelfMgt: Codeunit "TS Self Service Mgt ori";
    begin
        exit(SelfMgt.CanReadSheets());
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
        exit('Projects.TimeSheetApproval.Get: ' + DescriptionLbl);
    end;

    /// <summary>Declares the message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
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
        Envelope.Add('dataRequired', false);
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
        Parameters.Add(Contract.Parameter('from', 'date', false, Param1Lbl));
        Parameters.Add(Contract.Parameter('to', 'date', false, Param2Lbl));
        Parameters.Add(Contract.Parameter('take', 'integer', false, Param3Lbl));
        Parameters.Add(Contract.Parameter('skip', 'integer', false, Param4Lbl));
        exit(true);
    end;

    /// <summary>Documents the response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('timeSheets', 'array', Resp0Lbl));
        Fields.Add(Contract.ResponseField('hasMore', 'boolean', Resp1Lbl));
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
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, RefusedLbl, InvalidParameterNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, InvalidParameterFormatNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownParameterNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, RecordNotFoundNextLbl));
        exit(true);
    end;

    /// <summary>Declares the effect.</summary>
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
        Examples.Add(Contract.Example('Projects.TimeSheetApproval.Get', '{"type":"Projects.TimeSheetApproval.Get","data":{"take":10}}', '{"status":"Success","timeSheets":[{"timeSheetNo":"TS0002","ownerUserId":"EMPLOYEE1","lines":[{"lineNo":10000,"status":"Submitted","totalHours":8}]}],"hasMore":false}'));
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
        SelfMgt.ExecuteApprovalGet(Argument);
    end;
}
