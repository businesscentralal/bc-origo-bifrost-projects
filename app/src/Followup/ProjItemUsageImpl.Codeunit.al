namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;

/// <summary>Exposes the dedicated native project operation.</summary>
codeunit 70009242 "Proj. Item Usage Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionLbl: Label 'Ask an administrator for BIFROST Full ori and native purchase/project or inventory posting permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar innkaupa-, verkefna- eða birgðabókunarheimildir.';
        MissingLbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        FormatLbl: Label 'Use the parameter type and length listed in the help.', Comment = 'is-IS=Notaðu gagnategund og lengd viðfangs sem tilgreind eru í hjálpinni.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        IdentifierLbl: Label 'Check the project and task nos.', Comment = 'is-IS=Athugaðu verkefnis- og verkhlutanúmerin.';
        RefusedLbl: Label 'The request cannot be executed with the supplied parameters or permissions.', Comment = 'is-IS=Ekki er hægt að framkvæma beiðnina með sendum viðföngum eða heimildum.';
        ConflictLbl: Label 'Use identifiers belonging to the same purchase line, project/task, or item/location.', Comment = 'is-IS=Notaðu auðkenni sem tilheyra sömu innkaupalínu, verkefni og verkhluta eða vöru og birgðageymslu.';
        StatusLbl: Label 'Change the status with Projects.Project.SetStatus.', Comment = 'is-IS=Breyttu stöðunni með Projects.Project.SetStatus.';

    /// <summary>Checks native operation permissions before advertising availability.</summary>
    procedure IsEnabled(): Boolean
    var
        Adapter: Codeunit "Projects Item Usage ori";
    begin
        exit(Adapter.IsEnabled());
    end;

    /// <summary>Identifies the project filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Job);
    end;

    /// <summary>Returns the localized native operation purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts item consumption to an open project task through the native project journal and returns the project ledger entry range.', Comment = 'is-IS=Bókar vörunotkun á verkhluta opins verkefnis í gegnum innbyggða verkefnabók og skilar bili verkefnisfærslna.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns matching discovery terms in both supported languages.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, item, usage, post, consumption', Comment = 'is-IS=verkefni, vara, notkun, bókun, eyðsla';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized type selection explanation.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares a inbound native operation.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the version-one JSON task envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', true);
        exit(true);
    end;

    /// <summary>The typed data filters fully describe the target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Shares the exact runtime parameter declaration.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Adapter: Codeunit "Projects Item Usage ori";
    begin
        Parameters := Adapter.Parameters();
        exit(true);
    end;

    /// <summary>Describes the typed native operation result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Field0Lbl: Label 'First native project ledger entry number.', Comment = 'is-IS=Fyrsta innbyggða verkefnisfærslunúmerið.';
        Field1Lbl: Label 'Last native project ledger entry number.', Comment = 'is-IS=Síðasta innbyggða verkefnisfærslunúmerið.';
        Field2Lbl: Label 'The exact native ledger entry numbers returned for the request.', Comment = 'is-IS=Nákvæm innbyggð færslunúmer sem beiðnin skilaði.';
    begin
        Fields.Add(Contract.Parameter('firstEntryNo', 'integer', true, Field0Lbl));
        Fields.Add(Contract.Parameter('lastEntryNo', 'integer', true, Field1Lbl));
        Fields.Add(Contract.Parameter('entryNos', 'array', true, Field2Lbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists common refusals and native operation remedies.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, IdentifierLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, StatusLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionLbl));
        exit(true);
    end;

    /// <summary>Declares the operation effect and idempotency.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        exit(true);
    end;

    /// <summary>Uses Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No extra related types are required.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No extra workflow is required.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a self-contained request and answer example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Envelope: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonObject;
        Values: JsonArray;
        TitleLbl: Label 'Native project operation', Comment = 'is-IS=Innbyggð verkefnaaðgerð';
    begin
        Request.Add('projectNo', 'PROJECT-001');
        Request.Add('taskNo', 'TASK-001');
        Line.Add('itemNo', 'ITEM-001');
        Line.Add('quantity', 1);
        Values.Add(Line);
        Request.Add('lines', Values);
        Clear(Values);
        Values.Add(123);
        Response.Add('firstEntryNo', 123);
        Response.Add('lastEntryNo', 123);
        Response.Add('entryNos', Values);
        Envelope.Add('type', 'Projects.ItemUsage.Post');
        Envelope.Add('data', Request);
        Response.Add('status', 'Success');
        Example.Add('title', TitleLbl);
        Example.Add('request', Envelope);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Returns the localized operation overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Explains native safety, transaction behavior and exact selectors.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Posting commits the entire successful task and is not idempotent: resending posts again. Every line is validated before native posting begins. A failure rolls back the whole task. Native item tracking, inventory, warehouse and posting-date rules apply. Quantity must be positive; one serial number requires exactly one base unit. postingDate defaults to the work date; documentNo defaults to a task-specific identifier. No pre-existing journal line is edited or deleted.', Comment = 'is-IS=Bókun staðfestir allt verkið við árangur og endursending bókar aftur. Allar línur eru sannprófaðar áður en innbyggð bókun hefst. Bilun afturkallar allt verkið. Innbyggðar reglur um vörurakningu, birgðir, vöruhús og bókunardagsetningu gilda. Magn verður að vera jákvætt; eitt raðnúmer krefst nákvæmlega einnar grunneiningar. postingDate er sjálfgefið vinnudagsetning; documentNo er sjálfgefið verksértækt auðkenni. Engri fyrirliggjandi bókarlínu er breytt eða eytt.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Checks effective native rights before licensing and dispatches validated isolated processing.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Adapter: Codeunit "Projects Item Usage ori";
        Input: Codeunit "Projects Followup Input ori";
    begin
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Adapter.Execute(Argument);
    end;
}
