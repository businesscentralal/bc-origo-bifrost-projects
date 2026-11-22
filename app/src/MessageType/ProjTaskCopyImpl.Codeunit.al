namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Implements the version 1 Projects.Task.CopyFrom contract.</summary>
codeunit 70013425 "Proj. Task Copy Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori", "Msg Confirm ori"
{
    Access = Internal;
    /// <summary>Requires the feature Full role and the caller's native project permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        FullRole: Record "Proj. Posting ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(FullRole.WritePermission() and Gate.IsEnabled(Database::Job, false) and
            Gate.IsEnabled(Database::"Job Task", true) and Gate.IsEnabled(Database::"Job Planning Line", true));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Task");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Copies tasks and planning lines into an existing project without replacing existing tasks.', Comment = 'is-IS=Afritar verkhluta og áætlunarlínur í fyrirliggjandi verkefni án þess að skipta út verkhlutum.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, task, copy, planning lines, posted usage, existing project', Comment = 'is-IS=verkefni, verkhluti, afrita, áætlunarlínur, bókuð notkun, fyrirliggjandi verkefni';
    begin
        exit(KeywordsLbl);
    end;
    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;
    /// <summary>Declares the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;
    /// <summary>Declares the data-only version 1 envelope.</summary>
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
    /// <summary>Declares the target keys.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.sourceProjectNo', 'sourceProjectNo', 'Existing source project.'));
        Target.Add(Contract.TargetEntry('data.targetProjectNo', 'targetProjectNo', 'Existing target project.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Parameters.Add(Input.Parameter('sourceProjectNo', 'string', true, 'Existing source project, up to 20 characters.', 20));
        Parameters.Add(Input.Parameter('targetProjectNo', 'string', true, 'Existing target project, different from the source.', 20));
        Parameters.Add(Input.Parameter('fromTaskNo', 'string', false, 'Inclusive lower task number; omitted means no lower bound.', 20));
        Parameters.Add(Input.Parameter('toTaskNo', 'string', false, 'Inclusive upper task number; omitted means no upper bound.', 20));
        Parameters.Add(Input.Parameter('source', 'string', false, 'planningLines (default) or ledgerEntries.', 0));
        Parameters.Add(Input.Parameter('planningLineType', 'string', false, 'Budget, Billable or Both (default); filters planningLines only.', 0));
        Parameters.Add(Input.Parameter('ledgerEntryType', 'string', false, 'Usage (default) or Sale; only valid with ledgerEntries.', 0));
        Parameters.Add(Input.Parameter('copyQuantity', 'boolean', false, 'Copy quantities; default true.', 0));
        Parameters.Add(Input.Parameter('copyPrices', 'boolean', false, 'Copy prices; default true, with native ledger conversion rules.', 0));
        Parameters.Add(Input.Parameter('copyDimensions', 'boolean', false, 'Copy task dimensions; default true.', 0));
        Parameters.Add(Input.Parameter('expectedCount', 'integer', false, 'Accepted and ignored: no confirmation is asked.', 0));
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.Parameter('status', 'string', true, 'Success after the complete copy.'));
        Fields.Add(Contract.Parameter('sourceProjectNo', 'string', true, 'Source project number.'));
        Fields.Add(Contract.Parameter('targetProjectNo', 'string', true, 'Existing target project number.'));
        Fields.Add(Contract.Parameter('copiedTasks', 'array', true, 'Each copied task: taskNo and planningLines count, in task number order.'));
        Fields.Add(Contract.Parameter('copiedPlanningLines', 'integer', true, 'Total planning lines created.'));
        Fields.Add(Contract.Parameter('summary', 'object', true, 'taskCount and planningLineCount.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;
    /// <summary>Declares contract and native validation failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'The project task copy could not be completed.', 'Send sourceProjectNo and targetProjectNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The project task copy could not be completed.', 'Use the option values and parameter types listed in the help.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The project task copy could not be completed.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The project task copy could not be completed.', 'Choose two existing projects.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'The project task copy could not be completed.', 'Choose different projects and a task range with no task numbers already in the target.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The project task copy could not be completed.', 'Use an open target project that is not blocked for all activity; correct the native validation issue.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The project task copy could not be completed.', 'Ask an administrator for BIFROST Full ori and native project task and planning line insert permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'The project task copy could not be completed.', 'Repeat the request with expectedCount from the preview.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'The project task copy could not be completed.', 'Review the preview and send its current expectedCount.'));
        exit(true);
    end;
    /// <summary>Documents transactional native writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Adds tasks and planning lines to an existing project; expectedCount is accepted and ignored.');
        Effect.Add('idempotent', false);
        exit(true);
    end;
    /// <summary>No additional app-specific meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>Links to the new-target copy and task indentation operations.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.Project.Copy', 'Copy into a new project instead.'));
        Related.Add(Contract.RelatedEntry('Projects.Task.Indent', 'Recalculate totaling after copying a complete task structure.'));
        exit(true);
    end;
    /// <summary>No additional workflow chapter is declared.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>Provides a minimal request example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Request: JsonObject;
    begin
        Request.Add('sourceProjectNo', 'PROJECT-001');
        Request.Add('targetProjectNo', 'PROJECT-002');
        Request.Add('fromTaskNo', '1000');
        Request.Add('toTaskNo', '1999');
        Example.Add('data', Request);
        Examples.Add(Example);
        exit(true);
    end;
    /// <summary>Provides the English-only operation overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use Copy Project Tasks from an existing source into an existing target. Copies the selected tasks and their planning lines, or creates planning lines from posted project entries. The target must already exist. For a new target use Projects.Project.Copy.';
        exit(true);
    end;
    /// <summary>Documents the English-only copy options and confirmation behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'expectedCount is accepted and ignored; the copy runs at once. Task bounds are inclusive and may be omitted. Any task number already in the target refuses the entire copy; nothing is overwritten or deleted. Completed targets and targets blocked for all activity are refused. Quantity, price and dimension defaults are true. Both includes every planning line type; ledgerEntries defaults to Usage and follows native posted-entry conversion. A native failure rolls back all tasks and lines. Requires BIFROST Full ori plus native project read, task and planning line insert rights; ledgerEntries also requires posted project entry read rights.';
        exit(true);
    end;
    /// <summary>Checks caller permissions before licensing and validation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        if not AssertPermissions(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Execute(Argument);
    end;

    /// <summary>Runs the validated operation in one native rollback boundary.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Count: Integer;
        Summary: Text;
        Reason: Text;
        ErrorCode: Text;
        NativeLbl: Label 'Correct the project task copy options and native validation issue, then retry. Nothing was copied.', Comment = 'is-IS=Leiðréttu afritunarvalkosti verkhluta og innbyggða villu og reyndu aftur. Ekkert var afritað.';
    begin
        if not GetConfirmCount(Argument, Count, Summary) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Task Copy Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Task Copy Process ori", Argument) then begin
            Reason := GetLastErrorText();
            ErrorCode := GetLastErrorCode();
            ClearLastError();
            if ErrorCode.Contains('Permission') then
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, Reason, '', '', '', PermissionNextLbl)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, Reason, '', '', '', NativeLbl);
        end;
    end;

    /// <summary>Validates and counts the source tasks without writing business data.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        SourceProject: Record Job;
        TargetProject: Record Job;
        Task: Record "Job Task";
        Request: JsonObject;
    begin
        Summary := CountLbl;
        Count := 0;
        if not AssertPermissions(Argument) then
            exit(false);
        if not Validate(Argument, Request, SourceProject, TargetProject, Task) then
            exit(false);
        Count := Task.Count();
        exit(true);
    end;

    local procedure AssertPermissions(var Argument: Record "Message Argument ori"): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        if IsEnabled() then
            exit(true);
        exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionNextLbl));
    end;

    local procedure Validate(var Argument: Record "Message Argument ori"; var Request: JsonObject; var SourceProject: Record Job; var TargetProject: Record Job; var Task: Record "Job Task"): Boolean
    var
        ExistingTask: Record "Job Task";
        Entry: Record "Job Ledger Entry";
        Input: Codeunit "Projects Followup Input ori";
        Parameters: JsonArray;
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
        SourceNo: Code[20];
        TargetNo: Code[20];
        FromNo: Code[20];
        ToNo: Code[20];
        Conflicts: Text;
        FormatLbl: Label 'Send a JSON object with the documented keys, types and options.', Comment = 'is-IS=Sendu JSON-hlut með skjalfestum lyklum, gagnategundum og valkostum.';
        FindLbl: Label 'Choose existing source and target projects.', Comment = 'is-IS=Veldu fyrirliggjandi uppruna- og markverkefni.';
        DifferentLbl: Label 'Choose a target project different from the source project.', Comment = 'is-IS=Veldu annað markverkefni en upprunaverkefnið.';
        RangeLbl: Label 'Use a fromTaskNo that does not exceed toTaskNo.', Comment = 'is-IS=Notaðu fromTaskNo sem er ekki hærra en toTaskNo.';
        OpenLbl: Label 'Use a target project that is not completed or blocked for all activity.', Comment = 'is-IS=Notaðu markverkefni sem er hvorki lokið né lokað fyrir allar aðgerðir.';
        CollisionLbl: Label 'These task numbers already exist in the target: %1. Nothing was copied.', Comment = '%1 = task numbers, is-IS=Þessi verkhlutanúmer eru þegar til í markverkefninu: %1. Ekkert var afritað.';
        CollisionNextLbl: Label 'Choose a source task range with no task numbers already in the target.', Comment = 'is-IS=Veldu bil upprunaverkhluta þar sem ekkert verkhlutanúmer er þegar til í markverkefninu.';
    begin
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'data', FormatLbl));
        end;
        GetParameters(Parameters);
        if not Input.Validate(Argument, Request, Parameters) then
            exit(false);
        foreach ParameterName in Request.Keys() do
            if ParameterName in ['copyQuantity', 'copyPrices', 'copyDimensions'] then begin
                Request.Get(ParameterName, Token);
                Token.WriteTo(Raw);
                if not (Raw in ['true', 'false']) then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, FormatLbl));
            end;
        if not (OptionText(Request, 'source', 'planningLines') in ['planningLines', 'ledgerEntries']) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'source', FormatLbl));
        if not (OptionText(Request, 'planningLineType', 'Both') in ['Budget', 'Billable', 'Both']) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineType', FormatLbl));
        if Request.Contains('ledgerEntryType') then
            if (OptionText(Request, 'source', 'planningLines') <> 'ledgerEntries') or
                not (Request.GetText('ledgerEntryType') in ['Usage', 'Sale']) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'ledgerEntryType', FormatLbl));
        if OptionText(Request, 'source', 'planningLines') = 'ledgerEntries' then
            if not Entry.ReadPermission() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'source', PermissionNextLbl));
        SourceNo := CopyStr(Request.GetText('sourceProjectNo'), 1, 20);
        TargetNo := CopyStr(Request.GetText('targetProjectNo'), 1, 20);
        FromNo := CopyStr(Input.TextValue(Request, 'fromTaskNo'), 1, 20);
        ToNo := CopyStr(Input.TextValue(Request, 'toTaskNo'), 1, 20);
        if SourceNo = TargetNo then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'targetProjectNo', DifferentLbl));
        if (FromNo <> '') and (ToNo <> '') and (FromNo > ToNo) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'fromTaskNo', RangeLbl));
        if not SourceProject.Get(SourceNo) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'sourceProjectNo', FindLbl));
        if not TargetProject.Get(TargetNo) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'targetProjectNo', FindLbl));
        if (TargetProject.Status = TargetProject.Status::Completed) or (TargetProject.Blocked = TargetProject.Blocked::All) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'targetProjectNo', OpenLbl));
        Task.SetRange("Job No.", SourceNo);
        if (FromNo <> '') and (ToNo <> '') then
            Task.SetRange("Job Task No.", FromNo, ToNo)
        else
            if FromNo <> '' then
                Task.SetFilter("Job Task No.", '%1..', FromNo)
            else
                if ToNo <> '' then
                    Task.SetFilter("Job Task No.", '..%1', ToNo);
        Task.SetLoadFields("Job No.", "Job Task No.");
        if Task.FindSet() then
            repeat
                if ExistingTask.Get(TargetNo, Task."Job Task No.") then begin
                    if Conflicts <> '' then
                        Conflicts += ', ';
                    Conflicts += Task."Job Task No.";
                end;
            until Task.Next() = 0;
        if Conflicts <> '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(CollisionLbl, Conflicts), 'targetProjectNo', TargetNo, '', CollisionNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Revalidates and confirms under locks, then copies and reports the native results atomically.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        SourceProject: Record Job;
        TargetProject: Record Job;
        Task: Record "Job Task";
        Line: Record "Job Planning Line";
        CopyJob: Codeunit "Copy Job";
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Response: JsonObject;
        Summary: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        TaskCount: Integer;
        LineCount: Integer;
        TotalLines: Integer;
    begin
        if not AssertPermissions(Argument) then
            exit;
        SourceProject.LockTable();
        Task.LockTable();
        Line.LockTable();
        if not Validate(Argument, Request, SourceProject, TargetProject, Task) then
            exit;
        TaskCount := Task.Count();
        ConfigureCopy(Request, CopyJob);
        CopyJob.SetJobTaskRange(CopyStr(Input.TextValue(Request, 'fromTaskNo'), 1, 20), CopyStr(Input.TextValue(Request, 'toTaskNo'), 1, 20));
        CopyJob.CopyJobTasks(SourceProject, TargetProject);
        if Task.FindSet() then
            repeat
                Line.SetRange("Job No.", TargetProject."No.");
                Line.SetRange("Job Task No.", Task."Job Task No.");
                LineCount := Line.Count();
                TotalLines += LineCount;
                Clear(Row);
                Row.Add('taskNo', Task."Job Task No.");
                Row.Add('planningLines', LineCount);
                Rows.Add(Row);
            until Task.Next() = 0;
        Summary.Add('taskCount', TaskCount);
        Summary.Add('planningLineCount', TotalLines);
        Response.Add('status', 'Success');
        Response.Add('sourceProjectNo', SourceProject."No.");
        Response.Add('targetProjectNo', TargetProject."No.");
        Response.Add('copiedTasks', Rows);
        Response.Add('copiedPlanningLines', TotalLines);
        Response.Add('summary', Summary);
        Argument.SetResponseJson(Response);
    end;

    local procedure ConfigureCopy(Request: JsonObject; var CopyJob: Codeunit "Copy Job")
    var
        Source: Option "Job Planning Lines","Job Ledger Entries";
        PlanType: Option " ",Budget,Billable;
        EntryType: Option " ",Usage,Sale;
    begin
        if OptionText(Request, 'source', 'planningLines') = 'ledgerEntries' then
            Source := Source::"Job Ledger Entries";
        case OptionText(Request, 'planningLineType', 'Both') of
            'Budget':
                PlanType := PlanType::Budget;
            'Billable':
                PlanType := PlanType::Billable;
        end;
        case OptionText(Request, 'ledgerEntryType', 'Usage') of
            'Usage':
                EntryType := EntryType::Usage;
            'Sale':
                EntryType := EntryType::Sale;
        end;
        CopyJob.SetCopyOptions(OptionalBoolean(Request, 'copyPrices'), OptionalBoolean(Request, 'copyQuantity'), OptionalBoolean(Request, 'copyDimensions'), Source, PlanType, EntryType);
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    local procedure OptionText(Request: JsonObject; ParameterName: Text; DefaultValue: Text): Text
    begin
        if Request.Contains(ParameterName) then
            exit(Request.GetText(ParameterName));
        exit(DefaultValue);
    end;

    local procedure OptionalBoolean(Request: JsonObject; ParameterName: Text): Boolean
    begin
        if Request.Contains(ParameterName) then
            exit(Request.GetBoolean(ParameterName));
        exit(true);
    end;

    var
        PermissionNextLbl: Label 'Ask an administrator for BIFROST Full ori and native project read, task and planning line insert permissions, plus posted project entry read permissions when copying ledger entries.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar lesheimildir verkefna, stofnunarheimildir verkhluta og áætlunarlína og lesheimildir bókaðra verkefnafærslna þegar færslur eru afritaðar.';
        CountLbl: Label 'source project tasks to copy', Comment = 'is-IS=upprunaverkhlutar sem á að afrita';
}
