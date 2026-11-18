namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Contract chapters for Projects.TimeSheetLine.Set.</summary>
codeunit 70013592 "TS Line Set Contract ori"
{
    Access = Internal;

    var
        SheetParameterLbl: Label 'Time sheet number.', Comment = 'is-IS=Númer tímaskýrslu.';
        LinesParameterLbl: Label 'Lines to add or change, at most 100. Each line is an object: lineNo (integer, omit to add a line), type (project, resource, absence or service; required for a new line), projectNo and projectTaskNo (project lines, sent together), causeOfAbsenceCode (absence lines), serviceOrderNo (service lines), workTypeCode (project and resource lines), description (at most 100 characters), chargeable (boolean) and hours (array of objects with date and quantity).', Comment = 'is-IS=Línur sem á að bæta við eða breyta, að hámarki 100. Hver lína er hlutur: lineNo (heiltala, slepptu til að bæta við línu), type (project, resource, absence eða service; nauðsynlegt fyrir nýja línu), projectNo og projectTaskNo (verklínur, send saman), causeOfAbsenceCode (fjarvistarlínur), serviceOrderNo (þjónustulínur), workTypeCode (verk- og auðlindalínur), description (að hámarki 100 stafir), chargeable (sanngildi) og hours (fylki hluta með date og quantity).';
        SubjectDescriptionLbl: Label 'The Business Central time sheet whose lines the request changes.', Comment = 'is-IS=Tímaskýrslan í Business Central sem beiðnin breytir línum á.';
        TargetDescriptionLbl: Label 'Time sheet number.', Comment = 'is-IS=Númer tímaskýrslu.';
        SuccessDescriptionLbl: Label 'Success.', Comment = 'is-IS=Tókst.';
        SheetDescriptionLbl: Label 'Time sheet number.', Comment = 'is-IS=Númer tímaskýrslu.';
        ResourceDescriptionLbl: Label 'Resource number of the time sheet.', Comment = 'is-IS=Númer auðlindar tímaskýrslunnar.';
        LinesDescriptionLbl: Label 'One object per requested line, in request order: lineNo, type, created, status, projectNo, projectTaskNo, causeOfAbsenceCode, serviceOrderNo, workTypeCode, description, chargeable, totalQuantity and hours (every day of the line after the write).', Comment = 'is-IS=Einn hlutur fyrir hverja línu í beiðninni, í sömu röð: lineNo, type, created, status, projectNo, projectTaskNo, causeOfAbsenceCode, serviceOrderNo, workTypeCode, description, chargeable, totalQuantity og hours (allir dagar línunnar eftir skráningu).';
        MissingMessageLbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingDescriptionLbl: Label 'The request omitted timeSheetNo, lines, a type for a new line, or a key the line type needs.', Comment = 'is-IS=Í beiðnina vantar timeSheetNo, lines, type fyrir nýja línu eða lykil sem tegund línunnar þarf.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeMessageLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er af röngu JSON-tagi.';
        TypeDescriptionLbl: Label 'A value was not the documented JSON type.', Comment = 'is-IS=Gildi var ekki af skráðu JSON-tagi.';
        TypeNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownMessageLbl: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownDescriptionLbl: Label 'Unknown keys are refused at every level, including inside lines and hours. Nothing is written.', Comment = 'is-IS=Óþekktum lyklum er hafnað á öllum stigum, líka innan lína og klukkustunda. Ekkert er skráð.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        IdentifierMessageLbl: Label 'The identifier does not match a record.', Comment = 'is-IS=Auðkennið passar ekki við færslu.';
        IdentifierDescriptionLbl: Label 'The time sheet, line, project, project task, cause of absence or service order was not found.', Comment = 'is-IS=Tímaskýrslan, línan, verkið, verkhlutinn, fjarvistarástæðan eða þjónustupöntunin fannst ekki.';
        IdentifierNextLbl: Label 'Use an identifier that exists.', Comment = 'is-IS=Notaðu auðkenni sem er til.';
        ConflictMessageLbl: Label 'The request names the same line more than once.', Comment = 'is-IS=Beiðnin nefnir sömu línu oftar en einu sinni.';
        ConflictDescriptionLbl: Label 'Two entries in lines have the same lineNo.', Comment = 'is-IS=Tvær færslur í lines hafa sama lineNo.';
        ConflictNextLbl: Label 'Send each lineNo once.', Comment = 'is-IS=Sendu hvert lineNo einu sinni.';
        InvalidMessageLbl: Label 'A value is not allowed for this line.', Comment = 'is-IS=Gildi er ekki leyft fyrir þessa línu.';
        InvalidDescriptionLbl: Label 'The type is unknown, a key does not belong to the line type, or the description is longer than 100 characters.', Comment = 'is-IS=Tegundin er óþekkt, lykill á ekki við tegund línunnar eða lýsingin er lengri en 100 stafir.';
        InvalidNextLbl: Label 'Use project, resource, absence or service, and send only the keys of that type.', Comment = 'is-IS=Notaðu project, resource, absence eða service og sendu aðeins lykla þeirrar tegundar.';
        HoursMessageLbl: Label 'Hours dates must be unique and inside the time sheet period, and hours cannot be negative.', Comment = 'is-IS=Dagsetningar klukkustunda verða að vera einstakar og innan tímabils tímaskýrslunnar og klukkustundir mega ekki vera neikvæðar.';
        HoursDescriptionLbl: Label 'A date is outside the time sheet, appears twice on one line, or has negative hours.', Comment = 'is-IS=Dagsetning er utan tímaskýrslunnar, birtist tvisvar á einni línu eða hefur neikvæðar klukkustundir.';
        HoursNextLbl: Label 'Send each date once, keep every date inside the time sheet period and use zero or more hours.', Comment = 'is-IS=Sendu hverja dagsetningu einu sinni, haltu öllum dagsetningum innan tímabils tímaskýrslunnar og notaðu núll eða fleiri klukkustundir.';
        LockedMessageLbl: Label 'The line is submitted or approved and cannot change.', Comment = 'is-IS=Línan hefur verið send inn eða samþykkt og er ekki hægt að breyta.';
        LockedDescriptionLbl: Label 'Only Open and Rejected lines change. Posted lines never change, the type of an existing line stays, assembly lines are not added here and absence needs a resource linked to an employee.', Comment = 'is-IS=Aðeins opnum og höfnuðum línum er breytt. Bókuðum línum er aldrei breytt, tegund línu sem er til helst, samsetningarlínum er ekki bætt við hér og fjarvist þarf auðlind sem er tengd starfsmanni.';
        LockedNextLbl: Label 'Reopen the line with Projects.TimeSheet.Reopen, then send the change again.', Comment = 'is-IS=Opnaðu línuna aftur með Projects.TimeSheet.Reopen og sendu svo breytinguna aftur.';
        LimitMessageLbl: Label 'The request has too many lines.', Comment = 'is-IS=Beiðnin hefur of margar línur.';
        LimitDescriptionLbl: Label 'More than 100 lines were sent in one call.', Comment = 'is-IS=Fleiri en 100 línur voru sendar í einu kalli.';
        LimitNextLbl: Label 'Send at most 100 lines per call.', Comment = 'is-IS=Sendu að hámarki 100 línur í hverju kalli.';
        PermissionMessageLbl: Label 'The caller cannot write time sheets.', Comment = 'is-IS=Kallandinn getur ekki skrifað tímaskýrslur.';
        PermissionDescriptionLbl: Label 'This type needs write access to time sheet lines and details.', Comment = 'is-IS=Þessi tegund þarf skrifheimild á línum og dögum tímaskýrslna.';
        PermissionNextLbl: Label 'Assign the BIFROST Full ori permission set.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunni BIFROST Full ori.';
        BcMessageLbl: Label 'Business Central rejected a line.', Comment = 'is-IS=Business Central hafnaði línu.';
        BcDescriptionLbl: Label 'A Business Central validation failed, for example a blocked project or resource or a closed accounting period. The whole call is rolled back.', Comment = 'is-IS=Prófun í Business Central mistókst, til dæmis lokað verk eða auðlind eða lokað reikningstímabil. Allt kallið er afturkallað.';
        BcNextLbl: Label 'Fix the line and send the call again.', Comment = 'is-IS=Lagfærðu línuna og sendu kallið aftur.';
        PermissionPreconditionLbl: Label 'The caller has the BIFROST Full ori permission set.', Comment = 'is-IS=Kallandinn hefur heimildasamstæðuna BIFROST Full ori.';
        StatusPreconditionLbl: Label 'Changed lines are Open or Rejected and not posted.', Comment = 'is-IS=Línur sem er breytt eru opnar eða hafnaðar og óbókaðar.';
        ChangesDescriptionLbl: Label 'Adds time sheet lines and changes Open or Rejected lines and their hours per day, all through Business Central validation. All lines of the call are committed together or not at all. Nothing is deleted: a day set to 0 keeps its row with zero hours.', Comment = 'is-IS=Bætir línum við tímaskýrslu og breytir opnum eða höfnuðum línum og klukkustundum þeirra eftir dögum, allt með prófunum Business Central. Allar línur kallsins eru staðfestar saman eða engar. Engu er eytt: dagur sem er settur á 0 heldur færslu sinni með núll klukkustundum.';
        RelatedSubmitLbl: Label 'Submit the lines for approval when they are complete.', Comment = 'is-IS=Sendu línurnar inn til samþykktar þegar þær eru tilbúnar.';
        RelatedReopenLbl: Label 'Reopen submitted or approved lines before you change them.', Comment = 'is-IS=Opnaðu innsendar eða samþykktar línur aftur áður en þú breytir þeim.';
        RelatedAbsenceLbl: Label 'Register a single absence line by cause and days.', Comment = 'is-IS=Skráðu staka fjarvistarlínu eftir ástæðu og dögum.';
        WorkflowStepDescriptionLbl: Label 'Add or change the lines and their hours per day.', Comment = 'is-IS=Bættu við eða breyttu línunum og klukkustundum þeirra eftir dögum.';
        WorkflowSubmitStepLbl: Label 'Submit the lines for approval.', Comment = 'is-IS=Sendu línurnar inn til samþykktar.';
        WorkflowDescriptionLbl: Label 'Read the time sheet lines, send the changes, then read the returned lines before the next call. Submitted or approved lines must be reopened first.', Comment = 'is-IS=Lestu línur tímaskýrslunnar, sendu breytingarnar og lestu svo línurnar sem var skilað fyrir næsta kall. Opna þarf innsendar eða samþykktar línur fyrst.';
        OverviewDescriptionLbl: Label 'Projects.TimeSheetLine.Set adds or changes time sheet lines (project, resource, absence or service) and their hours per day, like the lines and day columns of the Time Sheet page. Every value goes through Business Central validation. A refusal writes nothing.', Comment = 'is-IS=Projects.TimeSheetLine.Set bætir við eða breytir línum tímaskýrslu (verk, auðlind, fjarvist eða þjónusta) og klukkustundum þeirra eftir dögum, eins og línur og dagadálkar síðunnar Tímaskýrsla. Öll gildi fara í gegnum prófanir Business Central. Höfnun skráir ekkert.';
        NotesDescriptionLbl: Label 'Omit lineNo to add a line; send lineNo to change one. Only Open and Rejected lines change: reopen submitted or approved lines with Projects.TimeSheet.Reopen first. The type of an existing line cannot change. projectNo and projectTaskNo travel together because Business Central clears the task when the project changes. Hours are set per date; dates you do not send keep their hours, and 0 keeps the day with zero hours. A sent description replaces the one Business Central takes from the task or cause. Generic Data.Records.Set writes to time sheet lines and details are refused.', Comment = 'is-IS=Slepptu lineNo til að bæta við línu; sendu lineNo til að breyta línu. Aðeins opnum og höfnuðum línum er breytt: opnaðu innsendar eða samþykktar línur fyrst aftur með Projects.TimeSheet.Reopen. Ekki er hægt að breyta tegund línu sem er til. projectNo og projectTaskNo eru send saman því Business Central hreinsar verkhlutann þegar verkinu er breytt. Klukkustundir eru settar eftir dagsetningu; dagsetningar sem þú sendir ekki halda klukkustundum sínum og 0 heldur deginum með núll klukkustundum. Send lýsing kemur í stað lýsingarinnar sem Business Central tekur úr verkhluta eða ástæðu. Almennum Data.Records.Set skráningum á línur og daga tímaskýrslna er hafnað.';

    /// <summary>Declares the two request keys.</summary>
    procedure AddParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('timeSheetNo', 'string', true, SheetParameterLbl));
        Parameters.Add(ContractMgt.Parameter('lines', 'array', true, LinesParameterLbl));
        exit(true);
    end;

    /// <summary>Describes the supported task envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
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
        exit(true);
    end;

    /// <summary>Describes the time-sheet identifier.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.timeSheetNo', 'string', TargetDescriptionLbl));
        exit(true);
    end;

    /// <summary>Describes the lines returned on success.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', SuccessDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('timeSheetNo', 'string', SheetDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('resourceNo', 'string', ResourceDescriptionLbl));
        Fields.Add(ContractMgt.ResponseField('lines', 'array', LinesDescriptionLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists documented refusals and recovery steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingMessageLbl, MissingDescriptionLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, TypeMessageLbl, TypeDescriptionLbl, TypeNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownMessageLbl, UnknownDescriptionLbl, UnknownNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, IdentifierMessageLbl, IdentifierDescriptionLbl, IdentifierNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictMessageLbl, ConflictDescriptionLbl, ConflictNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidMessageLbl, InvalidDescriptionLbl, InvalidNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, HoursMessageLbl, HoursDescriptionLbl, HoursNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, LockedMessageLbl, LockedDescriptionLbl, LockedNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, LimitMessageLbl, LimitDescriptionLbl, LimitNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionMessageLbl, PermissionDescriptionLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, BcMessageLbl, BcDescriptionLbl, BcNextLbl));
        exit(true);
    end;

    /// <summary>Describes the committed write and required permissions.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add(PermissionPreconditionLbl);
        Preconditions.Add(StatusPreconditionLbl);
        Effect.Add('effect', 'write');
        Effect.Add('changes', ChangesDescriptionLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Lists related time-sheet messages.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Projects.TimeSheet.Submit', RelatedSubmitLbl));
        Related.Add(ContractMgt.RelatedEntry('Projects.TimeSheet.Reopen', RelatedReopenLbl));
        Related.Add(ContractMgt.RelatedEntry('Projects.Absence.Register', RelatedAbsenceLbl));
        exit(true);
    end;

    /// <summary>Describes the line maintenance workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep(TypeName(), WorkflowStepDescriptionLbl));
        Steps.Add(ContractMgt.WorkflowStep('Projects.TimeSheet.Submit', WorkflowSubmitStepLbl));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', WorkflowDescriptionLbl);
        exit(true);
    end;

    /// <summary>Provides a request and response example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(TypeName(),
            '{"type":"' + TypeName() + '","data":{"timeSheetNo":"TS0001","lines":[{"type":"project","projectNo":"J00010","projectTaskNo":"1010","description":"Design","hours":[{"date":"2026-06-01","quantity":8},{"date":"2026-06-02","quantity":6}]},{"lineNo":20000,"hours":[{"date":"2026-06-03","quantity":2}]}]}}',
            '{"status":"Success","timeSheetNo":"TS0001","resourceNo":"R0010","lines":[{"lineNo":30000,"type":"project","created":true,"status":"Open","projectNo":"J00010","projectTaskNo":"1010","causeOfAbsenceCode":"","serviceOrderNo":"","workTypeCode":"","description":"Design","chargeable":true,"totalQuantity":14,"hours":[{"date":"2026-06-01","quantity":8},{"date":"2026-06-02","quantity":6}]},{"lineNo":20000,"type":"resource","created":false,"status":"Open","projectNo":"","projectTaskNo":"","causeOfAbsenceCode":"","serviceOrderNo":"","workTypeCode":"","description":"Admin","chargeable":true,"totalQuantity":2,"hours":[{"date":"2026-06-03","quantity":2}]}]}'));
        exit(true);
    end;

    /// <summary>Returns the localized purpose of the message.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewDescriptionLbl;
        exit(true);
    end;

    /// <summary>Explains line selection, status rules and hours handling.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesDescriptionLbl;
        exit(true);
    end;

    local procedure TypeName(): Text
    begin
        exit('Projects.TimeSheetLine.Set');
    end;
}
