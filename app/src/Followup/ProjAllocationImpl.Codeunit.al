namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;

/// <summary>Exposes the Projects.ResourceAllocation.Get message and its localized read-only contract.</summary>
codeunit 70009238 "Proj. Allocation Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Text1Lbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        Text2Lbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        Text3Lbl: Label 'Use the parameter type and length listed in the help.', Comment = 'is-IS=Notaðu gagnategund og lengd viðfangs sem tilgreind eru í hjálpinni.';
        Text4Lbl: Label 'Optional exact resource number.', Comment = 'is-IS=Valfrjálst nákvæmt forðanúmer.';
        Text5Lbl: Label 'Ask an administrator for BIFROST Read ori and the Projects read permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Read ori og lesheimildir fyrir verkefni.';
        Text6Lbl: Label 'Use day, week, month, quarter or year.', Comment = 'is-IS=Notaðu day, week, month, quarter eða year.';
        Text7Lbl: Label 'Narrow the date range.', Comment = 'is-IS=Þrengdu dagsetningabilið.';
        Text8Lbl: Label 'Use a resource belonging to the selected resource group.', Comment = 'is-IS=Notaðu forða sem tilheyrir völdum forðaflokki.';
        Text9Lbl: Label 'Optional exact project number.', Comment = 'is-IS=Valfrjálst nákvæmt verkefnisnúmer.';
        Text10Lbl: Label 'resource no.', Comment = 'is-IS=forðanúmer';
        Text11Lbl: Label 'project no.', Comment = 'is-IS=verkefnisnúmer';
        Text12Lbl: Label 'Each row contains resourceNo, fromDate, toDate, capacity, allocated, availability and projects (projectNo, allocated). Quantities use the resource base unit.', Comment = 'is-IS=Hver lína inniheldur resourceNo, fromDate, toDate, capacity, allocated, availability og projects (projectNo, allocated). Magn er í grunneiningu forðans.';
        Text13Lbl: Label 'The requested calendar period type.', Comment = 'is-IS=Umbeðin tegund almanakstímabils.';
        Text14Lbl: Label 'A required date or periodType is missing.', Comment = 'is-IS=Nauðsynlega dagsetningu eða periodType vantar.';
        Text15Lbl: Label 'A parameter has the wrong JSON type, date format or identifier length.', Comment = 'is-IS=Viðfang hefur ranga JSON-gagnategund, dagsetningasnið eða lengd auðkennis.';
        Text16Lbl: Label 'A key is not declared by this contract.', Comment = 'is-IS=Lykill er ekki skilgreindur í þessum samningi.';
        Text17Lbl: Label 'The periodType or date range is invalid.', Comment = 'is-IS=periodType eða dagsetningabil er ógilt.';
        Text18Lbl: Label 'The requested range crosses more than 53 calendar periods.', Comment = 'is-IS=Umbeðið bil nær yfir fleiri en 53 almanakstímabil.';
        Text19Lbl: Label 'An explicit project, resource or resource group does not exist.', Comment = 'is-IS=Tilgreint verkefni, forði eða forðaflokkur er ekki til.';
        Text20Lbl: Label 'Pass an existing identifier.', Comment = 'is-IS=Sendu auðkenni sem er til.';
        Text21Lbl: Label 'The resource does not belong to the selected group.', Comment = 'is-IS=Forðinn tilheyrir ekki völdum flokki.';
        Text22Lbl: Label 'A required native table is not readable or Projects is disabled.', Comment = 'is-IS=Ekki er hægt að lesa nauðsynleg gögn eða verkefni eru óvirk.';

    /// <summary>Checks company enablement and every required native read permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Allocation: Codeunit "Projects Allocation ori";
    begin
        exit(Allocation.IsEnabled());
    end;

    /// <summary>Identifies the resource table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Resource);
    end;

    /// <summary>Returns the localized purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads resource capacity, allocation to open projects and availability by calendar period.', Comment = 'is-IS=Les afkastagetu, ráðstöfun á opin verkefni og lausa afkastagetu forða eftir almanakstímabili.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, resource, capacity, allocation, availability', Comment = 'is-IS=verkefni, forði, afkastageta, ráðstöfun, tiltækni';
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
        exit("Msg Direction ori"::Outbound);
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
    begin
        Target.Add(Contract.TargetEntry('data.resourceNo', Text10Lbl, Text4Lbl));
        Target.Add(Contract.TargetEntry('data.projectNo', Text11Lbl, Text9Lbl));
        exit(true);
    end;

    /// <summary>Declares every key read by the allocation engine.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Allocation: Codeunit "Projects Allocation ori";
    begin
        Parameters := Allocation.Parameters();
        exit(true);
    end;

    /// <summary>Describes per-resource/per-period response rows.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.Parameter('rows', 'array', true, Text12Lbl));
        Fields.Add(Contract.Parameter('periodType', 'string', true, Text13Lbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes stable refusal codes and corrective next steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, Text14Lbl, Text2Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, Text15Lbl, Text3Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, Text16Lbl, Text1Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, Text17Lbl, Text6Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, Text18Lbl, Text7Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, Text19Lbl, Text20Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, Text21Lbl, Text8Lbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, Text22Lbl, Text5Lbl));
        exit(true);
    end;

    /// <summary>Declares read-only idempotent behavior.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('idempotent', true);
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
        Envelope: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Project: JsonObject;
        Rows: JsonArray;
        Projects: JsonArray;
        TitleLbl: Label 'Monthly resource allocation', Comment = 'is-IS=Mánaðarleg ráðstöfun forða';
    begin
        Request.Add('resourceNo', 'RESOURCE-001');
        Request.Add('periodType', 'month');
        Request.Add('fromDate', '2026-01-01');
        Request.Add('toDate', '2026-01-31');
        Envelope.Add('type', 'Projects.ResourceAllocation.Get');
        Envelope.Add('data', Request);
        Project.Add('projectNo', 'PROJECT-001');
        Project.Add('allocated', 120);
        Projects.Add(Project);
        Row.Add('resourceNo', 'RESOURCE-001');
        Row.Add('fromDate', '2026-01-01');
        Row.Add('toDate', '2026-01-31');
        Row.Add('capacity', 160);
        Row.Add('allocated', 120);
        Row.Add('availability', 40);
        Row.Add('projects', Projects);
        Rows.Add(Row);
        Response.Add('status', 'Success');
        Response.Add('periodType', 'month');
        Response.Add('rows', Rows);
        Example.Add('title', TitleLbl);
        Example.Add('request', Envelope);
        Example.Add('response', Response);
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
        NotesLbl: Label 'Read only. Dates are inclusive; weeks end Sunday. Partial first/last periods are clipped to the date range. At most 53 periods are allowed. Allocation sums scheduled base quantities on open projects; billable-only lines are excluded. Capacity is the resource total even when projectNo filters allocation. Missing capacity returns zero. No capacity or allocation is changed.', Comment = 'is-IS=Aðeins til lestrar. Dagsetningar eru meðtaldar; vikum lýkur á sunnudegi. Fyrsta og síðasta tímabil afmarkast af dagsetningabilinu. Mest 53 tímabil eru leyfð. Ráðstöfun leggur saman áætlað grunnmagn á opnum verkefnum; línur sem eru eingöngu reikningshæfar eru undanskildar. Afkastageta er heildargeta forðans þótt projectNo afmarki ráðstöfun. Engar afkastafærslur skila núlli. Afkastagetu eða ráðstöfun er ekki breytt.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Checks effective permissions before licensing and executes the read-only request.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Allocation: Codeunit "Projects Allocation ori";
        Input: Codeunit "Projects Followup Input ori";
    begin
        if not Allocation.IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', Text5Lbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Allocation.Execute(Argument);
    end;
}
