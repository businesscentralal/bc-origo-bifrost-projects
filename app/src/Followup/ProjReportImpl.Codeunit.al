namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;

/// <summary>Exposes typed read-only native project reports without arbitrary report execution.</summary>
codeunit 70009243 "Proj. Report Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionLbl: Label 'Ask an administrator for BIFROST Read ori and native project report read permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Read ori og innbyggðar lesheimildir fyrir verkefnaskýrslur.';
        MissingLbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        ReportLbl: Label 'Use one of the values listed in the help.', Comment = 'is-IS=Notaðu eitt gildanna sem talin eru upp í hjálpinni.';
        FormatLbl: Label 'Use the parameter type and length listed in the help.', Comment = 'is-IS=Notaðu gagnategund og lengd viðfangs sem tilgreind eru í hjálpinni.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        IdentifierLbl: Label 'Pass an existing project, task or register number.', Comment = 'is-IS=Sendu verkefnis-, verkhluta- eða færsluskrárnúmer sem er til.';
        ConflictLbl: Label 'Use a task belonging to the selected project.', Comment = 'is-IS=Notaðu verkhluta sem tilheyrir völdu verkefni.';
        RefusedLbl: Label 'The request cannot be executed with the supplied parameters or permissions.', Comment = 'is-IS=Ekki er hægt að framkvæma beiðnina með sendum viðföngum eða heimildum.';

    /// <summary>Checks every native data read before advertising availability.</summary>
    procedure IsEnabled(): Boolean
    var
        Adapter: Codeunit "Projects Report ori";
    begin
        exit(Adapter.IsEnabled());
    end;

    /// <summary>Identifies the project filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Job);
    end;

    /// <summary>Returns the localized report purpose.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads standard project Actual to Budget, Analysis, WIP to G/L or Register reports as typed rows or a base64 PDF.', Comment = 'is-IS=Les staðlaðar verkefnaskýrslur um rauntölur og áætlun, greiningu, verk í vinnslu í fjárhag eða færsluskrá sem gagnaðar línur eða base64 PDF.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns matching discovery terms in both supported languages.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, report, budget, analysis, register', Comment = 'is-IS=verkefni, skýrsla, áætlun, greining, færsluskrá';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized type selection explanation.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares a read-only outbound type.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
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
        Adapter: Codeunit "Projects Report ori";
    begin
        Parameters := Adapter.Parameters();
        exit(true);
    end;

    /// <summary>Describes the selected format and native report result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        RowsLbl: Label 'For json: typed native report detail rows; no data is an empty list. Actual-to-budget rows contain quantities, costs and prices for budget, actual and difference. Analysis rows contain budget, actual, billable and invoiced costs and prices. WIP rows contain account, posting group, WIP amounts, G/L balance and difference. Register rows contain native ledger identifiers and amounts. All monetary amounts are LCY.', Comment = 'is-IS=Fyrir json: gagnaðar ítarlínur innbyggðu skýrslunnar; engin gögn eru tómur listi. Rauntölur og áætlun innihalda magn, kostnað og verð fyrir áætlun, rauntölur og mismun. Greining inniheldur áætlaðan, raunverulegan, reikningshæfan og reikningsfærðan kostnað og verð. Verk í vinnslu innihalda reikning, bókunarflokk, fjárhæðir, fjárhagsstöðu og mismun. Færsluskrá inniheldur innbyggð færsluauðkenni og fjárhæðir. Allar fjárhæðir eru í SGM.';
        PdfLbl: Label 'For pdf: the native standard-layout PDF encoded as base64, with contentType application/pdf.', Comment = 'is-IS=Fyrir pdf: PDF með innbyggðu staðlaðri útliti, kóðað sem base64, með contentType application/pdf.';
    begin
        Fields.Add(Contract.Parameter('rows', 'array', false, RowsLbl));
        Fields.Add(Contract.Parameter('pdfBase64', 'string', false, PdfLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes declared input and permission refusals with corrective next steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, RefusedLbl, ReportLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, IdentifierLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionLbl));
        exit(true);
    end;

    /// <summary>Declares read-only idempotent behavior.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
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

    /// <summary>Provides a self-contained typed analysis example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Envelope: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        TitleLbl: Label 'Project analysis in local currency', Comment = 'is-IS=Verkefnagreining í staðbundnum gjaldmiðli';
    begin
        Request.Add('report', 'analysis');
        Request.Add('format', 'json');
        Request.Add('projectNo', 'PROJECT-001');
        Request.Add('taskNo', 'TASK-001');
        Request.Add('fromDate', '2026-01-01');
        Request.Add('toDate', '2026-01-31');
        Envelope.Add('type', 'Projects.Report.Get');
        Envelope.Add('data', Request);
        Row.Add('projectNo', 'PROJECT-001');
        Row.Add('taskNo', 'TASK-001');
        Row.Add('description', 'Project analysis');
        Row.Add('budgetPriceLCY', 1000);
        Row.Add('actualPriceLCY', 300);
        Row.Add('billablePriceLCY', 1000);
        Row.Add('invoicedPriceLCY', 0);
        Row.Add('budgetCostLCY', 800);
        Row.Add('actualCostLCY', 240);
        Row.Add('billableCostLCY', 800);
        Row.Add('invoicedCostLCY', 0);
        Rows.Add(Row);
        Response.Add('status', 'Success');
        Response.Add('report', 'analysis');
        Response.Add('format', 'json');
        Response.Add('rows', Rows);
        Example.Add('title', TitleLbl);
        Example.Add('request', Envelope);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Returns the localized report overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Explains exact filters, default layout, date scope and no-write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Read only: nothing is posted or changed. Monetary amounts use local currency. Date filters are inclusive and apply to posting dates and planning dates. Analysis uses fixed budget, actual, billable and invoiced price/cost columns. wipToGL accepts project and dates; taskNo is refused. register requires registerNo and intersects optional project/task/date filters. Custom layouts and scheduling are not supported.', Comment = 'is-IS=Aðeins til lestrar: ekkert er bókað eða breytt. Fjárhæðir eru í staðbundnum gjaldmiðli. Dagsetningasíur eru meðtaldar og gilda um bókunar- og áætlunardagsetningar. Greining notar fasta verð- og kostnaðardálka fyrir áætlun, rauntölur, reikningshæfar og reikningsfærðar fjárhæðir. wipToGL tekur verkefni og dagsetningar; taskNo er hafnað. register krefst registerNo og sker saman valfrjálsar verkefnis-, verkhluta- og dagsetningasíur. Sérsniðin útlit og tímasetning eru ekki studd.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Checks effective read rights before licensing and executes only a validated standard report.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Adapter: Codeunit "Projects Report ori";
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
