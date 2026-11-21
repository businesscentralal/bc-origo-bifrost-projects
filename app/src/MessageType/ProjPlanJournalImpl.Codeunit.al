namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Creates linked project journal lines from selected budget planning lines.</summary>
codeunit 70013427 "Proj. Plan Journal Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionLbl: Label 'Ask an administrator for the Bifrost Full role, project read rights, planning line modify rights and project journal line insert rights.', Comment = 'is-IS=Biddu kerfisstjóra um Bifrost Full hlutverkið, lesheimildir fyrir verkefni, breytingarheimildir fyrir áætlunarlínur og stofnheimildir fyrir verkbókarlínur.';
        FindLbl: Label 'Choose an existing project, posting task, planning line, journal template and batch.', Comment = 'is-IS=Veldu fyrirliggjandi verkefni, bókunarverkhluta, áætlunarlínu, bókarsniðmát og bókarkeyrslu.';
        BudgetLbl: Label 'Choose a budget resource, item or account line on an open, unblocked project with positive remaining quantity.', Comment = 'is-IS=Veldu fjárhagsáætlunarlínu fyrir forða, vöru eða reikning á opnu, ólokuðu verkefni með jákvæðu eftirstandandi magni.';
        QuantityLbl: Label 'Use a positive quantity no greater than the planning line remaining quantity.', Comment = 'is-IS=Notaðu jákvætt magn sem er ekki meira en eftirstandandi magn áætlunarlínunnar.';
        FormatLbl: Label 'Send the documented parameters and at least one unique task and planning line pair.', Comment = 'is-IS=Sendu skjalfest viðföng og að minnsta kosti eitt einkvæmt par verkhluta og áætlunarlínu.';
        NativeLbl: Label 'Correct the planning line or journal setup and retry. Nothing was transferred.', Comment = 'is-IS=Leiðréttu áætlunarlínuna eða uppsetningu verkbókar og reyndu aftur. Ekkert var flutt.';

    /// <summary>Checks the company switch, feature role and caller-owned native rights.</summary>
    procedure IsEnabled(): Boolean
    var
        FullRole: Record "Proj. Posting ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(FullRole.WritePermission() and Gate.IsEnabled(Database::Job, false) and
            Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::"Job Planning Line", true) and
            Gate.IsEnabled(Database::"Job Journal Line", true) and Gate.IsEnabled(Database::"Job Journal Template", false) and
            Gate.IsEnabled(Database::"Job Journal Batch", false));
    end;

    /// <summary>Returns the discovery filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Planning Line");
    end;

    /// <summary>Returns localized discovery guidance.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates linked project journal lines from selected budget planning lines without posting or changing existing journal lines.', Comment = 'is-IS=Stofnar tengdar verkbókarlínur úr völdum fjárhagsáætlunarlínum án bókunar eða breytinga á fyrirliggjandi verkbókarlínum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, planning line, journal, transfer, budget, usage link', Comment = 'is-IS=verkefni, áætlunarlína, verkbók, flytja, fjárhagsáætlun, notkunartenging';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares an inbound request.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares a version-one data envelope.</summary>
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

    /// <summary>Identifies the project and destination journal.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.projectNo', 'project number', 'Existing open project.'));
        Target.Add(Contract.TargetEntry('data.templateName, data.batchName', 'journal template and batch', 'Existing destination project journal.'));
        exit(true);
    end;

    /// <summary>Declares the complete request and selected-line schema.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        Lines: JsonObject;
    begin
        Parameters.Add(Input.Parameter('projectNo', 'string', true, 'Existing project, up to 20 characters.', 20));
        Lines := Input.Parameter('planningLines', 'array', true, 'Nonempty array of unique taskNo and lineNo pairs, with optional quantity.', 0);
        Lines.Add('children', LineParameters());
        Parameters.Add(Lines);
        Parameters.Add(Input.Parameter('templateName', 'string', true, 'Existing project journal template.', 10));
        Parameters.Add(Input.Parameter('batchName', 'string', true, 'Existing batch in the specified template.', 10));
        Parameters.Add(Input.Parameter('postingDate', 'date', true, 'Posting date in YYYY-MM-DD form.', 0));
        exit(true);
    end;

    local procedure LineParameters() Parameters: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Parameters.Add(Input.Parameter('taskNo', 'string', true, 'Existing posting task.', 20));
        Parameters.Add(Input.Parameter('lineNo', 'integer', true, 'Positive planning line number.', 0));
        Parameters.Add(Input.Parameter('quantity', 'number', false, 'Positive quantity no greater than remaining; omitted uses remaining quantity.', 0));
    end;

    /// <summary>Describes the created journal lines and next actions.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after all selected lines transfer.'));
        Fields.Add(Contract.ResponseField('journalLines', 'array', 'lineNo, type, no, quantity, taskNo and planningLineNo for each created line.'));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', 'Projects.ProjectJournal.Check and Projects.ProjectJournal.Post.'));
        Fields.Add(Contract.ResponseField('summary', 'object', 'journalLineCount, templateName and batchName.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares localized refusals and recovery guidance.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        RefusedLbl: Label 'The planning line transfer was refused; no journal lines were created.', Comment = 'is-IS=Flutningi áætlunarlína var hafnað; engar verkbókarlínur voru stofnaðar.';
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, FindLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, BudgetLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionLbl));
        exit(true);
    end;

    /// <summary>Declares the append-only, nonposting write effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('changes', 'Enables Usage Link and sets the transfer quantity on selected planning lines, then appends linked project journal lines. Never clears, changes or posts existing journal lines.');
        exit(true);
    end;

    /// <summary>Uses Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Names checking, posting and related usage operations.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.ProjectJournal.Check', 'Check the created journal lines before posting.'));
        Related.Add(Contract.RelatedEntry('Projects.ProjectJournal.Post', 'Post the checked journal to record project usage.'));
        Related.Add(Contract.RelatedEntry('Projects.ItemUsage.Post', 'Post item usage directly.'));
        Related.Add(Contract.RelatedEntry('Projects.Usage.Transfer', 'Transfer approved time-sheet usage.'));
        Related.Add(Contract.RelatedEntry('Projects.Usage.Link', 'Link already posted usage.'));
        exit(true);
    end;

    /// <summary>Explains the journal workflow in English.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow.Add('steps', 'Create the journal lines, check the journal, review it, then post it to record usage against the planning lines.');
        exit(true);
    end;

    /// <summary>Provides a partial transfer example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Create linked project journal lines',
            '{"type":"Projects.PlanningLine.TransferToJournal","data":{"projectNo":"PROJECT-001","planningLines":[{"taskNo":"1000","lineNo":10000,"quantity":2}],"templateName":"PROJECT","batchName":"DEFAULT","postingDate":"2026-11-21"}}',
            '{"status":"Success","journalLines":[{"lineNo":10000,"type":"Resource","no":"RESOURCE-001","quantity":2,"taskNo":"1000","planningLineNo":10000}],"nextSteps":["Projects.ProjectJournal.Check","Projects.ProjectJournal.Post"],"summary":{"journalLineCount":1,"templateName":"PROJECT","batchName":"DEFAULT"}}'));
        exit(true);
    end;

    /// <summary>Provides an English-only overview in every language.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use Create Project Journal Lines for selected budget planning lines. It enables Usage Link, copies native prices and item tracking, and appends linked journal lines. Nothing is posted. Check the journal next, then post it to record usage and reduce the planning lines remaining quantity.';
        exit(true);
    end;

    /// <summary>Explains validation and append semantics in user terms.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Select each task and planning line once. Omit quantity to use its remaining quantity, or send a positive partial quantity. Billable-only lines, text lines, blocked or non-open projects and excess quantities are refused. The whole request succeeds or nothing changes. Existing journal lines are never changed or cleared. Repeating a successful request adds more lines: check the journal before retrying. Native project read, planning line modify and journal line insert permissions are required together with the Bifrost Full role.';
        exit(true);
    end;

    /// <summary>Checks native permissions before Foundation licensing and version checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        if not AssertPermissions(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Execute(Argument);
    end;

    /// <summary>Validates and runs one rollback boundary without a posting gate.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Reason: Text;
        ErrorCode: Text;
    begin
        if not AssertPermissions(Argument) then
            exit;
        if not Validate(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Plan Journal Proc ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Plan Journal Proc ori", Argument) then begin
            Reason := GetLastErrorText();
            ErrorCode := GetLastErrorCode();
            ClearLastError();
            if ErrorCode.Contains('Permission') then
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, Reason, '', '', '', PermissionLbl)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, Reason, '', '', '', NativeLbl);
        end;
    end;

    local procedure AssertPermissions(var Argument: Record "Message Argument ori"): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        if IsEnabled() then
            exit(true);
        exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl));
    end;

    /// <summary>Revalidates all business preconditions inside the write boundary as well.</summary>
    internal procedure Validate(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject): Boolean
    var
        Project: Record Job;
        Task: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        JournalTemplate: Record "Job Journal Template";
        Batch: Record "Job Journal Batch";
        Input: Codeunit "Projects Followup Input ori";
        Parameters: JsonArray;
        Entry: JsonToken;
        ProjectToken: JsonToken;
        Line: JsonObject;
        Selected: List of [Text];
        SelectionKey: Text;
        Quantity: Decimal;
    begin
        if not TryReadRequest(Argument, RequestJson) then begin
            ClearLastError();
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'data', FormatLbl));
        end;
        GetParameters(Parameters);
        if not Input.Validate(Argument, RequestJson, Parameters) then
            exit(false);
        if RequestJson.GetArray('planningLines').Count() = 0 then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLines', FormatLbl));
        foreach Entry in RequestJson.GetArray('planningLines') do begin
            if not Entry.IsObject() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLines', FormatLbl));
            Line := Entry.AsObject();
            if not Input.Validate(Argument, Line, LineParameters()) then
                exit(false);
            if Line.GetInteger('lineNo') = 0 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'lineNo', FormatLbl));
            SelectionKey := UpperCase(Line.GetText('taskNo')) + ':' + Format(Line.GetInteger('lineNo'), 0, 9);
            if Selected.Contains(SelectionKey) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLines', FormatLbl));
            Selected.Add(SelectionKey);
        end;
        RequestJson.Get('projectNo', ProjectToken);
        if not Project.Get(ProjectToken.AsValue().AsText()) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', FindLbl));
        if not JournalTemplate.Get(RequestJson.GetText('templateName')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'templateName', FindLbl));
        if not Batch.Get(JournalTemplate.Name, RequestJson.GetText('batchName')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'batchName', FindLbl));
        if (Project.Blocked <> Project.Blocked::" ") or (Project.Status <> Project.Status::Open) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', BudgetLbl));
        foreach Entry in RequestJson.GetArray('planningLines') do begin
            Line := Entry.AsObject();
            if not Task.Get(Project."No.", Line.GetText('taskNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', FindLbl));
            if not PlanningLine.Get(Project."No.", Task."Job Task No.", Line.GetInteger('lineNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'lineNo', FindLbl));
            if (Task."Job Task Type" <> Task."Job Task Type"::Posting) or
                (PlanningLine."Line Type" = PlanningLine."Line Type"::Billable) or (PlanningLine.Type = PlanningLine.Type::Text)
            then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'planningLines', BudgetLbl));
            Quantity := PlanningLine."Remaining Qty.";
            if Line.Contains('quantity') then
                Quantity := Line.GetDecimal('quantity');
            if (Quantity <= 0) or (Quantity > PlanningLine."Remaining Qty.") then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'quantity', QuantityLbl));
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var RequestJson: JsonObject)
    begin
        RequestJson := Argument.GetRequestJson();
    end;
}
