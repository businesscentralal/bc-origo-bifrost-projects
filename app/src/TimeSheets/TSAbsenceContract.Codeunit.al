namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Contract chapters for the native Timesheets message types. Parameter lists are
/// separate procedures so each type declares only the keys it reads.
/// </summary>
codeunit 70013552 "TS Absence Contract ori"
{
    Access = Internal;

    var
        SheetParameterLbl: Label 'Time sheet number. Send this or resourceNo plus date. With quantity, date may also be sent as its day.', Comment = 'is-IS=Númer tímaskýrslu. Sendu þetta eða resourceNo ásamt date. Með quantity má einnig senda date sem dag magnsins.';
        ResourceParameterLbl: Label 'Resource number, together with date, when timeSheetNo is omitted. Date also supplies the day for quantity.', Comment = 'is-IS=Númer auðlindar ásamt date þegar timeSheetNo er sleppt. Date gefur einnig dag fyrir quantity.';
        DateParameterLbl: Label 'ISO date inside the time sheet. With resourceNo it selects the sheet; with timeSheetNo and quantity it is the quantity day.', Comment = 'is-IS=ISO-dagsetning innan tímaskýrslunnar. Með resourceNo velur hún tímaskýrslu; með timeSheetNo og quantity er hún dagur magnsins.';
        CauseParameterLbl: Label 'Cause of absence code.', Comment = 'is-IS=Kóði fjarvistarástæðu.';
        HoursParameterLbl: Label 'Days as objects with date and quantity. Do not combine with quantity.', Comment = 'is-IS=Dagar sem hlutir með date og quantity. Ekki nota með quantity.';
        QuantityParameterLbl: Label 'Hours on date. Send with timeSheetNo plus date, or with resourceNo and date. Do not combine with hours.', Comment = 'is-IS=Klukkustundir á date. Sendu með timeSheetNo ásamt date eða með resourceNo og date. Ekki nota með hours.';
        SubjectDescriptionLbl: Label 'The Business Central time sheet operation addressed by the request.', Comment = 'is-IS=Aðgerðin á tímaskýrslu í Business Central sem beiðnin á við.';
        TargetDescriptionLbl: Label 'Time sheet number, or omit it and send resourceNo plus date.', Comment = 'is-IS=Númer tímaskýrslu eða slepptu því og sendu resourceNo ásamt date.';
        SuccessDescriptionLbl: Label 'Success.', Comment = 'is-IS=Tókst.';
        SheetDescriptionLbl: Label 'Time sheet number.', Comment = 'is-IS=Númer tímaskýrslu.';
        LineDescriptionLbl: Label 'Absence line number.', Comment = 'is-IS=Númer fjarvistarlínu.';
        CauseDescriptionLbl: Label 'Cause of absence.', Comment = 'is-IS=Fjarvistarástæða.';
        ResourceDescriptionLbl: Label 'Resource number of the time sheet.', Comment = 'is-IS=Númer auðlindar tímaskýrslunnar.';
        HoursDescriptionLbl: Label 'Hours written, per day.', Comment = 'is-IS=Skráðar klukkustundir eftir dögum.';
        WarningsDescriptionLbl: Label 'Present when hours fall on a non-working day. The line is still written.', Comment = 'is-IS=Birtist þegar klukkustundir lenda á degi sem er ekki vinnudagur. Línan er samt skráð.';
        MissingMessageLbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingDescriptionLbl: Label 'The request omitted a key this type needs.', Comment = 'is-IS=Lykil sem þessi tegund þarf vantar í beiðnina.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeMessageLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        TypeDescriptionLbl: Label 'A value was not the documented JSON type.', Comment = 'is-IS=Gildi var ekki af skráðu JSON-tagi.';
        TypeNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownMessageLbl: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownDescriptionLbl: Label 'This native type refuses keys it does not document. Processing stops.', Comment = 'is-IS=Þessi tegund hafnar óskráðum lyklum. Vinnslan stöðvast.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        IdentifierMessageLbl: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        IdentifierDescriptionLbl: Label 'The time sheet, resource or cause was not found.', Comment = 'is-IS=Tímaskýrslan, auðlindin eða fjarvistarástæðan fannst ekki.';
        IdentifierNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictMessageLbl: Label 'The request names the record in more than one way.', Comment = 'is-IS=Beiðnin nefnir færsluna á fleiri en einn hátt.';
        ConflictDescriptionLbl: Label 'Two identifiers were sent for one time sheet or resource.', Comment = 'is-IS=Tvö auðkenni voru send fyrir eina tímaskýrslu eða auðlind.';
        ConflictNextLbl: Label 'Send only one identifier for the time sheet.', Comment = 'is-IS=Sendu aðeins eitt auðkenni fyrir tímaskýrsluna.';
        InvalidHoursMessageLbl: Label 'Hours dates must be unique and inside the time sheet period.', Comment = 'is-IS=Dagsetningar klukkustunda verða að vera einstakar og innan tímabils tímaskýrslunnar.';
        InvalidHoursDescriptionLbl: Label 'A requested hour date is outside the selected time sheet or appears more than once.', Comment = 'is-IS=Dagsetning klukkustunda er utan valinnar tímaskýrslu eða birtist oftar en einu sinni.';
        InvalidHoursNextLbl: Label 'Send each date once and keep every date inside the time sheet period.', Comment = 'is-IS=Sendu hverja dagsetningu einu sinni og haltu öllum dagsetningum innan tímabils tímaskýrslunnar.';
        PermissionMessageLbl: Label 'The caller cannot run this type.', Comment = 'is-IS=Kallandinn getur ekki keyrt þessa tegund.';
        PermissionDescriptionLbl: Label 'This type needs write access to time sheets.', Comment = 'is-IS=Þessi tegund þarf skrifheimild á tímaskýrslum.';
        PermissionNextLbl: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        EmployeeMessageLbl: Label 'The resource is not linked to an employee.', Comment = 'is-IS=Auðlindin er ekki tengd við starfsmann.';
        EmployeeDescriptionLbl: Label 'No employee has this resource number. Nothing is written.', Comment = 'is-IS=Enginn starfsmaður hefur þetta auðlindarnúmer. Ekkert er skráð.';
        EmployeeNextLbl: Label 'Link the resource to an employee in BC.', Comment = 'is-IS=Tengdu auðlindina við starfsmann í BC.';
        CauseMessageLbl: Label 'The cause of absence was not found.', Comment = 'is-IS=Fjarvistarástæðan fannst ekki.';
        CauseMissingDescriptionLbl: Label 'The code is not in Causes of Absence.', Comment = 'is-IS=Kóðinn er ekki í fjarvistarástæðum.';
        CauseNextLbl: Label 'Use a code from Causes of Absence.', Comment = 'is-IS=Notaðu kóða úr fjarvistarástæðum.';
        PermissionPreconditionLbl: Label 'The caller has the BIFROST Full ori permission set.', Comment = 'is-IS=Kallandinn hefur heimildasamstæðuna BIFROST Full ori.';
        ChangesDescriptionLbl: Label 'Adds an absence line and its daily hours to a time sheet. The write is committed when the call succeeds. A refused call writes nothing.', Comment = 'is-IS=Bætir fjarvistarlínu og klukkustundum eftir dögum við tímaskýrslu. Skráning er staðfest þegar kallið tekst. Kall sem er hafnað skráir ekkert.';
        RelatedDescriptionLbl: Label 'The type is also listed with the other message types.', Comment = 'is-IS=Tegundin birtist einnig með öðrum skilaboðategundum.';
        WorkflowStepDescriptionLbl: Label 'Register the absence line and its hours.', Comment = 'is-IS=Skráðu fjarvistarlínuna og klukkustundir hennar.';
        WorkflowDescriptionLbl: Label 'Read the returned line before the next call. The line becomes an Employee Absence when the time sheet is posted.', Comment = 'is-IS=Lestu línuna sem var skilað fyrir næsta kall. Línan verður að starfsmannafjarvist þegar tímaskýrslan er bókuð.';
        OverviewDescriptionLbl: Label 'Projects.Absence.Register adds an absence line with a cause of absence and hours per day to a time sheet. A refusal writes nothing. Unknown keys are refused.', Comment = 'is-IS=Projects.Absence.Register bætir fjarvistarlínu með fjarvistarástæðu og klukkustundum eftir dögum við tímaskýrslu. Höfnun skráir ekkert. Óþekktum lyklum er hafnað.';
        NotesDescriptionLbl: Label 'Link the resource to an employee in BC. Use a code from Causes of Absence. Hours on Saturday or Sunday are written and returned with a warning. Employee Absence is created when the line is posted by Business Central, not by this type. The write is committed when the call succeeds.', Comment = 'is-IS=Tengdu auðlindina við starfsmann í BC. Notaðu kóða úr fjarvistarástæðum. Klukkustundir á laugardegi eða sunnudegi eru skráðar og skilað með viðvörun. Business Central stofnar starfsmannafjarvist þegar línan er bókuð. Skráning er staðfest þegar kallið tekst.';

    /// <summary>Declares exactly the six supported absence request keys.</summary>
    procedure AddAbsenceParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('timeSheetNo', 'string', false, SheetParameterLbl));
        Parameters.Add(ContractMgt.Parameter('resourceNo', 'string', false, ResourceParameterLbl));
        Parameters.Add(ContractMgt.Parameter('date', 'string', false, DateParameterLbl));
        Parameters.Add(ContractMgt.Parameter('causeOfAbsenceCode', 'string', true, CauseParameterLbl));
        Parameters.Add(ContractMgt.Parameter('hours', 'array', false, HoursParameterLbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'decimal', false, QuantityParameterLbl));
        exit(true);
    end;

    /// <summary>Describes the supported task envelope.</summary>
    procedure GetEnvelope(MessageType: Enum "Message Type ori"; var Envelope: JsonObject): Boolean
    var
        Forms: JsonArray;
        Subject: JsonObject;
    begin
        Forms.Add('data');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', SubjectDescriptionLbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(MessageType = MessageType::"Projects.Absence.Register");
    end;

    /// <summary>Describes the time-sheet identifier.</summary>
    procedure GetTarget(MessageType: Enum "Message Type ori"; var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Target.Add(ContractMgt.TargetEntry('data.timeSheetNo', 'string', TargetDescriptionLbl));
        exit(true);
    end;

    /// <summary>Describes the absence line returned on success.</summary>
    procedure GetResponse(MessageType: Enum "Message Type ori"; var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Fields.Add(ContractMgt.ResponseField('status', 'string', SuccessDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('timeSheetNo', 'string', SheetDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', LineDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('causeOfAbsenceCode', 'string', CauseDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('resourceNo', 'string', ResourceDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('hours', 'array', HoursDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('warnings', 'array', WarningsDescriptionLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists documented refusals and recovery steps.</summary>
    procedure GetErrors(MessageType: Enum "Message Type ori"; var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingMessageLbl, MissingDescriptionLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, TypeMessageLbl, TypeDescriptionLbl, TypeNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownMessageLbl, UnknownDescriptionLbl, UnknownNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, IdentifierMessageLbl, IdentifierDescriptionLbl, IdentifierNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictMessageLbl, ConflictDescriptionLbl, ConflictNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidHoursMessageLbl, InvalidHoursDescriptionLbl, InvalidHoursNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionMessageLbl, PermissionDescriptionLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, EmployeeMessageLbl, EmployeeDescriptionLbl, EmployeeNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, CauseMessageLbl, CauseMissingDescriptionLbl, CauseNextLbl));
        exit(true);
    end;

    /// <summary>Describes the committed write and required permissions.</summary>
    procedure GetEffect(MessageType: Enum "Message Type ori"; var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Preconditions.Add(PermissionPreconditionLbl);
        Effect.Add('effect', 'write');
        Effect.Add('changes', ChangesDescriptionLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Lists related discovery messages.</summary>
    procedure GetRelated(MessageType: Enum "Message Type ori"; var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Related.Add(ContractMgt.RelatedEntry('Help.MessageTypes.Get', RelatedDescriptionLbl));
        exit(true);
    end;

    /// <summary>Describes the absence registration workflow.</summary>
    procedure GetWorkflow(MessageType: Enum "Message Type ori"; var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Steps.Add(ContractMgt.WorkflowStep(MessageTypeName(MessageType), WorkflowStepDescriptionLbl));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', WorkflowDescriptionLbl);
        exit(true);
    end;

    /// <summary>Provides an absence registration request and response example.</summary>
    procedure GetExamples(MessageType: Enum "Message Type ori"; var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Name: Text;
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Name := MessageTypeName(MessageType);
        Examples.Add(ContractMgt.Example(Name, '{"type":"' + Name + '","data":{"timeSheetNo":"TS0001","causeOfAbsenceCode":"VAC","hours":[{"date":"2026-06-02","quantity":8}]}}', '{"status":"Success","timeSheetNo":"TS0001","lineNo":10000,"causeOfAbsenceCode":"VAC","resourceNo":"RES0001","hours":[{"date":"2026-06-02","quantity":8}]}'));
        exit(true);
    end;

    /// <summary>Returns the localized purpose of the message.</summary>
    procedure GetOverview(MessageType: Enum "Message Type ori"; var Overview: Text): Boolean
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Overview := OverviewDescriptionLbl;
        exit(true);
    end;

    /// <summary>Explains employee linking, weekend warnings and commit behavior.</summary>
    procedure GetNotes(MessageType: Enum "Message Type ori"; var Notes: Text): Boolean
    begin
        if MessageType <> MessageType::"Projects.Absence.Register" then
            exit(false);
        Notes := NotesDescriptionLbl;
        exit(true);
    end;

    /// <summary>Returns the stable message type name used in examples.</summary>
    procedure MessageTypeName(MessageType: Enum "Message Type ori"): Text
    begin
        exit(Enum::"Message Type ori".Names().Get(Enum::"Message Type ori".Ordinals().IndexOf(MessageType.AsInteger())));
    end;
}
