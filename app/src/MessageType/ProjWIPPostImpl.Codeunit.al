namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.WIP;

/// <summary>Implements the version 1 Projects.WIP.Post contract.</summary>
codeunit 10078504 "Proj. WIP Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        PostingGate: Codeunit "Proj. Posting Gate ori";
    begin
        exit(Gate.IsEnabled(Database::"Job WIP G/L Entry", true) and PostingGate.HasPostingPermission() and Gate.IsEnabled(Database::Job, true) and Gate.IsEnabled(Database::"Job WIP Entry", false) and Gate.IsEnabled(Database::"Job WIP G/L Entry", false));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job WIP G/L Entry");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts calculated project WIP to the general ledger through native BC posting.', Comment = 'is-IS=Bókar reiknuð verk í vinnslu í fjárhag með innbyggðri bókun BC.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, job, work in progress, WIP, post', Comment = 'is-IS=verkefni, verk, verk í vinnslu, VÍV, bóka';
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
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'The exact native project number.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Projects Contract ori";
    begin
        Parameters := Contract.Parameters('WIP', 'Post', false);
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
        Field.Add('name', 'entries');
        Field.Add('type', 'array');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'glEntries');
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
        Effect.Add('effect', 'irreversible');
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
        NotesLbl: Label 'Uses native project WIP validation and posting. Post additionally requires BIFROST Full ori and native business permissions. New G/L entries keep the document number of the calculated WIP entries. No licensing setup is changed.', Comment = 'is-IS=Notar innbyggða sannprófun og bókun verka í vinnslu. Post krefst einnig BIFROST Full ori og innbyggðra viðskiptaheimilda. Nýjar fjárhagsfærslur halda fylgiskjalsnúmeri reiknaðra VÍV-færslna. Engri leyfisuppsetningu er breytt.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;
    /// <summary>Guards licensing and permissions before transactional execution.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Projects Gate ori";
        Dispatch: Codeunit "Projects Write ori";
        PostingGate: Codeunit "Proj. Posting Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, GetFilterTableNo(), true) then
            exit;
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::Job, true) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job WIP Entry", false) then
            exit;
        if not Gate.AssertEnabled(Argument, Database::"Job WIP G/L Entry", false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Dispatch.Execute(Argument, 'WIP', 'Post');
    end;
}
