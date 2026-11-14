namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Foundation.Reporting;
using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Customer;

/// <summary>
/// Implements the version 1 Projects.Quote.Send contract (#15): sends a project quote through a Document Sending
/// Profile the way the Send Project Quote action on the project card does. Every refusal is checked before anything
/// is sent; the native send runs in "Proj. Quote Send Process ori" so a Business Central error rolls back.
/// </summary>
codeunit 70013548 "Proj. Quote Send Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    Permissions = tabledata Job = R,
                  tabledata Customer = R,
                  tabledata "Document Sending Profile" = R;

    /// <summary>Checks company enablement and native project read permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Job, false));
    end;

    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Job);
    end;

    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Sends a project quote to the bill-to customer through a document sending profile.', Comment = 'is-IS=Sendir verkefnistilboð til reikningsviðskiptamanns með forstillingu skjalasendingar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'send project quote, send job quote, email the project quote, project quote, job quote, quote to customer, send quote, document sending profile', Comment = 'is-IS=senda verkefnistilboð, senda verktilboð, senda verkefnistilboð í tölvupósti, verkefnistilboð, verktilboð, tilboð til viðskiptamanns, senda tilboð, forstilling skjalasendingar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Send the quote of a project in status Quote to its bill-to customer through a document sending profile, as the Send Project Quote action on the project card does. Irreversible. To change the project status first, use Projects.Project.SetStatus.', Comment = 'is-IS=Senda tilboð verkefnis í stöðunni Tilboð til reikningsviðskiptamanns þess með forstillingu skjalasendingar, eins og aðgerðin Senda verkefnistilboð á verkefnaspjaldinu. Óafturkræft. Til að breyta stöðu verkefnisins fyrst, notaðu Projects.Project.SetStatus.';
    begin
        exit(SelectionLbl);
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

    /// <summary>Declares the target key.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.projectNo', 'project no.', 'The exact native project number of a project in status Quote.'));
        exit(true);
    end;

    /// <summary>Declares the request parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := RequestSchema();
        exit(true);
    end;

    /// <summary>The request schema, shared by the contract and the input validation.</summary>
    /// <returns>The parameter entries for projectNo and documentSendingProfile.</returns>
    internal procedure RequestSchema() Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Entry: JsonObject;
    begin
        Entry := ContractMgt.Parameter('projectNo', 'string', true, 'Exact native project number. The project must be in status Quote and have a bill-to customer.');
        Entry.Add('maxLength', 20);
        Result.Add(Entry);
        Clear(Entry);
        Entry := ContractMgt.Parameter('documentSendingProfile', 'string', false,
            'Code of the Document Sending Profile to use for this call only, at most 20 characters; a longer value is refused (InvalidParameterFormat), never cut. Must exist, must not save to disk and must not prompt for e-mail settings. Left out: the bill-to customer''s profile, then the profile marked Default.');
        Entry.Add('maxLength', 20);
        Result.Add(Entry);
    end;

    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Source: JsonObject;
        Sources: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('projectNo', 'string', 'No. of the project whose quote was sent.'));
        Fields.Add(ContractMgt.ResponseField('projectId', 'string', 'SystemId of the project (GUID, no braces).'));
        Fields.Add(ContractMgt.ResponseField('customerNo', 'string', 'Bill-to Customer No. of the project; the quote goes to this customer.'));
        Fields.Add(ContractMgt.ResponseField('customerName', 'string', 'Bill-to Name of the project.'));
        Fields.Add(ContractMgt.ResponseField('documentSendingProfileCode', 'string', 'Code of the Document Sending Profile that was used.'));
        Sources.Add('Request');
        Sources.Add('Customer');
        Sources.Add('Default');
        Source := ContractMgt.ResponseField('documentSendingProfileSource', 'string', 'Where the profile came from: Request (documentSendingProfile), Customer (the bill-to customer''s Document Sending Profile) or Default (the profile marked Default).');
        Source.Add('allowed', Sources);
        Fields.Add(Source);
        Fields.Add(ContractMgt.ResponseField('archived', 'boolean', 'True when Business Central stored a new project archive version after sending (Projects Setup, Archive Projects).'));
        Fields.Add(ContractMgt.ResponseField('message', 'string', 'Project quote sent.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares the coded refusals and Business Central failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Projects messages are disabled for this company.', 'Enable Projects in Projects Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission denied for this Projects message type.', 'The caller has no read permission on Job.', 'Ask an administrator for the required Business Central role.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Projects data must be a JSON object, or a key has the wrong JSON type or length.',
            'data is not an object, projectNo is not a string of at most 20 characters, or documentSendingProfile is not a string of at most 20 characters. A longer code is refused, never cut. Nothing was sent.', 'Use the declared parameter schema.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required Projects parameter is missing or empty.', 'projectNo is missing or empty. Nothing was sent.', 'Supply the key named by parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several input values are invalid; errors[] lists each. Nothing was sent.', 'Correct every entry in errors and retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Project {projectNo} does not exist.', 'parameter is projectNo. Nothing was sent.', 'Send the No. of an existing project.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Project {projectNo} has status {status}; only a project in status Quote can send a quote.',
            'parameter is projectNo, received is the current status, expected is Quote. Nothing was sent.', 'Set the project status to Quote with Projects.Project.SetStatus, or send a project that is in status Quote.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Project {projectNo} has no bill-to customer, or bill-to customer {customerNo} does not exist.',
            'The quote is sent to the bill-to customer. parameter is projectNo. Nothing was sent.', 'Set an existing Bill-to Customer No. on the project with Projects.Project.Update, then retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Document Sending Profile "{code}" not found.',
            'documentSendingProfile names a profile that does not exist. Nothing was sent.', 'Send the Code of an existing Document Sending Profile, or leave the key out.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Document Sending Profile "{code}" referenced by customer {customerNo} does not exist.',
            'The bill-to customer''s Document Sending Profile field names a profile that was deleted. Nothing was sent.', 'Fix the profile on the customer card, or send documentSendingProfile.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'No Document Sending Profile resolved for customer {customerNo} and no system default profile exists.',
            'No documentSendingProfile was sent, the customer has no profile and no profile is marked Default. Nothing was sent.', 'Send documentSendingProfile, give the customer a profile, or mark one profile Default.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Document Sending Profile "{code}" saves the document to disk, which needs a client; it cannot run through the API.',
            'The resolved profile has a Disk channel. parameter is documentSendingProfile. Nothing was sent.', 'Send documentSendingProfile with a profile that has no Disk channel: E-Mail, Electronic Document, or Printer with default settings.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Document Sending Profile "{code}" prompts for e-mail settings, which needs a client; it cannot run through the API.',
            'E-Mail is Yes (Prompt for Settings). parameter is documentSendingProfile and received is the resolved profile code. Nothing was sent.', 'Pass documentSendingProfile with E-Mail set to Yes (Use Default Settings), or change the resolved profile.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Customer {customerNo} has no e-mail address for Document Sending Profile {code}.',
            'The resolved profile sends e-mail and the bill-to customer has no e-mail address for the project quote. parameter is email. Nothing was sent.', 'Set the customer e-mail address or select a sending profile that does not send e-mail, then retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own error text',
            'Business Central refuses to send, e.g. no e-mail account set up, no report for the Report Selection usage Project Quote, an electronic document format that does not support project quotes, or any failure of a Printer channel. The send and the archive roll back.',
            'Read the text: it names the setup to fix. Check Sent Emails before sending again: a channel that ran before the failure may already have delivered the quote.'));
        exit(true);
    end;

    /// <summary>Documents the irreversible send.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The project exists, is in status Quote and has an existing bill-to customer.');
        Preconditions.Add('A Document Sending Profile resolves: documentSendingProfile, the bill-to customer''s profile or the Default profile. A profile with a Disk channel or an e-mail settings prompt is refused before anything is sent.');
        Preconditions.Add('E-Mail: an e-mail account, a customer e-mail address and a report for the Report Selection usage Project Quote are set up.');
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Sends the project quote with the resolved profile, as the Send Project Quote action does: the quote goes out through every channel the profile enables. Afterwards Business Central archives the project when Projects Setup, Archive Projects, is Always or Question.');
        Effect.Add('idempotent', false);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>No additional app-specific meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Points to the status change that makes a quote sendable.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Projects.Project.SetStatus', 'The project is not in status Quote yet.'));
        Related.Add(ContractMgt.RelatedEntry('Projects.Project.Create', 'The project does not exist yet.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You want to check which channels a Document Sending Profile enables, or read Sent Emails afterwards.'));
        exit(true);
    end;

    /// <summary>Shows the usual sequence.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Projects.Project.Create', 'Create the project with its bill-to customer, tasks and planning lines.'));
        Steps.Add(ContractMgt.WorkflowStep('Projects.Project.SetStatus', 'Set status Quote.'));
        Steps.Add(ContractMgt.WorkflowStep('Projects.Quote.Send', 'Send the quote to the bill-to customer.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides request examples.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Send with the customer''s profile',
            '{"type":"Projects.Quote.Send","data":{"projectNo":"JOB00010"}}',
            '{"status":"Success","projectNo":"JOB00010","projectId":"<systemId>","customerNo":"10000","customerName":"Adatum Corporation","documentSendingProfileCode":"EMAIL","documentSendingProfileSource":"Customer","archived":false,"message":"Project quote sent."}'));
        Examples.Add(ContractMgt.Example('A project that is not in status Quote is refused',
            '{"type":"Projects.Quote.Send","data":{"projectNo":"JOB00020"}}',
            '{"status":"Error","code":"PreconditionFailed","error":"Project JOB00020 has status Open; only a project in status Quote can send a quote.","parameter":"projectNo","received":"Open","expected":"Quote","nextStep":"Set the project status to Quote with Projects.Project.SetStatus, or send a project that is in status Quote."}'));
        exit(true);
    end;

    /// <summary>Provides the English help overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Sends the quote of a project in status Quote to its bill-to customer the way the Send Project Quote action on the project card does, through a Document Sending Profile: ' +
            'the one named in the request, else the bill-to customer''s, else the profile marked Default. Irreversible.';
        exit(true);
    end;

    /// <summary>Documents send behaviour in English.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Success means Business Central ran every channel of the profile without an error, not that the customer received the quote; sent e-mails are in Sent Emails. ' +
            'Not retry-safe: a second call sends the quote again. ' +
            'The request, the project and the profile are all checked before anything is sent. The confirmation window of the card action is not shown: the resolved profile is used as it is. ' +
            'A profile with a Disk channel or with E-Mail set to Yes (Prompt for Settings) is refused (PreconditionFailed), because both need a client. A Printer channel is passed to Business Central; any failure comes back as BusinessCentralError. ' +
            'The documentSendingProfile code is compared in upper case. Refusals and their nextStep are answered in the session language.';
        exit(true);
    end;

    /// <summary>Checks enablement, licence and version, then sends the quote.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Setup: Record "Projects Setup ori";
        Gate: Codeunit "Projects Gate ori";
        DisabledErr: Label 'Projects messages are disabled for this company.', Comment = 'is-IS=Verkefnaskilaboð eru óvirk fyrir þetta fyrirtæki.';
        EnableLbl: Label 'Enable Projects in Projects Setup.', Comment = 'is-IS=Virkjaðu verkefni í uppsetningu verkefna.';
        DeniedErr: Label 'Permission denied for this Projects message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa verkefnaskilaboðategund.';
        DeniedNextStepLbl: Label 'Ask an administrator for a Business Central role that can read projects.', Comment = 'is-IS=Biddu kerfisstjóra um hlutverk í Business Central sem getur lesið verkefni.';
    begin
        if not Setup.IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DisabledErr, '', '', '', EnableLbl);
            exit;
        end;
        if not Gate.IsEnabled(GetFilterTableNo(), false) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedErr, '', '', '', DeniedNextStepLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        SendQuote(Argument);
    end;

    /// <summary>Validates the request, the project and the profile, then sends; nothing is sent after a refusal.</summary>
    /// <param name="Argument">The request; receives the answer.</param>
    internal procedure SendQuote(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        DocumentSendingProfile: Record "Document Sending Profile";
        Request: JsonObject;
        OverrideCode: Code[20];
        ProfileSource: Text;
        InvalidErr: Label 'Projects data must be a JSON object.', Comment = 'is-IS=Verkefnisgögn verða að vera JSON-hlutur.';
        SummaryErr: Label 'Correct the invalid Projects parameters.', Comment = 'is-IS=Leiðréttu ógild viðföng verkefnis.';
        NextStepLbl: Label 'Send data as a JSON object with projectNo.', Comment = 'is-IS=Sendu data sem JSON-hlut með projectNo.';
    begin
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'data', '', 'object', NextStepLbl);
            exit;
        end;
        if not ValidateInput(Argument, Request) then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, SummaryErr);
            exit;
        end;
        if not TryCheckProject(Argument, Request, Project) then
            exit;
        OverrideCode := ReadOverride(Request);
        if not TryResolveProfile(Project."Bill-to Customer No.", OverrideCode, DocumentSendingProfile, ProfileSource, Argument) then
            exit;
        if not CheckEmailAddress(Project, DocumentSendingProfile, Argument) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Quote Send Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Quote Send Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Collects every malformed key with its nextStep; a value is never cut.</summary>
    local procedure ValidateInput(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Token: JsonToken;
        MissingErr: Label 'A required Projects parameter is missing or empty.', Comment = 'is-IS=Nauðsynlegt viðfang verkefnis vantar eða er tómt.';
        ProjectNextStepLbl: Label 'Send projectNo as the No. of a project in status Quote.', Comment = 'is-IS=Sendu projectNo sem númer verkefnis í stöðunni Tilboð.';
        BadErr: Label 'A Projects parameter does not match its declared type, length or allowed values.', Comment = 'is-IS=Viðfang verkefnis passar ekki við skilgreinda gerð, lengd eða leyfileg gildi.';
        CodeExpectedLbl: Label 'a JSON string of at most 20 characters', Comment = 'is-IS=JSON-strengur með mest 20 stöfum';
        ProfileNextStepLbl: Label 'Send documentSendingProfile as a JSON string of at most 20 characters, or leave the key out. A longer code is refused, never cut.', Comment = 'is-IS=Sendu documentSendingProfile sem JSON-streng með mest 20 stöfum, eða slepptu lyklinum. Lengri kóða er hafnað, hann er aldrei styttur.';
    begin
        if not Request.Get('projectNo', Token) then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'projectNo', '', CodeExpectedLbl, ProjectNextStepLbl)
        else
            if not IsCodeString(Token) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, BadErr, 'projectNo', RawText(Token), CodeExpectedLbl, ProjectNextStepLbl)
            else
                if Token.AsValue().AsText().Trim() = '' then
                    Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'projectNo', '', CodeExpectedLbl, ProjectNextStepLbl);
        if Request.Get('documentSendingProfile', Token) then
            if not IsCodeString(Token) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, BadErr, 'documentSendingProfile', RawText(Token), CodeExpectedLbl, ProfileNextStepLbl);
        exit(not Argument.HasCollectedErrors());
    end;

    local procedure IsCodeString(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        if not RawText(Token).StartsWith('"') then
            exit(false);
        exit(StrLen(Token.AsValue().AsText()) <= 20);
    end;

    local procedure RawText(Token: JsonToken) Raw: Text
    begin
        Token.WriteTo(Raw);
        exit(CopyStr(Raw, 1, 250));
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    /// <summary>Reads the optional profile override in upper case; the schema check already limited its length.</summary>
    /// <param name="Request">The validated request.</param>
    /// <returns>The profile code, or an empty code when none was sent.</returns>
    internal procedure ReadOverride(Request: JsonObject): Code[20]
    var
        Token: JsonToken;
        OverrideCode: Code[20];
    begin
        if not Request.Get('documentSendingProfile', Token) then
            exit('');
        OverrideCode := CopyStr(UpperCase(Token.AsValue().AsText()), 1, MaxStrLen(OverrideCode));
        exit(OverrideCode);
    end;

    /// <summary>Finds the project and refuses one that is not in status Quote or has no usable bill-to customer.</summary>
    /// <param name="Argument">Receives the coded refusal.</param>
    /// <param name="Request">The validated request.</param>
    /// <param name="Project">Returns the project.</param>
    /// <returns>True when the quote can be sent.</returns>
    internal procedure TryCheckProject(var Argument: Record "Message Argument ori"; Request: JsonObject; var Project: Record Job): Boolean
    var
        Customer: Record Customer;
        ProjectNo: Code[20];
        NotFoundErr: Label 'Project %1 does not exist.', Comment = '%1 = project no., is-IS=Verkefni %1 er ekki til.';
        NotFoundNextStepLbl: Label 'Send the No. of an existing project.', Comment = 'is-IS=Sendu númer verkefnis sem er til.';
        ExistingProjectLbl: Label 'the No. of an existing project', Comment = 'is-IS=númer verkefnis sem er til';
        NotQuoteErr: Label 'Project %1 has status %2; only a project in status Quote can send a quote.', Comment = '%1 = project no., %2 = project status, is-IS=Verkefni %1 hefur stöðuna %2; aðeins verkefni í stöðunni Tilboð getur sent tilboð.';
        NotQuoteNextStepLbl: Label 'Set the project status to Quote with Projects.Project.SetStatus, or send a project that is in status Quote.', Comment = 'is-IS=Stilltu stöðu verkefnisins á Tilboð með Projects.Project.SetStatus, eða sendu verkefni sem er í stöðunni Tilboð.';
        NoCustomerErr: Label 'Project %1 has no bill-to customer.', Comment = '%1 = project no., is-IS=Verkefni %1 hefur engan reikningsviðskiptamann.';
        MissingCustomerErr: Label 'Bill-to customer %2 of project %1 does not exist.', Comment = '%1 = project no., %2 = customer no., is-IS=Reikningsviðskiptamaður %2 á verkefni %1 er ekki til.';
        CustomerNextStepLbl: Label 'Set an existing Bill-to Customer No. on the project with Projects.Project.Update, then retry. Nothing was sent.', Comment = 'is-IS=Settu reikningsviðskiptamann sem er til á verkefnið með Projects.Project.Update og reyndu aftur. Ekkert var sent.';
        CustomerExpectedLbl: Label 'a project with an existing bill-to customer', Comment = 'is-IS=verkefni með reikningsviðskiptamanni sem er til';
    begin
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        if not Project.Get(ProjectNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ProjectNo), 'projectNo', ProjectNo, ExistingProjectLbl, NotFoundNextStepLbl);
            exit(false);
        end;
        if Project.Status <> Project.Status::Quote then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotQuoteErr, Project."No.", Project.Status), 'projectNo', StatusName(Project.Status), StatusName(Project.Status::Quote), NotQuoteNextStepLbl);
            exit(false);
        end;
        if Project."Bill-to Customer No." = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoCustomerErr, Project."No."), 'projectNo', Project."No.", CustomerExpectedLbl, CustomerNextStepLbl);
            exit(false);
        end;
        if not Customer.Get(Project."Bill-to Customer No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(MissingCustomerErr, Project."No.", Project."Bill-to Customer No."), 'projectNo', Project."Bill-to Customer No.", CustomerExpectedLbl, CustomerNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Answers a status by its English enum name, whatever the session language.</summary>
    local procedure StatusName(Status: Enum "Job Status"): Text
    begin
        exit(Status.Names().Get(Status.Ordinals().IndexOf(Status.AsInteger())));
    end;

    /// <summary>
    /// Resolves the Document Sending Profile: request override, then the bill-to customer's profile, then the profile
    /// marked Default (the order of the Send Project Quote action), and refuses one that needs a client.
    /// </summary>
    /// <param name="CustomerNo">The bill-to customer of the project.</param>
    /// <param name="OverrideCode">The profile from the request, or empty.</param>
    /// <param name="DocumentSendingProfile">Returns the resolved profile.</param>
    /// <param name="Source">Returns Request, Customer or Default.</param>
    /// <param name="Argument">Receives the coded refusal.</param>
    /// <returns>True when a usable profile resolved.</returns>
    internal procedure TryResolveProfile(CustomerNo: Code[20]; OverrideCode: Code[20]; var DocumentSendingProfile: Record "Document Sending Profile"; var Source: Text; var Argument: Record "Message Argument ori"): Boolean
    var
        Customer: Record Customer;
        ProfileNotFoundErr: Label 'Document Sending Profile "%1" not found.', Comment = '%1 = profile code, is-IS=Forstilling skjalasendingar "%1" fannst ekki.';
        ProfileNotFoundNextStepLbl: Label 'Send the Code of an existing Document Sending Profile, or leave the key out.', Comment = 'is-IS=Sendu kóða forstillingar skjalasendingar sem er til, eða slepptu lyklinum.';
        ProfileExpectedLbl: Label 'the Code of an existing Document Sending Profile', Comment = 'is-IS=kóði forstillingar skjalasendingar sem er til';
        NoProfileExpectedLbl: Label 'a Document Sending Profile on the customer, or one profile marked Default', Comment = 'is-IS=forstilling skjalasendingar á viðskiptamanninum, eða ein forstilling merkt sem sjálfgefin';
        CustomerProfileMissingErr: Label 'Document Sending Profile "%1" referenced by customer %2 does not exist.', Comment = '%1 = profile code, %2 = customer no., is-IS=Forstilling skjalasendingar "%1" sem viðskiptamaður %2 vísar í er ekki til.';
        CustomerProfileNextStepLbl: Label 'Fix the profile on the customer card, or send documentSendingProfile.', Comment = 'is-IS=Lagaðu forstillingu skjalasendingar á viðskiptamannaspjaldinu, eða sendu documentSendingProfile.';
        NoProfileResolvedErr: Label 'No Document Sending Profile resolved for customer %1 and no system default profile exists.', Comment = '%1 = customer no., is-IS=Engin forstilling skjalasendingar fannst fyrir viðskiptamann %1 og engin sjálfgefin kerfisforstilling er til.';
        NoProfileNextStepLbl: Label 'Send documentSendingProfile, give the customer a profile, or mark one profile Default.', Comment = 'is-IS=Sendu documentSendingProfile, gefðu viðskiptamanninum forstillingu, eða merktu eina forstillingu sem sjálfgefna.';
    begin
        Clear(DocumentSendingProfile);
        Source := '';
        if OverrideCode <> '' then begin
            if not DocumentSendingProfile.Get(OverrideCode) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ProfileNotFoundErr, OverrideCode), 'documentSendingProfile', OverrideCode, ProfileExpectedLbl, ProfileNotFoundNextStepLbl);
                exit(false);
            end;
            Source := 'Request';
            exit(IsUsableWithoutClient(DocumentSendingProfile, Argument));
        end;
        Customer.SetLoadFields("Document Sending Profile");
        if Customer.Get(CustomerNo) and (Customer."Document Sending Profile" <> '') then begin
            if not DocumentSendingProfile.Get(Customer."Document Sending Profile") then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CustomerProfileMissingErr, Customer."Document Sending Profile", CustomerNo), 'documentSendingProfile', Customer."Document Sending Profile", ProfileExpectedLbl, CustomerProfileNextStepLbl);
                exit(false);
            end;
            Source := 'Customer';
            exit(IsUsableWithoutClient(DocumentSendingProfile, Argument));
        end;
        DocumentSendingProfile.Reset();
        DocumentSendingProfile.SetRange(Default, true);
        if DocumentSendingProfile.FindFirst() then begin
            Source := 'Default';
            exit(IsUsableWithoutClient(DocumentSendingProfile, Argument));
        end;
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoProfileResolvedErr, CustomerNo), 'documentSendingProfile', CustomerNo, NoProfileExpectedLbl, NoProfileNextStepLbl);
        exit(false);
    end;

    local procedure IsUsableWithoutClient(DocumentSendingProfile: Record "Document Sending Profile"; var Argument: Record "Message Argument ori"): Boolean
    var
        DiskProfileErr: Label 'Document Sending Profile "%1" saves the document to disk, which needs a client; it cannot run through the API.', Comment = '%1 = profile code, is-IS=Forstilling skjalasendingar "%1" vistar skjalið á disk, sem krefst biðlara; ekki er hægt að keyra hana í gegnum API.';
        DiskProfileNextStepLbl: Label 'Send documentSendingProfile with a profile that has no Disk channel: E-Mail, Electronic Document, or Printer with default settings.', Comment = 'is-IS=Sendu documentSendingProfile með forstillingu sem hefur enga Disk-rás: tölvupóst, rafrænt skjal eða prentara með sjálfgefnum stillingum.';
        DiskProfileExpectedLbl: Label 'a Document Sending Profile without a Disk channel', Comment = 'is-IS=forstilling skjalasendingar án Disk-rásar';
        PromptEmailErr: Label 'Document Sending Profile "%1" prompts for e-mail settings, which needs a client; it cannot run through the API.', Comment = '%1 = profile code, is-IS=Forstilling skjalasendingar "%1" biður um tölvupóststillingar, sem krefst biðlara; ekki er hægt að keyra hana í gegnum API.';
        PromptEmailNextStepLbl: Label 'Pass documentSendingProfile with E-Mail set to Yes (Use Default Settings), or change the resolved profile to use default e-mail settings. Nothing was sent.', Comment = 'is-IS=Sendu documentSendingProfile með E-Mail stillt á Yes (Use Default Settings), eða breyttu forstillingunni sem fannst þannig að hún noti sjálfgefnar tölvupóststillingar. Ekkert var sent.';
        PromptEmailExpectedLbl: Label 'a Document Sending Profile without an e-mail settings prompt', Comment = 'is-IS=forstilling skjalasendingar sem biður ekki um tölvupóststillingar';
    begin
        if DocumentSendingProfile.Disk <> DocumentSendingProfile.Disk::No then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DiskProfileErr, DocumentSendingProfile.Code), 'documentSendingProfile', DocumentSendingProfile.Code, DiskProfileExpectedLbl, DiskProfileNextStepLbl);
            exit(false);
        end;
        if DocumentSendingProfile."E-Mail" = DocumentSendingProfile."E-Mail"::"Yes (Prompt for Settings)" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(PromptEmailErr, DocumentSendingProfile.Code), 'documentSendingProfile', DocumentSendingProfile.Code, PromptEmailExpectedLbl, PromptEmailNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure CheckEmailAddress(Project: Record Job; DocumentSendingProfile: Record "Document Sending Profile"; var Argument: Record "Message Argument ori"): Boolean
    var
        ReportSelections: Record "Report Selections";
        TempBodyReportSelections: Record "Report Selections" temporary;
        EmailAddress: Text;
        MissingEmailErr: Label 'Customer %1 has no e-mail address for Document Sending Profile %2.', Comment = '%1 = customer number, %2 = profile code, is-IS=Viðskiptamaður %1 hefur ekkert tölvupóstfang fyrir forstillingu skjalasendingar %2.';
        MissingEmailNextStepLbl: Label 'Set the customer e-mail address or select a sending profile that does not send e-mail, then retry. Nothing was sent.', Comment = 'is-IS=Stilltu tölvupóstfang viðskiptamanns eða veldu forstillingu sem sendir ekki tölvupóst og reyndu aftur. Ekkert var sent.';
        EmailExpectedLbl: Label 'a customer e-mail address for the selected sending profile', Comment = 'is-IS=tölvupóstfang viðskiptamanns fyrir valda forstillingu';
    begin
        if DocumentSendingProfile."E-Mail" = DocumentSendingProfile."E-Mail"::No then
            exit(true);
        if ReportSelections.FindEmailBodyUsageForCust("Report Selection Usage"::JQ, Project."Bill-to Customer No.", TempBodyReportSelections) then
            EmailAddress := ReportSelections.GetEmailAddressExt("Report Selection Usage"::JQ.AsInteger(), Project, Project."Bill-to Customer No.", TempBodyReportSelections)
        else
            EmailAddress := ReportSelections.GetEmailAddressIgnoringLayout("Report Selection Usage"::JQ, Project, Project."Bill-to Customer No.");
        if EmailAddress <> '' then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(MissingEmailErr, Project."Bill-to Customer No.", DocumentSendingProfile.Code), 'email', '', EmailExpectedLbl, MissingEmailNextStepLbl);
        exit(false);
    end;
}
