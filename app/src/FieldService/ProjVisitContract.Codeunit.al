namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Shared contract text for Projects.Visit.Start, Stop and Complete (projects#83).</summary>
codeunit 70013441 "Proj. Visit Contract ori"
{
    Access = Internal;

    var
        ProjectNoLbl: Label 'Project number, maximum 20 characters.', Comment = 'is-IS=Númer verkefnis, mest 20 stafir.';
        TaskNoLbl: Label 'Task number, maximum 20 characters.', Comment = 'is-IS=Númer verkþáttar, mest 20 stafir.';
        KindLbl: Label 'travel or work.', Comment = 'is-IS=travel eða work.';
        AtLbl: Label 'Client time as an ISO date and time. Omitted means now. A time older than the setup tolerance is refused.', Comment = 'is-IS=Tími biðlara á ISO sniði. Ef sleppt er notaður núverandi tími. Tími sem er eldri en vikmörk uppsetningar er hafnað.';
        AutoStopLbl: Label 'When true, stop the running visit before this one starts.', Comment = 'is-IS=Þegar satt, stöðva heimsóknina sem er í gangi áður en þessi hefst.';
        ClientRequestLbl: Label 'Repeat key, maximum 100 characters. The same key returns the first result and writes nothing new.', Comment = 'is-IS=Endurtekningarlykill, mest 100 stafir. Sami lykill skilar fyrstu niðurstöðu og skrifar ekkert nýtt.';
        VisitIdStopLbl: Label 'Visit number. Omitted means the running visit.', Comment = 'is-IS=Númer heimsóknar. Ef sleppt er heimsóknin sem er í gangi notuð.';
        VisitIdCompleteLbl: Label 'Visit number. Omit it only when projectNo and taskNo name the visit.', Comment = 'is-IS=Númer heimsóknar. Slepptu því aðeins þegar projectNo og taskNo nefna heimsóknina.';
        NoteLbl: Label 'Note stored on the visit, maximum 250 characters.', Comment = 'is-IS=Athugasemd sem vistuð er á heimsókninni, mest 250 stafir.';
        MileageLbl: Label 'Kilometres as a positive number. Omit it to skip mileage. A usage line stays open.', Comment = 'is-IS=Kílómetrar sem jákvæð tala. Slepptu henni til að sleppa akstri. Notkunarlína helst opin.';
        OutcomeLbl: Label 'Outcome text stored on the visit, maximum 250 characters.', Comment = 'is-IS=Niðurstaðatexti sem vistaður er á heimsókninni, mest 250 stafir.';
        CompleteProjectLbl: Label 'Project number. With visitId it must be that visit. With taskNo and no visitId it selects the visit.', Comment = 'is-IS=Númer verkefnis. Með visitId verður það að vera sú heimsókn. Með taskNo og án visitId velur það heimsóknina.';
        CompleteTaskLbl: Label 'Task number. With visitId it must be that visit. With projectNo and no visitId it selects the visit.', Comment = 'is-IS=Númer verkþáttar. Með visitId verður það að vera sú heimsókn. Með projectNo og án visitId velur það heimsóknina.';
        RefusedLbl: Label 'The visit request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um heimsókn.';
        PermissionLbl: Label 'The caller cannot record a visit.', Comment = 'is-IS=Kallandi getur ekki skráð heimsókn.';
        PermissionNextLbl: Label 'Assign BIFROST Read ori together with PROJ TS SELF and PROJ VISIT.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori ásamt PROJ TS SELF og PROJ VISIT.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        FormatNextLbl: Label 'Send the key with the documented type and range.', Comment = 'is-IS=Sendu lykilinn með skráðri tegund og bili.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundNextLbl: Label 'Use a project, task or visit that exists.', Comment = 'is-IS=Notaðu verkefni, verkþátt eða heimsókn sem er til.';
        ConflictNextLbl: Label 'Send the visitId of that project and task, or omit the project and task.', Comment = 'is-IS=Sendu visitId þess verkefnis og verkþáttar, eða slepptu verkefni og verkþætti.';
        UnmappedLbl: Label 'The caller is not the time sheet owner of a resource.', Comment = 'is-IS=Kallandi er ekki eigandi tímaskýrslu á forða.';
        UnmappedNextLbl: Label 'Ask an administrator to set you as the owner of your resource.', Comment = 'is-IS=Biddu stjórnanda að skrá þig sem eiganda forðans þíns.';
        ManyResourcesLbl: Label 'The caller owns more than one time sheet resource.', Comment = 'is-IS=Kallandi á fleiri en einn tímaskýrsluforða.';
        ManyResourcesNextLbl: Label 'Ask an administrator to leave one resource for field visits.', Comment = 'is-IS=Biddu stjórnanda að skilja einn forða eftir fyrir vettvangsheimsóknir.';
        RunningNextLbl: Label 'Stop the running visit with Projects.Visit.Stop, or send autoStop true.', Comment = 'is-IS=Stöðvaðu heimsóknina sem er í gangi með Projects.Visit.Stop, eða sendu autoStop true.';
        OldTimeNextLbl: Label 'Send an at time within the client time tolerance in Projects Setup.', Comment = 'is-IS=Sendu at tíma innan vikmarka biðlaratíma í uppsetningu verkefna.';
        NoSheetNextLbl: Label 'Create the week with Projects.MyTimeSheet.Create.', Comment = 'is-IS=Stofnaðu vikuna með Projects.MyTimeSheet.Create.';
        LockedLineNextLbl: Label 'Use an open or rejected line. Submitted and approved lines stay unchanged.', Comment = 'is-IS=Notaðu opna eða hafnaða línu. Innsendum og samþykktum línum er ekki breytt.';
        UnplannedNextLbl: Label 'Ask a planner to plan you on the task, or turn on Allow Unplanned Tasks in Projects Setup.', Comment = 'is-IS=Biddu skipuleggjanda að skipuleggja þig á verkþáttinn, eða kveiktu á Leyfa óáætlaða verkþætti í uppsetningu verkefna.';
        TravelSetupNextLbl: Label 'Set the travel work type in Projects Setup.', Comment = 'is-IS=Settu vinnutegund ferðar í uppsetningu verkefna.';
        MileageSetupNextLbl: Label 'Set the mileage resource in Projects Setup.', Comment = 'is-IS=Settu akstursforðann í uppsetningu verkefna.';
        NotRunningLbl: Label 'The visit is not running.', Comment = 'is-IS=Heimsóknin er ekki í gangi.';
        NotRunningNextLbl: Label 'Start a visit, or complete one that is already stopped.', Comment = 'is-IS=Byrjaðu heimsókn, eða ljúktu heimsókn sem er þegar stöðvuð.';
        BeforeStartLbl: Label 'The stop time is before the visit started.', Comment = 'is-IS=Stöðvunartíminn er á undan upphafi heimsóknar.';
        BeforeStartNextLbl: Label 'Send an at time at or after the start.', Comment = 'is-IS=Sendu at tíma á eða eftir upphafi.';
        TooManyHoursNextLbl: Label 'Split the visit so the day stays at 24 hours or less.', Comment = 'is-IS=Skiptu heimsókninni svo dagurinn haldist í 24 stundum eða minna.';
        AlreadyDoneLbl: Label 'The visit is already completed.', Comment = 'is-IS=Heimsókninni er þegar lokið.';
        AlreadyDoneNextLbl: Label 'Start a new visit for more time.', Comment = 'is-IS=Byrjaðu nýja heimsókn fyrir fleiri tíma.';
        OtherVisitLbl: Label 'The visit belongs to another technician.', Comment = 'is-IS=Heimsóknin tilheyrir öðrum tæknimanni.';
        OtherVisitNextLbl: Label 'Use a visit of your own resource.', Comment = 'is-IS=Notaðu heimsókn á þínum eigin forða.';
        IsolatedLbl: Label 'This operation requires an isolated transaction.', Comment = 'is-IS=Þessi aðgerð krefst einangraðrar færslu.';
        IsolatedNextLbl: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        RetryNextLbl: Label 'Correct the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur. Engu var breytt.';
        NoIdentifierLbl: Label 'Send visitId, or both projectNo and taskNo.', Comment = 'is-IS=Sendu visitId, eða bæði projectNo og taskNo.';
        TravelSummaryLbl: Label 'Travel started on project %1, task %2.', Comment = '%1 = project no.; %2 = task no.; is-IS=Ferð hófst á verkefni %1, verkþætti %2.';
        WorkSummaryLbl: Label 'Work started on project %1, task %2.', Comment = '%1 = project no.; %2 = task no.; is-IS=Vinna hófst á verkefni %1, verkþætti %2.';
        StopSummaryLbl: Label '%1 hours written on %2.', Comment = '%1 = hours; %2 = date; is-IS=%1 stundir skrifaðar þann %2.';
        CompleteSummaryLbl: Label 'Visit %1 completed.', Comment = '%1 = visit no.; is-IS=Heimsókn %1 lokið.';
        MileageSummaryLbl: Label ' Mileage %1.', Comment = '%1 = kilometres; is-IS= Akstur %1.';
        StatusLbl: Label 'Success or Error.', Comment = 'is-IS=Success eða Error.';
        VisitIdRespLbl: Label 'The visit number.', Comment = 'is-IS=Númer heimsóknarinnar.';
        StartedRespLbl: Label 'When the visit started.', Comment = 'is-IS=Hvenær heimsóknin hófst.';
        StoppedRespLbl: Label 'The visit that autoStop stopped, when one was running.', Comment = 'is-IS=Heimsóknin sem autoStop stöðvaði, þegar ein var í gangi.';
        SummaryRespLbl: Label 'A short sentence about what was written.', Comment = 'is-IS=Stutt setning um það sem var skrifað.';
        HoursRespLbl: Label 'Rounded hours added for this visit.', Comment = 'is-IS=Námundaðar stundir sem bættust við fyrir þessa heimsókn.';
        SheetRespLbl: Label 'The time sheet that received the hours.', Comment = 'is-IS=Tímaskýrslan sem fékk stundirnar.';
        LineRespLbl: Label 'The time sheet line that received the hours.', Comment = 'is-IS=Lína tímaskýrslunnar sem fékk stundirnar.';
        DayRespLbl: Label 'The day the hours were added to.', Comment = 'is-IS=Dagurinn sem stundunum var bætt við.';
        NextRespLbl: Label 'What the caller can do next.', Comment = 'is-IS=Það sem kallandi getur gert næst.';
        VisitRespLbl: Label 'The completed visit.', Comment = 'is-IS=Heimsókninni sem lauk.';
        UsageRespLbl: Label 'The open usage line for mileage, when mileageKm was sent.', Comment = 'is-IS=Opna notkunarlína aksturs, þegar mileageKm var sent.';

    /// <summary>Declares the Start request keys.</summary>
    procedure AddStartParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('projectNo', 'string', true, ProjectNoLbl));
        Parameters.Add(Contract.Parameter('taskNo', 'string', true, TaskNoLbl));
        Parameters.Add(Contract.Parameter('kind', 'string', true, KindLbl));
        Parameters.Add(Contract.Parameter('at', 'string', false, AtLbl));
        Parameters.Add(Contract.Parameter('autoStop', 'boolean', false, AutoStopLbl));
        Parameters.Add(Contract.Parameter('clientRequestId', 'string', false, ClientRequestLbl));
    end;

    /// <summary>Declares the Stop request keys.</summary>
    procedure AddStopParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('visitId', 'integer', false, VisitIdStopLbl));
        Parameters.Add(Contract.Parameter('at', 'string', false, AtLbl));
        Parameters.Add(Contract.Parameter('note', 'string', false, NoteLbl));
        Parameters.Add(Contract.Parameter('clientRequestId', 'string', false, ClientRequestLbl));
    end;

    /// <summary>Declares the Complete request keys.</summary>
    procedure AddCompleteParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('visitId', 'integer', false, VisitIdCompleteLbl));
        Parameters.Add(Contract.Parameter('projectNo', 'string', false, CompleteProjectLbl));
        Parameters.Add(Contract.Parameter('taskNo', 'string', false, CompleteTaskLbl));
        Parameters.Add(Contract.Parameter('mileageKm', 'number', false, MileageLbl));
        Parameters.Add(Contract.Parameter('outcome', 'string', false, OutcomeLbl));
        Parameters.Add(Contract.Parameter('clientRequestId', 'string', false, ClientRequestLbl));
    end;

    /// <summary>Documents the shared refusals.</summary>
    procedure AddErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, NotFoundNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, RunningNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, RetryNextLbl));
    end;

    /// <summary>Documents the Start response.</summary>
    procedure AddStartResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('visitId', 'integer', VisitIdRespLbl));
        Fields.Add(Contract.ResponseField('startedAt', 'string', StartedRespLbl));
        Fields.Add(Contract.ResponseField('stopped', 'object', StoppedRespLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryRespLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents the Stop response.</summary>
    procedure AddStopResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('visitId', 'integer', VisitIdRespLbl));
        Fields.Add(Contract.ResponseField('hours', 'number', HoursRespLbl));
        Fields.Add(Contract.ResponseField('timeSheetNo', 'string', SheetRespLbl));
        Fields.Add(Contract.ResponseField('timeSheetLineNo', 'integer', LineRespLbl));
        Fields.Add(Contract.ResponseField('day', 'string', DayRespLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryRespLbl));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', NextRespLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents the Complete response.</summary>
    procedure AddCompleteResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('visit', 'object', VisitRespLbl));
        Fields.Add(Contract.ResponseField('usageEntryNo', 'integer', UsageRespLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryRespLbl));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', NextRespLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    procedure RefusedText(): Text
    begin
        exit(RefusedLbl);
    end;

    procedure PermissionText(): Text
    begin
        exit(PermissionLbl);
    end;

    procedure PermissionNext(): Text
    begin
        exit(PermissionNextLbl);
    end;

    procedure MissingNext(): Text
    begin
        exit(MissingNextLbl);
    end;

    procedure FormatNext(): Text
    begin
        exit(FormatNextLbl);
    end;

    procedure UnknownNext(): Text
    begin
        exit(UnknownNextLbl);
    end;

    procedure NotFoundNext(): Text
    begin
        exit(NotFoundNextLbl);
    end;

    procedure ConflictNext(): Text
    begin
        exit(ConflictNextLbl);
    end;

    procedure UnmappedText(): Text
    begin
        exit(UnmappedLbl);
    end;

    procedure UnmappedNext(): Text
    begin
        exit(UnmappedNextLbl);
    end;

    procedure ManyResourcesText(): Text
    begin
        exit(ManyResourcesLbl);
    end;

    procedure ManyResourcesNext(): Text
    begin
        exit(ManyResourcesNextLbl);
    end;

    procedure RunningNext(): Text
    begin
        exit(RunningNextLbl);
    end;

    procedure OldTimeNext(): Text
    begin
        exit(OldTimeNextLbl);
    end;

    procedure NoSheetNext(): Text
    begin
        exit(NoSheetNextLbl);
    end;

    procedure LockedLineNext(): Text
    begin
        exit(LockedLineNextLbl);
    end;

    procedure UnplannedNext(): Text
    begin
        exit(UnplannedNextLbl);
    end;

    procedure TravelSetupNext(): Text
    begin
        exit(TravelSetupNextLbl);
    end;

    procedure MileageSetupNext(): Text
    begin
        exit(MileageSetupNextLbl);
    end;

    procedure NotRunningText(): Text
    begin
        exit(NotRunningLbl);
    end;

    procedure NotRunningNext(): Text
    begin
        exit(NotRunningNextLbl);
    end;

    procedure BeforeStartText(): Text
    begin
        exit(BeforeStartLbl);
    end;

    procedure BeforeStartNext(): Text
    begin
        exit(BeforeStartNextLbl);
    end;

    procedure TooManyHoursNext(): Text
    begin
        exit(TooManyHoursNextLbl);
    end;

    procedure AlreadyDoneText(): Text
    begin
        exit(AlreadyDoneLbl);
    end;

    procedure AlreadyDoneNext(): Text
    begin
        exit(AlreadyDoneNextLbl);
    end;

    procedure OtherVisitText(): Text
    begin
        exit(OtherVisitLbl);
    end;

    procedure OtherVisitNext(): Text
    begin
        exit(OtherVisitNextLbl);
    end;

    procedure IsolatedText(): Text
    begin
        exit(IsolatedLbl);
    end;

    procedure IsolatedNext(): Text
    begin
        exit(IsolatedNextLbl);
    end;

    procedure RetryNext(): Text
    begin
        exit(RetryNextLbl);
    end;

    procedure NoIdentifierText(): Text
    begin
        exit(NoIdentifierLbl);
    end;

    procedure TravelSummary(ProjectNo: Code[20]; TaskNo: Code[20]): Text
    begin
        exit(StrSubstNo(TravelSummaryLbl, ProjectNo, TaskNo));
    end;

    procedure WorkSummary(ProjectNo: Code[20]; TaskNo: Code[20]): Text
    begin
        exit(StrSubstNo(WorkSummaryLbl, ProjectNo, TaskNo));
    end;

    procedure StopSummary(Hours: Decimal; Day: Date): Text
    begin
        exit(StrSubstNo(StopSummaryLbl, Hours, Day));
    end;

    procedure CompleteSummary(VisitId: Integer; Mileage: Decimal; HasMileage: Boolean): Text
    begin
        if HasMileage then
            exit(StrSubstNo(CompleteSummaryLbl, VisitId) + StrSubstNo(MileageSummaryLbl, Mileage));
        exit(StrSubstNo(CompleteSummaryLbl, VisitId));
    end;
}
