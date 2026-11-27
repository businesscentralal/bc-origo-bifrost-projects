namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.MyTimeSheetLine.Set: Adds or edits lines and daily hours on the caller's own time sheet while a line is Open or Rejected. (projects#38)</summary>
codeunit 70013589 "TS My Line Set Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Adds or edits lines and daily hours on the caller''s own time sheet while a line is Open or Rejected.', Comment = 'is-IS=Bætir við eða breytir línum og daglegum stundum á eigin tímaskýrslu kallanda meðan lína er opin eða höfnuð.';
        KeywordsLbl: Label 'time sheet, my time sheet, line, hours, register, edit', Comment = 'is-IS=tímaskýrsla, mín tímaskýrsla, lína, stundir, skrá, breyta';
        RefusedLbl: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        OverviewLbl: Label 'Adds or edits lines on a time sheet whose Owner User ID is the authenticated caller. Submitted and approved lines cannot be changed; an edited rejected line returns to Open for a new submit. All entries are written in one transaction: a Business Central error rolls back the whole call.', Comment = 'is-IS=Bætir við eða breytir línum á tímaskýrslu þar sem Owner User ID er auðkenndur kallandi. Ekki er hægt að breyta innsendum eða samþykktum línum; breytt höfnuð lína verður opin og má senda inn aftur. Allar færslur eru skrifaðar í einni færslu: villa í Business Central afturkallar allt kallið.';
        NotesLbl: Label 'No delete: zero hours keeps the day with 0. Item and resource usage lines are not part of this version.', Comment = 'is-IS=Engin eyðing: núll stundir halda deginum með 0. Notkunarlínur vara og forða eru ekki hluti af þessari útgáfu.';
        Param0Lbl: Label 'Own time sheet number, maximum 20 characters. Required.', Comment = 'is-IS=Númer eigin tímaskýrslu, mest 20 stafir. Nauðsynlegt.';
        Param1Lbl: Label '1..50 entries. Each entry: optional lineNo (edit an Open or Rejected line; omit to add), type (Job or Resource, required to add), projectNo and taskNo (required to add a Job line), workTypeCode, description, days [{date, hours}] with dates inside the sheet period and hours 0..24.', Comment = 'is-IS=1..50 færslur. Hver færsla: valfrjálst lineNo (breyta opinni eða hafnaðri línu; sleppt til að bæta við), type (Job eða Resource, nauðsynlegt til að bæta við), projectNo og taskNo (nauðsynleg fyrir nýja Job línu), workTypeCode, description, days [{date, hours}] með dagsetningum innan tímabils og stundum 0..24.';
        Resp0Lbl: Label 'The own time sheet.', Comment = 'is-IS=Eigin tímaskýrslan.';
        Resp1Lbl: Label 'One node per entry: lineNo, created, status (Open) and totalHours.', Comment = 'is-IS=Einn hnútur á hverja færslu: lineNo, created, status (Open) og totalHours.';
        PermissionDeniedNextLbl: Label 'Read the refusal message: your own sheet, your queue or the time sheet permission set.', Comment = 'is-IS=Lestu höfnunarskilaboðin: eigin skýrsla, þín biðröð eða heimildasafn tímaskýrslna.';
        MissingParameterNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        InvalidParameterNextLbl: Label 'Use from <= to.', Comment = 'is-IS=Notaðu from <= to.';
        InvalidParameterFormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownParameterNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        RecordNotFoundNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        InvalidLineNextLbl: Label 'Select lines in the status the action needs.', Comment = 'is-IS=Veldu línur í þeirri stöðu sem aðgerðin krefst.';
        BusinessCentralErrorNextLbl: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';
        PreconditionFailedNextLbl: Label 'Add lines first, or run outside an uncommitted batch.', Comment = 'is-IS=Bættu við línum fyrst, eða keyrðu utan óstaðfestrar lotu.';

    /// <summary>Shows the type only to callers with the tables it uses.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        SelfMgt: Codeunit "TS Self Service Mgt ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.MyTimeSheetLine.Set") then
            exit(false);
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
        exit('Projects.MyTimeSheetLine.Set: ' + DescriptionLbl);
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
        Parameters.Add(Contract.Parameter('lines', 'array', false, Param1Lbl));
        exit(true);
    end;

    /// <summary>Documents the response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('timeSheetNo', 'string', Resp0Lbl));
        Fields.Add(Contract.ResponseField('lines', 'array', Resp1Lbl));
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
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidLine, RefusedLbl, InvalidLineNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, BusinessCentralErrorNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, PreconditionFailedNextLbl));
        exit(true);
    end;

    /// <summary>Declares the effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
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
        Examples.Add(Contract.Example('Projects.MyTimeSheetLine.Set', '{"type":"Projects.MyTimeSheetLine.Set","data":{"timeSheetNo":"TS0001","lines":[{"type":"Job","projectNo":"JOB00010","taskNo":"1010","description":"Design","days":[{"date":"2026-11-16","hours":4}]}]}}', '{"status":"Success","timeSheetNo":"TS0001","lines":[{"lineNo":10000,"created":true,"status":"Open","totalHours":4}]}'));
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
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        SelfMgt: Codeunit "TS Self Service Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.MyTimeSheetLine.Set") then
            exit;
        Argument.AssertVersion1();
        SelfMgt.ExecuteMyLineSet(Argument);
    end;
}
