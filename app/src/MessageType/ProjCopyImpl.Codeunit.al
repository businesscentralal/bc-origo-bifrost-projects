namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Implements the version 1 Projects.Project.Copy contract.</summary>
codeunit 70013515 "Proj. Copy Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.Project.Copy") then
            exit(false);
        exit(Gate.IsEnabled(Database::"Job", true) and Gate.IsEnabled(Database::"Job Task", true) and Gate.IsEnabled(Database::"Job Planning Line", true));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Copies a project with a task range and budget or billable planning lines.', Comment = 'is-IS=Afritar verkefni með bili verkhluta og áætlunar- eða reikningsfærslulínum.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, job, task, planning line, copy', Comment = 'is-IS=verkefni, verk, verkhluti, áætlunarlína, afrita';
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
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'Source project to copy.'));
        Target.Add(Contract.TargetEntry('data.targetProjectNo', 'project no.', 'New target project number.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Projects Contract ori";
    begin
        Parameters := Contract.Parameters('Project', 'Copy', false);
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        ResponseField: JsonObject;
    begin
        ResponseField.Add('name', 'status');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Success after the entire native operation succeeds.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'projectNo');
        ResponseField.Add('type', 'string');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'sourceProjectNo');
        ResponseField.Add('type', 'string');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;
    /// <summary>Declares contract and native validation failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Projects Contract ori";
    begin
        Errors := Contract.Errors();
        exit(true);
    end;
    /// <summary>Documents transactional native writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Project records; native field and table triggers run.');
        Effect.Add('idempotent', false);
        exit(true);
    end;
    /// <summary>No additional app-specific meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>No additional related types are declared.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;
    /// <summary>No additional workflow chapter is declared.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>Provides a minimal request example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;
    /// <summary>Explains copying into a new project.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Copies a project with its selected tasks and planning lines into a new project. For an existing target use Projects.Task.CopyFrom.';
        exit(true);
    end;
    /// <summary>Documents the native copy and existing-target alternative.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Uses Copy Project with its native options. The target project must be new. For an existing target use Projects.Task.CopyFrom; that operation refuses any existing task numbers. No time sheets or postings are created. A native failure rolls back the whole copy.';
        exit(true);
    end;
    /// <summary>Guards licensing and permissions before transactional execution.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Gate: Codeunit "Projects Gate ori";
        Dispatch: Codeunit "Projects Write ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.Project.Copy") then
            exit;
        if not Gate.AssertEnabled(Argument, GetFilterTableNo(), true) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Task", true) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Planning Line", true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Dispatch.Execute(Argument, 'Project', 'Copy');
    end;
}
