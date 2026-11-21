namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;

/// <summary>Previews and creates project-linked purchase orders through native order planning.</summary>
codeunit 70013424 "Proj. Plan Purchase Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori", "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>Checks the company switch and caller-owned project and purchase rights.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Job, false) and
            Gate.IsEnabled(Database::"Job Planning Line", true) and
            Gate.IsEnabled(Database::"Purchase Header", true) and
            Gate.IsEnabled(Database::"Purchase Line", true) and
            Gate.IsEnabled(Database::"Requisition Line", true) and
            Gate.IsEnabled(Database::Vendor, false));
    end;

    /// <summary>Returns the discovery resource.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job Planning Line");
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Previews or creates purchase orders for project item demand not covered by stock or existing supply, linked to the project task and planning line.', Comment = 'is-IS=Forskoðar eða stofnar innkaupapantanir fyrir vöruþörf verkefnis sem birgðir eða fyrirliggjandi framboð anna ekki, tengdar verkhluta og áætlunarlínu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, planning line, purchase order, vendor, demand, stock, preview', Comment = 'is-IS=verkefni, áætlunarlína, innkaupapöntun, lánardrottinn, þörf, birgðir, forskoðun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Declares an inbound request.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the version-one data envelope.</summary>
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

    /// <summary>Declares the project selector.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'Exact project number.'));
        exit(true);
    end;

    /// <summary>Declares the exact request, including confirmation units.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        Parameter: JsonObject;
    begin
        Parameters.Add(Input.Parameter('projectNo', 'string', true, 'Exact open project number.', 20));
        Parameters.Add(Input.Parameter('taskNo', 'string', false, 'Exact task; exclusive with planningLineNos.', 20));
        Parameters.Add(Input.Parameter('planningLineNos', 'array', false, 'Positive unique planning line numbers. Ambiguous numbers across tasks are refused.', 0));
        Parameters.Add(Input.Parameter('preview', 'boolean', false, 'Default false. True calculates proposals and rolls back every change.', 0));
        Parameters.Add(Input.Parameter('vendorOverrides', 'array', false, 'Objects containing only planningLineNo (positive integer) and vendorNo (exact vendor, max 20 characters).', 0));
        Parameter := Input.Parameter('expectedCount', 'integer', false, 'expectedCount counts planning lines to order, equal to proposals in preview.', 0);
        Parameter.Add('expectedCount', true);
        Parameters.Add(Parameter);
        exit(true);
    end;

    /// <summary>Documents proposals, skipped demand and created documents.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after preview rollback or purchase creation.'));
        Fields.Add(Contract.ResponseField('proposals', 'array', 'planningLineNo, taskNo, itemNo, variantCode, locationCode, quantityToOrder, vendorNo, expectedReceiptDate.'));
        Fields.Add(Contract.ResponseField('purchaseOrders', 'array', 'number, vendorNo and lines with lineNo, taskNo and planningLineNo. Empty in preview.'));
        Fields.Add(Contract.ResponseField('skipped', 'array', 'planningLineNo, taskNo and reason: coveredByStockOrSupply, notItem or billableOnly.'));
        Fields.Add(Contract.ResponseField('summary', 'object', 'planningLineCount (confirmation unit), purchaseOrderCount and skippedCount.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares localized refusals and remedies.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        NextStepLbl: Label 'Check the named parameter, project status, vendor and permissions. Finish or clear your lines on the Order Planning page before retrying.', Comment = 'is-IS=Athugaðu tilgreint viðfang, stöðu verkefnis, lánardrottin og heimildir. Ljúktu eða hreinsaðu línurnar þínar á síðunni Pöntunaráætlun áður en þú reynir aftur.';
        RefusedLbl: Label 'The purchase request cannot be processed; nothing was changed.', Comment = 'is-IS=Ekki er hægt að vinna innkaupabeiðnina; engu var breytt.';
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, RefusedLbl, NextStepLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, NextStepLbl));
        exit(true);
    end;

    /// <summary>Declares the real effect of create and the read-only preview branch.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('idempotent', false);
        Effect.Add('changes', 'Creates purchase orders linked to project planning lines. expectedCount counts planning lines ordered. preview=true has read effect and commits nothing. No posting.');
        exit(true);
    end;

    /// <summary>Uses Foundation metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Names purchase linking and company-wide planning alternatives.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.PurchaseLine.Link', 'Link an existing purchase line.'));
        exit(true);
    end;

    /// <summary>Explains preview then confirmation.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Workflow.Add('steps', 'Preview first. Review proposals and vendors, then repeat with preview=false and expectedCount equal to proposals count.');
        exit(true);
    end;

    /// <summary>Provides a preview example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Preview project purchases',
            '{"type":"Projects.PlanningLine.CreatePurchaseOrder","data":{"projectNo":"PROJECT-001","preview":true}}',
            '{"status":"Success","proposals":[],"purchaseOrders":[],"skipped":[],"summary":{"planningLineCount":0,"purchaseOrderCount":0,"skippedCount":0}}'));
        exit(true);
    end;

    /// <summary>Keeps public chapter text English in all languages.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use Create Purchase Order for the uncovered item demand of one open project. Preview returns proposals without keeping any change. Create groups purchases by vendor and links each line to its project task and planning line. Receiving and invoicing then posts native project usage.';
        exit(true);
    end;

    /// <summary>Explains scope, scratch safety and company-wide alternatives in user terms.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Finish or clear your existing lines on Order Planning first; the request never removes them. Only Budget or Both Budget and Billable item lines can be ordered. Fully covered demand is skipped. A vendor is required for each proposal. For company-wide purchases use the requisition worksheet; for company-wide purchase, transfer and assembly supply use the planning worksheet. No posting occurs here. expectedCount counts planning lines to order, as returned by preview. Orders cannot be removed through this operation.';
        exit(true);
    end;

    /// <summary>Checks permissions before licensing, validation and native work.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Input: Codeunit "Projects Followup Input ori";
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and permission to read projects and vendors and maintain purchase, planning and order-planning lines.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og heimild til að lesa verkefni og lánardrottna og viðhalda innkaupa-, áætlunar- og pöntunaráætlunarlínum.';
    begin
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ExecuteNative(Argument);
    end;

    /// <summary>Supplies the native proposal count before Foundation dispatch and leaves preview ungated.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        TempPreviewArgument: Record "Message Argument ori" temporary;
        Input: Codeunit "Projects Followup Input ori";
        DefaultConfirm: Codeunit "Default Confirm ori";
        Request: JsonObject;
        Response: JsonObject;
        CountLbl: Label 'project planning lines to order', Comment = 'is-IS=áætlunarlínur verkefnis sem á að panta';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and native project and purchase permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar verkefna- og innkaupaheimildir.';
    begin
        Count := 0;
        if not IsEnabled() then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl));
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request) then
            exit(false);
        if Request.Contains('preview') then
            if Request.GetBoolean('preview') then begin
                // Foundation's no-subject sentinel delegates validation and the read-only branch to the handler.
                Summary := DefaultConfirm.NoSubjectText();
                exit(true);
            end;
        TempPreviewArgument := Argument;
        TempPreviewArgument.Insert(true);
        if Request.Contains('preview') then
            Request.Replace('preview', true)
        else
            Request.Add('preview', true);
        TempPreviewArgument.SetRequestJson(Request);
        ExecuteNative(TempPreviewArgument);
        Response := TempPreviewArgument.GetResponseJson();
        if Response.GetText('status') <> 'Success' then begin
            Argument.SetResponseJson(Response);
            exit(false);
        end;
        Count := Response.GetArray('proposals').Count();
        Summary := CountLbl;
        exit(true);
    end;

    /// <summary>Runs one rollback boundary; intentional preview/refusal rollback returns only a session-local JSON result.</summary>
    internal procedure ExecuteNative(var Argument: Record "Message Argument ori")
    var
        Result: Codeunit "Proj. Plan Purchase Result ori";
        Response: JsonObject;
        Request: JsonObject;
        NativeStepLbl: Label 'Correct the Business Central error and retry. All planning and purchase changes were rolled back.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur. Allar áætlunar- og innkaupabreytingar voru afturkallaðar.';
    begin
        Result.Reset();
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request) then
            exit;
        if not Codeunit.Run(Codeunit::"Proj. Plan Purchase Proc ori", Argument) then
            if Result.Take(Response) then
                Argument.SetResponseJson(Response)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeStepLbl);
        Result.Reset();
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        Parameters: JsonArray;
        Token: JsonToken;
        Raw: Text;
        FormatLbl: Label 'Send preview as true or false.', Comment = 'is-IS=Sendu preview sem true eða false.';
        ConflictLbl: Label 'Supply taskNo or planningLineNos, never both.', Comment = 'is-IS=Sendu taskNo eða planningLineNos, aldrei bæði.';
    begin
        GetParameters(Parameters);
        if not Input.Validate(Argument, Request, Parameters) then
            exit(false);
        if Request.Get('preview', Token) then begin
            Token.WriteTo(Raw);
            if not (Raw in ['true', 'false']) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'preview', FormatLbl));
        end;
        if Request.Contains('taskNo') and Request.Contains('planningLineNos') then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'taskNo', ConflictLbl));
        exit(true);
    end;
}
