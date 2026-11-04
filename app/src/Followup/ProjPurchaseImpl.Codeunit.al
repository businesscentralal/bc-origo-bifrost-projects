namespace Origo.Bifrost.Projects;

using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>Exposes the dedicated native project operation.</summary>
codeunit 70009241 "Proj. Purchase Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        ReceivedLbl: Label 'Link before receiving; correct posted lines with a credit memo.', Comment = 'is-IS=Tengdu fyrir móttöku; leiðréttu bókaðar línur með kreditreikningi.';

    /// <summary>Checks native operation permissions before advertising availability.</summary>
    procedure IsEnabled(): Boolean
    var
        Adapter: Codeunit "Projects Purchase ori";
    begin
        exit(Adapter.IsEnabled());
    end;

    /// <summary>Identifies the project filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Purchase Line");
    end;

    /// <summary>Returns the localized native operation purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Links an unposted purchase line to an open project task through native field validation.', Comment = 'is-IS=Tengir óbókaða innkaupalínu við verkhluta opins verkefnis með innbyggðri sannprófun reita.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns matching discovery terms in both supported languages.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, purchase, line, link, task', Comment = 'is-IS=verkefni, innkaup, lína, tenging, verkhluti';
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
        Adapter: Codeunit "Projects Purchase ori";
    begin
        Parameters := Adapter.Parameters();
        exit(true);
    end;

    /// <summary>Describes the typed native operation result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Field0Lbl: Label 'Whether the native purchase link changed.', Comment = 'is-IS=Hvort innbyggða innkaupatengingin breyttist.';
        Field1Lbl: Label 'The exact updated purchase line identifier.', Comment = 'is-IS=Nákvæmt auðkenni uppfærðu innkaupalínunnar.';
        Field2Lbl: Label 'Linked project number.', Comment = 'is-IS=Tengt verkefnisnúmer.';
        Field3Lbl: Label 'Linked task number.', Comment = 'is-IS=Tengt verkhlutanúmer.';
    begin
        Fields.Add(Contract.Parameter('changed', 'boolean', true, Field0Lbl));
        Fields.Add(Contract.Parameter('systemId', 'guid', true, Field1Lbl));
        Fields.Add(Contract.Parameter('projectNo', 'string', true, Field2Lbl));
        Fields.Add(Contract.Parameter('taskNo', 'string', true, Field3Lbl));
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
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, ReceivedLbl));
        exit(true);
    end;

    /// <summary>Declares the operation effect and idempotency.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', true);
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
        TitleLbl: Label 'Native project operation', Comment = 'is-IS=Innbyggð verkefnaaðgerð';
    begin
        Request.Add('projectNo', 'PROJECT-001');
        Request.Add('taskNo', 'TASK-001');
        Request.Add('systemId', '11111111-1111-1111-1111-111111111111');
        Response.Add('changed', true);
        Response.Add('systemId', '11111111-1111-1111-1111-111111111111');
        Response.Add('projectNo', 'PROJECT-001');
        Response.Add('taskNo', 'TASK-001');
        Envelope.Add('type', 'Projects.PurchaseLine.Link');
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
        NotesLbl: Label 'Updates one unposted purchase line; nothing is received, invoiced or posted. Use systemId or the complete documentType/documentNo/lineNo key. If both are provided they must identify the same line. Repeating an unchanged link returns changed false. Received or invoiced lines are refused. Optional planningLineNo must belong to the selected project and task.', Comment = 'is-IS=Uppfærir eina óbókaða innkaupalínu; ekkert er móttekið, reikningsfært eða bókað. Notaðu systemId eða allan documentType/documentNo/lineNo lykilinn. Ef bæði eru send verða þau að auðkenna sömu línu. Endurtekin óbreytt tenging skilar changed false. Mótteknum eða reikningsfærðum línum er hafnað. Valfrjálst planningLineNo verður að tilheyra völdu verkefni og verkhluta.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Checks effective native rights before licensing and dispatches validated isolated processing.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Adapter: Codeunit "Projects Purchase ori";
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
