namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;

/// <summary>Implements the version 1 Projects.Task.Indent contract.</summary>
codeunit 70013406 "Proj. Task Indent Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        FullRole: Record "Proj. Posting ori";
    begin
        // The existing feature-role token separates Read and Full; no posting action or gate runs.
        exit(FullRole.WritePermission() and Gate.IsEnabled(Database::"Job Task", true));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Task");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Indents project tasks and recalculates their totaling ranges.', Comment = 'is-IS=Inndregur verkhluta og endurreiknar samtölubil þeirra.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, task, indent, totaling, begin-total, end-total', Comment = 'is-IS=verkefni, verkhluti, inndráttur, samtala, upphaf samtölu, lok samtölu';
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
        Target.Add(Contract.TargetEntry('data.projectNo', 'projectNo', 'Exact project number.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Parameters.Add(Input.Parameter('projectNo', 'string', true, 'Exact project number, up to 20 characters.', 20));
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.Parameter('status', 'string', true, 'Success after all tasks have been indented.'));
        Fields.Add(Contract.Parameter('projectNo', 'string', true, 'Project number.'));
        Fields.Add(Contract.Parameter('tasks', 'array', true, 'All tasks in task-number order: taskNo, taskType, indentation, totaling, changed. taskType uses the English names Posting, Heading, Total, Begin-Total and End-Total.'));
        Fields.Add(Contract.Parameter('summary', 'object', true, 'taskCount and changedCount, counting tasks whose indentation or totaling changed.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;
    /// <summary>Declares contract and native validation failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'The project task request cannot be processed.', 'Send projectNo with the exact project number.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'The project task request cannot be processed.', 'Send projectNo as a nonempty string of at most 20 characters.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The project task request cannot be processed.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The project task request cannot be processed.', 'Choose an existing project and retry.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The project task request cannot be processed.', 'Correct the Begin-Total and End-Total structure on Project Task Lines, then retry. No tasks were changed.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The project task request cannot be processed.', 'Ask an administrator for BIFROST Full ori and permission to modify project tasks.'));
        exit(true);
    end;
    /// <summary>Documents transactional native writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Overwrites indentation on every task and totaling on End-Total tasks, matching Indent Project Tasks.');
        Effect.Add('idempotent', true);
        exit(true);
    end;
    /// <summary>No additional app-specific meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>No additional related types are declared.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.Task.Create', 'Create tasks before indenting the project.'));
        Related.Add(Contract.RelatedEntry('Projects.Task.Update', 'Update the task structure, then indent the project.'));
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
        Request.Add('projectNo', 'PROJECT-001');
        Example.Add('data', Request);
        Examples.Add(Example);
        exit(true);
    end;
    /// <summary>Provides localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs Indent Project Tasks without confirmation for all tasks in one project. Use it after creating or updating the task structure.';
        exit(true);
    end;
    /// <summary>Documents nested write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Overwrites Indentation on every task and Totaling on End-Total tasks, matching the Indent Project Tasks action. Begin-Total and matching End-Total tasks define each totaling range. A second call leaves the same values and returns changed=false for every task. Unmatched End-Total tasks and nesting beyond ten levels fail atomically, with no task changes. Empty projects return an empty tasks array. Existing Totaling on other task types is preserved.';
        exit(true);
    end;
    /// <summary>Guards licensing and permissions before transactional execution.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Input: Codeunit "Projects Followup Input ori";
        PermissionLbl: Label 'Ask an administrator for BIFROST Full ori and permission to modify project tasks.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og heimild til að breyta verkhlutum.';
    begin
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Execute(Argument);
    end;

    /// <summary>Validates input before entering the shared atomic write boundary.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Parameters: JsonArray;
        FormatLbl: Label 'Send a JSON object containing projectNo.', Comment = 'is-IS=Sendu JSON-hlut sem inniheldur projectNo.';
        NativeLbl: Label 'Correct the Begin-Total and End-Total structure on Project Task Lines, then retry. No tasks were changed.', Comment = 'is-IS=Leiðréttu uppbyggingu upphafs og loka samtölu í verkhlutalínum og reyndu aftur. Engum verkhlutum var breytt.';
        Reason: Text;
    begin
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'data', FormatLbl);
            exit;
        end;
        GetParameters(Parameters);
        if not Input.Validate(Argument, Request, Parameters) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Projects Write Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Projects Write Process ori", Argument) then begin
            Reason := GetLastErrorText();
            ClearLastError();
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, Reason, 'projectNo', '', '', NativeLbl);
        end;
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    /// <summary>Runs the native action and compares each result to its pre-action snapshot.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Task: Record "Job Task";
        BeforeTask: Record "Job Task" temporary;
        Indent: Codeunit "Job Task-Indent";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Tasks: JsonArray;
        Summary: JsonObject;
        ProjectNo: Code[20];
        Changed: Boolean;
        ChangedCount: Integer;
        MissingLbl: Label 'The project does not exist.', Comment = 'is-IS=Verkefnið er ekki til.';
        FindLbl: Label 'Choose an existing project and retry.', Comment = 'is-IS=Veldu fyrirliggjandi verkefni og reyndu aftur.';
        TaskTypes: List of [Text];
        TaskOrdinals: List of [Integer];
    begin
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        if not Project.Get(ProjectNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingLbl, 'projectNo', ProjectNo, '', FindLbl);
            exit;
        end;
        Task.LockTable();
        Task.SetRange("Job No.", ProjectNo);
        if Task.FindSet() then
            repeat
                BeforeTask := Task;
                BeforeTask.Insert(false);
            until Task.Next() = 0;
        Indent.Indent(ProjectNo, true);
        TaskTypes := Task."Job Task Type".Names();
        TaskOrdinals := Task."Job Task Type".Ordinals();
        if Task.FindSet() then
            repeat
                BeforeTask.Get(ProjectNo, Task."Job Task No.");
                Changed := (Task.Indentation <> BeforeTask.Indentation) or (Task.Totaling <> BeforeTask.Totaling);
                if Changed then
                    ChangedCount += 1;
                Clear(Row);
                Row.Add('taskNo', Task."Job Task No.");
                Row.Add('taskType', TaskTypes.Get(TaskOrdinals.IndexOf(Task."Job Task Type".AsInteger())));
                Row.Add('indentation', Task.Indentation);
                Row.Add('totaling', Task.Totaling);
                Row.Add('changed', Changed);
                Tasks.Add(Row);
            until Task.Next() = 0;
        Summary.Add('taskCount', Tasks.Count());
        Summary.Add('changedCount', ChangedCount);
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        Response.Add('tasks', Tasks);
        Response.Add('summary', Summary);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
