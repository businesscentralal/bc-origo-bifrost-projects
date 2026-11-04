namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;


/// <summary>Implements the version 1 Projects.Usage.Link contract.</summary>
codeunit 70009228 "Proj. Usage Link Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::"Job Planning Line", true) and Gate.IsEnabled(Database::"Job Ledger Entry", false) and Gate.IsEnabled(Database::"Job Usage Link", true));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Usage Link");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Links posted project usage to a planning line or creates planning lines from usage through native BC.', Comment = 'is-IS=Tengir bókaða verkefnanotkun við áætlunarlínu eða stofnar áætlunarlínur úr notkun með innbyggðu BC.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, usage, link, planning, remaining', Comment = 'is-IS=verkefni, notkun, tengja, áætlun, eftirstöðvar';
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
        Parameters := Contract.Parameters('Usage', 'Link', false);
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
        Field.Add('name', 'links');
        Field.Add('type', 'array');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'planningLines');
        Field.Add('type', 'array');
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
        Effect.Add('effect', 'reversible');
        Effect.Add('changes', 'Native planning quantities and usage links; no financial posting.');
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
        NotesLbl: Label 'Get is read-only. Link requires Apply Usage Link on the project. An already linked entry is rejected. Existing lines must match the usage identity. createPlanningLine uses native transfer, with Budget as default lineType. No financial posting is performed.', Comment = 'is-IS=Get er aðeins til lestrar. Link krefst notkunartengingar á verkefninu. Færslu sem þegar er tengd er hafnað. Núverandi línur verða að passa við notkunina. createPlanningLine notar innbyggðan flutning með Budget sem sjálfgefna línugerð. Engin fjárhagsbókun fer fram.';
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
        if not Gate.AssertEnabled(Argument, GetFilterTableNo(), true) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::Job, false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Ledger Entry", false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Planning Line", true) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job Task", false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Dispatch.Execute(Argument, 'Usage', 'Link');
    end;
}
