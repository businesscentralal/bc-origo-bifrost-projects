namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>Links an unposted purchase line through native project-field validation without posting the purchase document.</summary>
codeunit 70009232 "Projects Purchase ori"
{
    Access = Internal;

    var
        MissingLbl: Label 'Check the project and task nos.', Comment = 'is-IS=Athugaðu verkefnis- og verkhlutanúmerin.';
        StatusLbl: Label 'Change the status with Projects.Project.SetStatus.', Comment = 'is-IS=Breyttu stöðunni með Projects.Project.SetStatus.';
        ReceivedLbl: Label 'Link before receiving; correct posted lines with a credit memo.', Comment = 'is-IS=Tengdu fyrir móttöku; leiðréttu bókaðar línur með kreditreikningi.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and native purchase/project permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar innkaupa- og verkefnaheimildir.';
        SelectorLbl: Label 'Pass systemId or documentType, documentNo and lineNo.', Comment = 'is-IS=Sendu systemId eða documentType, documentNo og lineNo.';
        ConflictLbl: Label 'Use identifiers for the same purchase line.', Comment = 'is-IS=Notaðu auðkenni fyrir sömu innkaupalínu.';
        TypeLbl: Label 'Use Quote, Order, Invoice, Credit Memo, Blanket Order or Return Order.', Comment = 'is-IS=Notaðu Quote, Order, Invoice, Credit Memo, Blanket Order eða Return Order.';
        LineTypeLbl: Label 'Use budget, billable or both.', Comment = 'is-IS=Notaðu budget, billable eða both.';

    /// <summary>Declares exact purchase selectors and project-link fields.</summary>
    procedure Parameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
        ProjectLbl: Label 'Exact open project number.', Comment = 'is-IS=Nákvæmt númer opins verkefnis.';
        TaskLbl: Label 'Exact posting task number within the project.', Comment = 'is-IS=Nákvæmt númer bókunarverkhluta innan verkefnisins.';
        SystemLbl: Label 'Purchase line SystemId; alternative to the complete document key.', Comment = 'is-IS=SystemId innkaupalínunnar; kemur í stað alls skjalalykilsins.';
        TypeDescriptionLbl: Label 'Native unposted document type: Quote, Order, Invoice, Credit Memo, Blanket Order or Return Order.', Comment = 'is-IS=Innbyggð óbókuð skjalategund: Quote, Order, Invoice, Credit Memo, Blanket Order eða Return Order.';
        DocumentLbl: Label 'Exact unposted purchase document number.', Comment = 'is-IS=Nákvæmt númer óbókaðs innkaupaskjals.';
        LineLbl: Label 'Positive purchase line number; required with document selectors.', Comment = 'is-IS=Jákvætt innkaupalínunúmer; nauðsynlegt með skjalalyklum.';
        PlanningLbl: Label 'Optional existing project planning line number; zero clears the link.', Comment = 'is-IS=Valfrjálst númer núverandi verkefnisáætlunarlínu; núll hreinsar tenginguna.';
        LinkTypeLbl: Label 'Optional budget, billable or both; omitted preserves the native default or current value.', Comment = 'is-IS=Valfrjálst budget, billable eða both; ef því er sleppt helst innbyggt sjálfgefið eða núverandi gildi.';
    begin
        Result.Add(Input.Parameter('projectNo', 'string', true, ProjectLbl, 20));
        Result.Add(Input.Parameter('taskNo', 'string', true, TaskLbl, 20));
        Result.Add(Input.Parameter('systemId', 'guid', false, SystemLbl, 38));
        Result.Add(Input.Parameter('documentType', 'string', false, TypeDescriptionLbl, 0));
        Result.Add(Input.Parameter('documentNo', 'string', false, DocumentLbl, 20));
        Result.Add(Input.Parameter('lineNo', 'integer', false, LineLbl, 0));
        Result.Add(Input.Parameter('lineType', 'string', false, LinkTypeLbl, 0));
        Result.Add(Input.Parameter('planningLineNo', 'integer', false, PlanningLbl, 0));
    end;

    /// <summary>Checks the caller's native purchase write and project read permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        Posting: Codeunit "Proj. Posting Gate ori";
    begin
        exit(Posting.HasPostingPermission() and Gate.IsEnabled(Database::"Purchase Line", true) and Gate.IsEnabled(Database::"Purchase Line", false) and
             Gate.IsEnabled(Database::"Purchase Header", false) and Gate.IsEnabled(Database::Job, false) and
             Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::"Job Planning Line", false));
    end;

    /// <summary>Validates all identifiers before dispatching an isolated native field update.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
    begin
        Request := Argument.GetRequestJson();
        if not Input.Validate(Argument, Request, Parameters()) then
            exit;
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        if not ValidateSelectors(Argument, Request) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Purchase Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Purchase Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure ValidateSelectors(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        DocumentType: Enum "Purchase Document Type";
    begin
        if not Request.Contains('systemId') or Request.Contains('documentType') or Request.Contains('documentNo') or Request.Contains('lineNo') then begin
            if not Request.Contains('documentType') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'documentType', SelectorLbl));
            if not Request.Contains('documentNo') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'documentNo', SelectorLbl));
            if Request.GetText('documentNo').Trim() = '' then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'documentNo', SelectorLbl));
            if not Request.Contains('lineNo') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'lineNo', SelectorLbl));
            if Request.GetInteger('lineNo') = 0 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'lineNo', SelectorLbl));
            if not TryDocumentType(Request.GetText('documentType'), DocumentType) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'documentType', TypeLbl));
        end;
        if Request.Contains('lineType') then
            if not (Request.GetText('lineType') in ['budget', 'billable', 'both']) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'lineType', LineTypeLbl));
        exit(true);
    end;

    /// <summary>Rechecks the locked native records and updates the validated project-link fields.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        PurchaseLine: Record "Purchase Line";
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Response: JsonObject;
        Changed: Boolean;
    begin
        Request := Argument.GetRequestJson();
        if not ResolveLine(Argument, Request, PurchaseLine) then
            exit;
        if not Project.Get(Request.GetText('projectNo')) or not Task.Get(Request.GetText('projectNo'), Request.GetText('taskNo')) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl);
            exit;
        end;
        if (Project.Status <> Project.Status::Open) or (Project.Blocked <> Project.Blocked::" ") then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', StatusLbl);
            exit;
        end;
        if Task."Job Task Type" <> Task."Job Task Type"::Posting then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', MissingLbl);
            exit;
        end;
        if (PurchaseLine."Quantity Received" <> 0) or (PurchaseLine."Quantity Invoiced" <> 0) or (PurchaseLine."Receipt No." <> '') or (PurchaseLine."Return Qty. Shipped" <> 0) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'lineNo', ReceivedLbl);
            exit;
        end;
        if Request.Contains('planningLineNo') then
            if Request.GetInteger('planningLineNo') > 0 then
                if not Planning.Get(Project."No.", Task."Job Task No.", Request.GetInteger('planningLineNo')) then begin
                    Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'planningLineNo', MissingLbl);
                    exit;
                end;
        Changed := (PurchaseLine."Job No." <> Project."No.") or (PurchaseLine."Job Task No." <> Task."Job Task No.");
        if Request.Contains('lineType') then
            Changed := Changed or (PurchaseLine."Job Line Type" <> LineType(Request.GetText('lineType')));
        if Request.Contains('planningLineNo') then
            Changed := Changed or (PurchaseLine."Job Planning Line No." <> Request.GetInteger('planningLineNo'));
        if Request.Contains('lineType') and not Request.Contains('planningLineNo') and (PurchaseLine."Job Planning Line No." <> 0) then
            if PurchaseLine."Job Line Type" <> LineType(Request.GetText('lineType')) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'planningLineNo', LineTypeLbl);
                exit;
            end;
        if Request.Contains('lineType') and Request.Contains('planningLineNo') then
            if Request.GetInteger('planningLineNo') > 0 then
                if Planning.ConvertToJobLineType() <> LineType(Request.GetText('lineType')) then begin
                    Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'lineType', LineTypeLbl);
                    exit;
                end;
        if Changed then begin
            if (PurchaseLine."Job No." <> Project."No.") or (PurchaseLine."Job Task No." <> Task."Job Task No.") then begin
                PurchaseLine.Validate("Job No.", Project."No.");
                PurchaseLine.Validate("Job Task No.", Task."Job Task No.");
            end;
            // Native line-type validation requires clearing an old planning link first.
            if Request.Contains('lineType') then begin
                if PurchaseLine."Job Planning Line No." <> 0 then
                    PurchaseLine.Validate("Job Planning Line No.", 0);
                PurchaseLine.Validate("Job Line Type", LineType(Request.GetText('lineType')));
            end;
            if Request.Contains('planningLineNo') then
                PurchaseLine.Validate("Job Planning Line No.", Request.GetInteger('planningLineNo'));
            PurchaseLine.Modify(true);
        end;
        Response.Add('status', 'Success');
        Response.Add('changed', Changed);
        Response.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Response.Add('documentNo', PurchaseLine."Document No.");
        Response.Add('lineNo', PurchaseLine."Line No.");
        Response.Add('projectNo', PurchaseLine."Job No.");
        Response.Add('taskNo', PurchaseLine."Job Task No.");
        Response.Add('planningLineNo', PurchaseLine."Job Planning Line No.");
        Argument.SetResponseJson(Response);
    end;

    local procedure ResolveLine(var Argument: Record "Message Argument ori"; Request: JsonObject; var PurchaseLine: Record "Purchase Line"): Boolean
    var
        KeyLine: Record "Purchase Line";
        Input: Codeunit "Projects Followup Input ori";
        DocumentType: Enum "Purchase Document Type";
        SystemId: Guid;
    begin
        PurchaseLine.LockTable();
        if Request.Contains('systemId') then begin
            Evaluate(SystemId, Request.GetText('systemId'));
            if not PurchaseLine.GetBySystemId(SystemId) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'systemId', MissingLbl));
        end;
        if Request.Contains('documentType') then begin
            TryDocumentType(Request.GetText('documentType'), DocumentType);
            if not KeyLine.Get(DocumentType, Request.GetText('documentNo'), Request.GetInteger('lineNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'lineNo', MissingLbl));
            if Request.Contains('systemId') and (KeyLine.SystemId <> PurchaseLine.SystemId) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId', ConflictLbl));
            PurchaseLine := KeyLine;
        end;
        exit(true);
    end;

    local procedure TryDocumentType(DocumentTypeName: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
    begin
        case DocumentTypeName of
            'Quote': DocumentType := DocumentType::Quote;
            'Order': DocumentType := DocumentType::Order;
            'Invoice': DocumentType := DocumentType::Invoice;
            'Credit Memo': DocumentType := DocumentType::"Credit Memo";
            'Blanket Order': DocumentType := DocumentType::"Blanket Order";
            'Return Order': DocumentType := DocumentType::"Return Order";
            else exit(false);
        end;
        exit(true);
    end;

    local procedure LineType(LineTypeName: Text): Enum "Job Line Type"
    begin
        case LineTypeName of
            'budget': exit("Job Line Type"::Budget);
            'billable': exit("Job Line Type"::Billable);
            'both': exit("Job Line Type"::"Both Budget and Billable");
        end;
    end;
}
