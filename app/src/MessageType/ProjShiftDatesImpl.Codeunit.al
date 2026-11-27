namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Shifts project planning dates through the native batch action (#76).</summary>
codeunit 70013417 "Proj. Shift Dates Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the company switch and the caller's native permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.PlanningLine.ShiftDates") then
            exit(false);
        exit(Gate.IsEnabled(Database::"Job Planning Line", true) and
            Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Task", false) and
            Gate.IsEnabled(Database::"Job Planning Line Invoice", false));
    end;

    /// <summary>Returns the native resource for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Planning Line");
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Shifts planning or currency dates for a project or task range and returns the old and new dates.', Comment = 'is-IS=Færir áætlunar- eða gjaldmiðilsdagsetningar verkefnis eða verkhlutabils og skilar gömlum og nýjum dagsetningum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, task, planning date, currency date, shift dates, replan, date formula, fixed date', Comment = 'is-IS=verkefni, verkhluti, áætlunardagsetning, gjaldmiðilsdagsetning, færa dagsetningar, enduráætla, dagsetningarformúla, föst dagsetning';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized operation selector.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares a write request.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the version-one data envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Declares the exact project selector.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'Exact project number.'));
        exit(true);
    end;

    /// <summary>Declares every accepted parameter; confirmation counts are not accepted.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Parameters.Add(Input.Parameter('projectNo', 'string', true, 'Exact project number.', 20));
        Parameters.Add(Input.Parameter('fromTaskNo', 'string', false, 'Inclusive first task number; must exist when supplied.', 20));
        Parameters.Add(Input.Parameter('toTaskNo', 'string', false, 'Inclusive last task number; must exist when supplied.', 20));
        Parameters.Add(Input.Parameter('dateField', 'string', false, 'planningDate (default), currencyDate or both. Currency dates also change document dates, as in Change Project Planning Line Dates.', 20));
        Parameters.Add(Input.Parameter('lineType', 'string', true, 'Budget, Billable or Both. Budget and Billable each include combined budget and billable lines; Both includes all line types.', 20));
        Parameters.Add(Input.Parameter('dateFormula', 'string', false, 'Culture-invariant date formula, for example +1W or -1M. Supply exactly one of dateFormula or fixedDate.', 100));
        Parameters.Add(Input.Parameter('fixedDate', 'date', false, 'ISO date (YYYY-MM-DD). Supply exactly one of fixedDate or dateFormula.', 10));
        Parameters.Add(Input.Parameter('includeFrom', 'date', false, 'Inclusive lower date bound, applied separately to each selected date field.', 10));
        Parameters.Add(Input.Parameter('includeTo', 'date', false, 'Inclusive upper date bound, applied separately to each selected date field.', 10));
        exit(true);
    end;

    /// <summary>Documents actual changes, including native document-date changes.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after all changes commit.'));
        Fields.Add(Contract.ResponseField('projectNo', 'string', 'Selected project.'));
        Fields.Add(Contract.ResponseField('changedLines', 'array', 'One entry per changed field: taskNo, lineNo, field (planningDate, currencyDate or documentDate), oldDate and newDate (ISO dates). Keep these values to restore exact original dates.'));
        Fields.Add(Contract.ResponseField('skipped', 'array', 'Empty on success. A transferred or invoiced line in the selected scope refuses the whole request.'));
        Fields.Add(Contract.ResponseField('summary', 'object', 'changedLineCount counts distinct planning lines; changedFieldCount counts returned field changes.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares stable refusals with English help and actionable steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required value or date option is missing.', 'Supply projectNo, lineType and exactly one date option.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Both date options were supplied.', 'Supply dateFormula or fixedDate, never both.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value, formula, date or range is invalid.', 'Use the declared values, ISO dates and an invariant date formula.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An unknown key was supplied.', 'Remove the unknown key; expectedCount is not used.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The project or a task boundary does not exist.', 'Select an existing project and task range.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The project is blocked for all activity, or a selected line has been transferred or invoiced.', 'Unblock the project or select a range without transferred or invoiced lines. Nothing changed.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required project permissions are missing.', 'Ask an administrator for the Bifrost Full role and permission to modify project planning lines.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Projects is disabled for the company.', 'Enable Projects in Projects Setup.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the date change; the entire batch rolled back.', 'Correct the Business Central error and retry.'));
        exit(true);
    end;

    /// <summary>Declares the approved plain write effect (20 November 2026 ruling).</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('changes', 'Planning dates, currency dates and related document dates. No posting. No expectedCount confirmation.');
        exit(true);
    end;

    /// <summary>Uses Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Names the single-line editing alternative.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.PlanningLine.Update', 'Change one planning line.'));
        exit(true);
    end;

    /// <summary>No additional workflow is needed.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a task-range example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Move task 1000 forward one week',
            '{"type":"Projects.PlanningLine.ShiftDates","data":{"projectNo":"PROJECT-001","fromTaskNo":"1000","toTaskNo":"1000","lineType":"Both","dateFormula":"+1W"}}',
            '{"status":"Success","projectNo":"PROJECT-001","changedLines":[{"taskNo":"1000","lineNo":10000,"field":"planningDate","oldDate":"2026-01-01","newDate":"2026-01-08"}],"skipped":[],"summary":{"changedLineCount":1,"changedFieldCount":1}}'));
        exit(true);
    end;

    /// <summary>Returns English help in every language.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Moves project planning dates as Change Project Planning Line Dates does, for a project or inclusive task range. Choose a date formula or a fixed date. No posting or confirmation count is required.';
        exit(true);
    end;

    /// <summary>Explains exact undo information and atomic refusal.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Keep every old date returned in changedLines to restore the exact previous values. A fixed date or month-end formula is not undone reliably by negating the formula. Currency-date changes also update document dates and may recalculate currency amounts. Date windows apply separately to the selected planning and currency dates. A transferred or invoiced line in that scope refuses the entire request. All native failures roll back the batch.';
        exit(true);
    end;

    /// <summary>Guards native rights, licensing and version before input and transactional writes.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Setup: Record "Projects Setup ori";
        Gate: Codeunit "Projects Gate ori";
        Input: Codeunit "Projects Followup Input ori";
        PermissionsLbl: Label 'Ask an administrator for the Bifrost Full role and permission to modify project planning lines.', Comment = 'is-IS=Biddu kerfisstjóra um fullt Bifrost-hlutverk og heimild til að breyta áætlunarlínum verkefna.';
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.PlanningLine.ShiftDates") then
            exit;
        if not Setup.IsEnabled() then begin
            Gate.AssertEnabled(Argument, Database::"Job Planning Line", true);
            exit;
        end;
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ShiftDates(Argument);
    end;

    /// <summary>Validates the request and invokes one rollback boundary, also used by isolated AL tests.</summary>
    internal procedure ShiftDates(var Argument: Record "Message Argument ori")
    var
        Input: Codeunit "Projects Followup Input ori";
        PeriodLength: DateFormula;
        Request: JsonObject;
        Parameters: JsonArray;
        FixedDate: Date;
        StartingDate: Date;
        EndingDate: Date;
        NativeStepLbl: Label 'Correct the Business Central error and retry. The entire date batch was rolled back.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur. Allar dagsetningarbreytingar voru afturkallaðar.';
    begin
        Request := Argument.GetRequestJson();
        GetParameters(Parameters);
        if not Input.Validate(Argument, Request, Parameters) then
            exit;
        if not ValidateOptions(Argument, Request, PeriodLength, FixedDate, StartingDate, EndingDate) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Shift Dates Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Shift Dates Process ori", Argument) then
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeStepLbl);
    end;

    /// <summary>Parses invariant options before any mutation.</summary>
    internal procedure ValidateOptions(var Argument: Record "Message Argument ori"; Request: JsonObject; var PeriodLength: DateFormula; var FixedDate: Date; var StartingDate: Date; var EndingDate: Date): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        FormulaText: Text;
        DateOptionLbl: Label 'Supply exactly one of dateFormula or fixedDate.', Comment = 'is-IS=Sendu nákvæmlega annað viðfangið dateFormula eða fixedDate.';
        FormatLbl: Label 'Use the declared values, ISO dates and a culture-invariant date formula such as +1W.', Comment = 'is-IS=Notaðu skilgreind gildi, ISO-dagsetningar og menningaróháða dagsetningarformúlu eins og +1W.';
        RangeLbl: Label 'The start of the range must not follow its end.', Comment = 'is-IS=Upphaf bilsins má ekki vera á eftir enda þess.';
    begin
        if Request.Contains('dateFormula') and Request.Contains('fixedDate') then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'dateFormula', DateOptionLbl));
        if not (Request.Contains('dateFormula') or Request.Contains('fixedDate')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'dateFormula', DateOptionLbl));
        if not (Request.GetText('lineType') in ['Budget', 'Billable', 'Both']) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'lineType', FormatLbl));
        if Request.Contains('dateField') then
            if not (Request.GetText('dateField') in ['planningDate', 'currencyDate', 'both']) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'dateField', FormatLbl));
        if Request.Contains('dateFormula') then begin
            FormulaText := Request.GetText('dateFormula').Trim();
            if FormulaText = '' then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'dateFormula', DateOptionLbl));
            if not FormulaText.StartsWith('<') then
                FormulaText := '<' + FormulaText + '>';
            if not Evaluate(PeriodLength, FormulaText, 9) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'dateFormula', FormatLbl));
        end;
        if Request.Contains('fixedDate') then
            Evaluate(FixedDate, Request.GetText('fixedDate'), 9);
        if Request.Contains('includeFrom') then
            Evaluate(StartingDate, Request.GetText('includeFrom'), 9);
        if Request.Contains('includeTo') then
            Evaluate(EndingDate, Request.GetText('includeTo'), 9);
        if (Request.Contains('fixedDate') and (FixedDate = 0D)) or
           (Request.Contains('includeFrom') and (StartingDate = 0D)) or
           (Request.Contains('includeTo') and (EndingDate = 0D)) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'date', FormatLbl));
        if EndingDate = 0D then
            EndingDate := DMY2Date(31, 12, 9999);
        if (EndingDate < StartingDate) or
           ((Input.TextValue(Request, 'fromTaskNo') <> '') and (Input.TextValue(Request, 'toTaskNo') <> '') and
            (UpperCase(Input.TextValue(Request, 'fromTaskNo')) > UpperCase(Input.TextValue(Request, 'toTaskNo')))) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'range', RangeLbl));
        exit(true);
    end;
}
