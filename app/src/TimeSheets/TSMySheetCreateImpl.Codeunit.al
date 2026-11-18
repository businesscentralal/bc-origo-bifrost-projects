namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.MyTimeSheet.Create: Creates the caller's own time sheet for one period if none exists. (projects#38)</summary>
codeunit 70013591 "TS My Sheet Create Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Creates the caller''s own time sheet for one period if none exists.', Comment = 'is-IS=Stofnar eigin tímaskýrslu kallanda fyrir eitt tímabil ef engin er til.';
        KeywordsLbl: Label 'time sheet, my time sheet, create, own, period', Comment = 'is-IS=tímaskýrsla, mín tímaskýrsla, stofna, eigin, tímabil';
        RefusedLbl: Label 'The time sheet request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um tímaskýrslu.';
        OverviewLbl: Label 'Creates one time sheet for a resource whose Time Sheet Owner User ID is the authenticated caller, with the same rules as the Business Central Create Time Sheets report. Another resource is refused. A sheet that already exists is returned with created false. A successful call commits.', Comment = 'is-IS=Stofnar eina tímaskýrslu fyrir forða þar sem Time Sheet Owner User ID er auðkenndur kallandi, með sömu reglum og skýrslan Create Time Sheets í Business Central. Öðrum forða er hafnað. Skýrsla sem er þegar til er skilað með created false. Heppnað kall staðfestir.';
        NotesLbl: Label 'The caller does not need Time Sheet Admin.; the request is limited to the caller''s own resource and one period.', Comment = 'is-IS=Kallandi þarf ekki Time Sheet Admin.; beiðnin takmarkast við eigin forða kallanda og eitt tímabil.';
        Param0Lbl: Label 'First day of the period, YYYY-MM-DD, on the Time Sheet First Weekday from Resources Setup. Required.', Comment = 'is-IS=Fyrsti dagur tímabils, YYYY-MM-DD, á Time Sheet First Weekday úr Resources Setup. Nauðsynlegt.';
        Param1Lbl: Label 'Own resource number. Needed only when the caller owns more than one time sheet resource.', Comment = 'is-IS=Númer eigin forða. Aðeins nauðsynlegt þegar kallandi á fleiri en einn tímaskýrsluforða.';
        Resp0Lbl: Label 'True when a new sheet was created; false when the sheet already existed (nothing changes).', Comment = 'is-IS=True þegar ný skýrsla var stofnuð; false þegar skýrslan var þegar til (engu er breytt).';
        Resp1Lbl: Label 'timeSheetNo, resourceNo, startingDate and endingDate of the own sheet.', Comment = 'is-IS=timeSheetNo, resourceNo, startingDate og endingDate eigin skýrslu.';
        PermissionDeniedNextLbl: Label 'Read the refusal message: your own sheet, your queue or the time sheet permission set.', Comment = 'is-IS=Lestu höfnunarskilaboðin: eigin skýrsla, þín biðröð eða heimildasafn tímaskýrslna.';
        MissingParameterNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        InvalidParameterNextLbl: Label 'Use from <= to.', Comment = 'is-IS=Notaðu from <= to.';
        InvalidParameterFormatNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownParameterNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        BusinessCentralErrorNextLbl: Label 'Correct the Business Central error and retry.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur.';
        PreconditionFailedNextLbl: Label 'Add lines first, or run outside an uncommitted batch.', Comment = 'is-IS=Bættu við línum fyrst, eða keyrðu utan óstaðfestrar lotu.';

    /// <summary>Shows the type only to callers with the tables it uses.</summary>
    procedure IsEnabled(): Boolean
    var
        SelfMgt: Codeunit "TS Self Service Mgt ori";
    begin
        exit(SelfMgt.CanReadSheets() and SelfMgt.CanCreateSheets());
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
        exit('Projects.MyTimeSheet.Create: ' + DescriptionLbl);
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
        Parameters.Add(Contract.Parameter('startingDate', 'date', false, Param0Lbl));
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, Param1Lbl));
        exit(true);
    end;

    /// <summary>Documents the response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('created', 'boolean', Resp0Lbl));
        Fields.Add(Contract.ResponseField('timeSheet', 'object', Resp1Lbl));
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
        Examples.Add(Contract.Example('Projects.MyTimeSheet.Create', '{"type":"Projects.MyTimeSheet.Create","data":{"startingDate":"2026-11-16"}}', '{"status":"Success","created":true,"timeSheet":{"timeSheetNo":"TS00042","resourceNo":"R0010","startingDate":"2026-11-16","endingDate":"2026-11-22"}}'));
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
        SelfMgt.ExecuteMyCreate(Argument);
    end;
}
