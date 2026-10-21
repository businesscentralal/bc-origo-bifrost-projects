namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Archive;
using Origo.Bifrost;

/// <summary>Exposes the Projects.Project.Archive message and its localized read-only contract.</summary>
codeunit 70009239 "Proj. Archive Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks company enablement and every required native read permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Allocation: Codeunit "Projects Archive ori";
    begin
        exit(Allocation.IsEnabled(true));
    end;

    /// <summary>Identifies the resource table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Archive");
    end;

    /// <summary>Returns the localized purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a new native project archive version.', Comment = 'is-IS=Vistar nýja innbyggða útgáfu verkefnis.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, archive, version, task, snapshot', Comment = 'is-IS=verkefni, safn, útgáfa, verkhluti, afrit';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection explanation.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares a read-only outbound message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the version-one JSON request envelope.</summary>
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

    /// <summary>Describes optional exact resource/project selectors.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        DescriptionLbl: Label 'Exact project number.', Comment = 'is-IS=Nákvæmt verkefnisnúmer.';
    begin
        Target.Add(Contract.TargetEntry('data.projectNo', 'projectNo', DescriptionLbl));
        exit(true);
    end;

    /// <summary>Declares every key read by the archive engine.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Allocation: Codeunit "Projects Archive ori";
    begin
        Parameters := Allocation.Parameters(true);
        exit(true);
    end;

    /// <summary>Describes per-resource/per-period response rows.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        DescriptionLbl: Label 'The new archived version number, or archived versions including tasks and planning lines when versionNo selects one version.', Comment = 'is-IS=Númer nýrrar vistaðrar útgáfu eða vistaðar útgáfur með verkhlutum og áætlunarlínum þegar versionNo velur eina útgáfu.';
    begin
        Fields.Add(Contract.Parameter('versionNo', 'integer', true, DescriptionLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes stable refusal codes and corrective next steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        InvalidLbl: Label 'The named parameter is invalid or missing.', Comment = 'is-IS=Tilgreint viðfang er ógilt eða vantar.';
        MissingLbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        FormatLbl: Label 'Use the parameter type and length listed in the help.', Comment = 'is-IS=Notaðu gagnategund og lengd viðfangs sem tilgreind eru í hjálpinni.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        VersionLbl: Label 'List versions with Projects.ProjectArchive.Get.', Comment = 'is-IS=Sýndu útgáfur með Projects.ProjectArchive.Get.';
        SetupLbl: Label 'Turn on Archive Projects in Jobs Setup.', Comment = 'is-IS=Kveiktu á vistun verkefnaútgáfa í uppsetningu verkefna.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori to archive, or BIFROST Read ori to read archives, and the native project permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori til að vista útgáfu eða BIFROST Read ori til að lesa vistaðar útgáfur og innbyggðar verkefnaheimildir.';
        NativeLbl: Label 'Correct the native validation error and retry; the failed archive is rolled back.', Comment = 'is-IS=Leiðréttu innbyggðu villuna og reyndu aftur; misheppnuð vistun er afturkölluð.';
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, InvalidLbl, MissingLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, InvalidLbl, UnknownLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidLbl, VersionLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, InvalidLbl, VersionLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, InvalidLbl, SetupLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, InvalidLbl, PermissionsLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, InvalidLbl, NativeLbl));
        exit(true);
    end;

    /// <summary>Declares read-only idempotent behavior.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        exit(true);
    end;

    /// <summary>Uses standard Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional related types are required.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No workflow chapter is required.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides a self-contained request example.</summary>
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

    /// <summary>Returns localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Explains calendar boundaries, scope and allocation quantities.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Archiving requires Archive Projects to be enabled in Jobs Setup. Each successful archive call creates a new version through the native action and commits the isolated operation. Read requests never write; omit versionNo to list versions, or pass a positive versionNo to include its tasks and planning lines. Restoring and deleting archives are not supported.', Comment = 'is-IS=Vistun útgáfu krefst þess að kveikt sé á vistun verkefnaútgáfa í uppsetningu verkefna. Hvert heppnað vistunarkall býr til nýja útgáfu með innbyggðri aðgerð og staðfestir einangruðu aðgerðina. Lesbeiðnir skrifa aldrei; slepptu versionNo til að sýna útgáfur eða sendu jákvætt versionNo til að fá verkhluta og áætlunarlínur útgáfunnar. Endurheimt og eyðing vistaðra útgáfa eru ekki studdar.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Checks effective permissions before licensing and executes the read-only request.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Archive: Codeunit "Projects Archive ori";
        Input: Codeunit "Projects Followup Input ori";
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori to archive, or BIFROST Read ori to read archives, and the native project permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori til að vista útgáfu eða BIFROST Read ori til að lesa vistaðar útgáfur og innbyggðar verkefnaheimildir.';
    begin
        if not Archive.IsEnabled(true) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Archive.Execute(Argument, true);
    end;
}
