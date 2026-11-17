namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Builds the bilingual contract for creating weekly time sheets.</summary>
codeunit 70013557 "TS Create Contract ori"
{
    Access = Internal;

    /// <summary>Provides the GetEnvelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'optional');
        Subject.Add('description', Text1Lbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Provides the GetParameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('startingDate', 'string', true, Text2Lbl));
        Parameters.Add(ContractMgt.Parameter('numberOfPeriods', 'integer', false, Text3Lbl));
        Parameters.Add(ContractMgt.Parameter('resourceNo', 'string', false, Text4Lbl));
        Parameters.Add(ContractMgt.Parameter('resourceNos', 'array', false, Text5Lbl));
        Parameters.Add(ContractMgt.Parameter('resourceGroup', 'string', false, Text6Lbl));
        Parameters.Add(ContractMgt.Parameter('createLinesFromPlanning', 'boolean', false, Text7Lbl));
        exit(true);
    end;

    /// <summary>Provides the GetResponse contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', Text8Lbl));
        Fields.Add(ContractMgt.ResponseField('created', 'array', Text9Lbl));
        Fields.Add(ContractMgt.ResponseField('skipped', 'array', Text10Lbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides the GetErrors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, Text11Lbl, Text11Lbl, Text12Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, Text13Lbl, Text13Lbl, Text14Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, Text15Lbl, Text15Lbl, Text16Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, Text17Lbl, Text17Lbl, Text18Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, Text19Lbl, Text19Lbl, Text20Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, Text21Lbl, Text21Lbl, Text22Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, Text23Lbl, Text23Lbl, Text24Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, Text25Lbl, Text25Lbl, Text26Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, Text27Lbl, Text27Lbl, Text28Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, Text29Lbl, Text29Lbl, Text30Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, Text31Lbl, Text31Lbl, Text32Lbl));
        exit(true);
    end;

    /// <summary>Provides the GetEffect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', Text33Lbl);
        Effect.Add('idempotent', true);
        Preconditions.Add(Text34Lbl);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Provides the GetRelated contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Help.MessageTypes.Get', Text35Lbl));
        exit(true);
    end;

    /// <summary>Provides the GetWorkflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Projects.TimeSheet.Create', Text36Lbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides the GetExamples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(Text37Lbl, RequestTok, ResponseTok));
        exit(true);
    end;

    /// <summary>Provides the GetOverview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := Text38Lbl;
        exit(true);
    end;

    /// <summary>Provides the GetNotes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := Text39Lbl;
        exit(true);
    end;

    var
        Text1Lbl: Label 'Resource selection is supplied in data.', Comment = 'is-IS=Val auðlinda er sent í data.';
        Text2Lbl: Label 'First day of the first week, as an ISO date. Must match Time Sheet First Weekday in Resources Setup.', Comment = 'is-IS=Fyrsti dagur fyrstu viku á ISO-sniði. Verður að samsvara fyrsta vikudegi tímaskýrslna í auðlindauppsetningu.';
        Text3Lbl: Label 'Number of weekly periods, from 1 to 52. Default: 1.', Comment = 'is-IS=Fjöldi vikna, frá 1 til 52. Sjálfgefið: 1.';
        Text4Lbl: Label 'One literal resource number. Send exactly one of resourceNo, resourceNos or resourceGroup.', Comment = 'is-IS=Eitt bókstaflegt auðlindanúmer. Sendu nákvæmlega eitt af resourceNo, resourceNos eða resourceGroup.';
        Text5Lbl: Label 'Nonempty list of literal resource numbers. Duplicates are processed once; every resource must exist and use time sheets.', Comment = 'is-IS=Listi auðlindanúmera sem má ekki vera tómur. Tvítekningar eru unnar einu sinni; allar auðlindir verða að vera til og nota tímaskýrslur.';
        Text6Lbl: Label 'Resource group number. Every selected resource must be unblocked and use time sheets.', Comment = 'is-IS=Númer auðlindaflokks. Allar valdar auðlindir verða að vera ólæstar og nota tímaskýrslur.';
        Text7Lbl: Label 'Create lines from project planning for new sheets. Default: false. Existing sheets are not changed.', Comment = 'is-IS=Búa til línur úr verkáætlun fyrir nýjar skýrslur. Sjálfgefið: false. Fyrirliggjandi skýrslum er ekki breytt.';
        Text8Lbl: Label 'Success.', Comment = 'is-IS=Success.';
        Text9Lbl: Label 'New sheets with timeSheetNo, resourceNo, startingDate and endingDate.', Comment = 'is-IS=Nýjar skýrslur með timeSheetNo, resourceNo, startingDate og endingDate.';
        Text10Lbl: Label 'Existing sheets with the same resource and period, in the same shape as created.', Comment = 'is-IS=Fyrirliggjandi skýrslur fyrir sömu auðlind og tímabil, á sama sniði og created.';
        Text11Lbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        Text12Lbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        Text13Lbl: Label 'A key has the wrong JSON type or value.', Comment = 'is-IS=Lykill er af röngu JSON-tagi eða hefur rangt gildi.';
        Text14Lbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        Text15Lbl: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        Text16Lbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        Text17Lbl: Label 'A resource is missing, blocked or does not use time sheets, or the selected group is empty.', Comment = 'is-IS=Auðlind vantar, er læst eða notar ekki tímaskýrslur, eða valinn flokkur er tómur.';
        Text18Lbl: Label 'Turn on Use Time Sheet on the resource.', Comment = 'is-IS=Kveiktu á Notaðu tímaskýrslu á auðlindinni.';
        Text19Lbl: Label 'More than one resource selector was supplied.', Comment = 'is-IS=Fleiri en ein leið var notuð til að velja auðlindir.';
        Text20Lbl: Label 'Send only one of resourceNo, resourceNos or resourceGroup.', Comment = 'is-IS=Sendu aðeins eitt af resourceNo, resourceNos eða resourceGroup.';
        Text21Lbl: Label 'The caller lacks permission to create time sheets.', Comment = 'is-IS=Kallandinn hefur ekki heimild til að búa til tímaskýrslur.';
        Text22Lbl: Label 'Assign the BIFROST Timeshts ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Timeshts ori.';
        Text23Lbl: Label 'startingDate is not the configured first weekday. Nothing is written.', Comment = 'is-IS=startingDate er ekki stilltur fyrsti vikudagur. Ekkert er skrifað.';
        Text24Lbl: Label 'Use the first weekday named in the refusal.', Comment = 'is-IS=Notaðu fyrsta vikudaginn sem höfnunin nefnir.';
        Text25Lbl: Label 'Numbering is missing or the caller is not a time sheet administrator.', Comment = 'is-IS=Númeraröð vantar eða kallandinn er ekki stjórnandi tímaskýrslna.';
        Text26Lbl: Label 'Configure time sheet numbering and Time Sheet Admin. in User Setup.', Comment = 'is-IS=Stilltu númeraröð tímaskýrslna og Stjórnandi tímaskýrslna í notandauppsetningu.';
        Text27Lbl: Label 'numberOfPeriods is above 52.', Comment = 'is-IS=numberOfPeriods er yfir 52.';
        Text28Lbl: Label 'Split the call.', Comment = 'is-IS=Skiptu kallinu.';
        Text29Lbl: Label 'numberOfPeriods is less than 1.', Comment = 'is-IS=numberOfPeriods er minna en 1.';
        Text30Lbl: Label 'Send a number from 1 to 52.', Comment = 'is-IS=Sendu tölu frá 1 til 52.';
        Text31Lbl: Label 'Business Central refused the creation. Nothing is written.', Comment = 'is-IS=Business Central hafnaði stofnuninni. Ekkert er skrifað.';
        Text32Lbl: Label 'Check the resource owners, approvers, numbering and open accounting periods, then retry.', Comment = 'is-IS=Athugaðu eigendur auðlinda, samþykktaraðila, númeraröð og opin reikningstímabil og reyndu aftur.';
        Text33Lbl: Label 'Creates weekly time sheets through the standard Create Time Sheets action. Normal queue execution commits the batch; a refusal creates no sheets.', Comment = 'is-IS=Býr til vikulegar tímaskýrslur með hefðbundinni aðgerð. Venjuleg biðraðarkeyrsla staðfestir lotuna; höfnun býr ekki til skýrslur.';
        Text34Lbl: Label 'Time Sheet Admin., time sheet numbering, resource owners and approvers, and open accounting periods must be configured.', Comment = 'is-IS=Stilla þarf stjórnanda tímaskýrslna, númeraröð, eigendur og samþykktaraðila auðlinda og opin reikningstímabil.';
        Text35Lbl: Label 'Discover available message types.', Comment = 'is-IS=Finna tiltækar skilaboðategundir.';
        Text36Lbl: Label 'Create sheets for selected resources and weeks.', Comment = 'is-IS=Búa til skýrslur fyrir valdar auðlindir og vikur.';
        Text37Lbl: Label 'Create one weekly time sheet.', Comment = 'is-IS=Búa til eina vikulega tímaskýrslu.';
        Text38Lbl: Label 'Create weekly time sheets for a resource, a list of resources or a resource group. Existing sheets are returned under skipped; other sheets are returned under created.', Comment = 'is-IS=Búðu til vikulegar tímaskýrslur fyrir auðlind, lista auðlinda eða auðlindaflokk. Fyrirliggjandi skýrslur birtast í skipped; nýjar skýrslur birtast í created.';
        Text39Lbl: Label 'All selected resources are checked before any write. Resource numbers are literal identifiers, not filters. The standard action requires a time sheet administrator and validates accounting periods and resource setup.', Comment = 'is-IS=Allar valdar auðlindir eru athugaðar áður en skrifað er. Auðlindanúmer eru bókstafleg auðkenni, ekki síur. Hefðbundna aðgerðin krefst stjórnanda tímaskýrslna og staðfestir reikningstímabil og auðlindauppsetningu.';
        RequestTok: Label '{"type":"Projects.TimeSheet.Create","data":{"startingDate":"2026-06-01","resourceNo":"XRESOURCE"}}', Locked = true;
        ResponseTok: Label '{"status":"Success","created":[{"timeSheetNo":"XTS0001","resourceNo":"XRESOURCE","startingDate":"2026-06-01","endingDate":"2026-06-07"}],"skipped":[]}', Locked = true;
}
