namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.WIP;

/// <summary>Implements the version 1 Projects.Statistics.Get contract.</summary>
codeunit 10078509 "Proj. Statistics Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::"Job Planning Line", false) and Gate.IsEnabled(Database::"Job Ledger Entry", false));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Job);
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Returns native project budget, actual, billable and invoiced statistics in LCY.', Comment = 'is-IS=Skilar innbyggðri áætlun, raunkostnaði, reikningshæfum og reikningsfærðum fjárhæðum verkefnis í heimamynt.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, budget, actual, statistics', Comment = 'is-IS=verkefni, áætlun, rauntölur, tölfræði';
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
        exit("Msg Direction ori"::Outbound);
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
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'The exact native project number.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Projects Contract ori";
    begin
        Parameters := Contract.Parameters('Statistics', 'Get', false);
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        Field: JsonObject;
    begin
        Field.Add('name', 'status');
        Field.Add('type', 'string');
        Field.Add('description', 'Success after the entire native operation succeeds.');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'projectNo');
        Field.Add('type', 'string');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'statistics');
        Field.Add('type', 'object');
        Fields.Add(Field);
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
        Effect.Add('effect', 'read');
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
    /// <summary>Provides localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;
    /// <summary>Documents nested write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Read-only native statistics in LCY. Invoiced amounts use the standard BC sign convention. BudgetVsActual returns only posting tasks, so total rows are not double counted.', Comment = 'is-IS=Innbyggð tölfræði í heimamynt, aðeins til lestrar. Reikningsfærðar fjárhæðir nota formerkjareglu BC. BudgetVsActual skilar aðeins bókunarverkhlutum svo samtölur tvíteljist ekki.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;
    /// <summary>Guards licensing and permissions before transactional execution.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Projects Gate ori";
        Dispatch: Codeunit "Projects Write ori";
    begin
        if not Gate.AssertEnabled(Argument, GetFilterTableNo(), false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::Job, false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Ledger Entry", false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Planning Line", false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Task", false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Dispatch.Execute(Argument, 'Statistics', 'Get');
    end;
}
