namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.WIP;

/// <summary>Implements the version 1 Projects.WIP.Reverse contract.</summary>
codeunit 70013406 "Proj. WIP Reverse Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori", "Msg Confirm ori"
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
        DescriptionLbl: Label 'Reverses posted project WIP in the general ledger, keeping calculated WIP unchanged.', Comment = 'is-IS=Bakfærir bókuð verk í vinnslu í fjárhag án þess að breyta reiknuðum færslum.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, job, work in progress, WIP, reverse', Comment = 'is-IS=verkefni, verk, verk í vinnslu, VÍV, bakfæra';
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
        WIP: Codeunit "Projects WIP ori";
    begin
        Parameters := WIP.ReverseParameters();
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        ResponseField: JsonObject;
        FieldName: Text;
    begin
        foreach FieldName in 'status,projectNo,reversedEntries,wip,nextStep,summary'.Split(',') do begin
            Clear(ResponseField);
            ResponseField.Add('name', FieldName);
            case FieldName of
                'reversedEntries':
                    begin
                        ResponseField.Add('type', 'array');
                        ResponseField.Add('description', 'Reversed posted WIP entries: entryNo, accountNo, balanceAccountNo, type and amount.');
                    end;
                'wip':
                    begin
                        ResponseField.Add('type', 'object');
                        ResponseField.Add('description', 'Current WIP in the Projects.WIP.Get shape: status, projectNo, entries and glEntries.');
                    end;
                else
                    ResponseField.Add('type', 'string');
            end;
            Fields.Add(ResponseField);
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;
    /// <summary>Declares contract and native validation failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Project does not exist.', 'Check projectNo with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'Send projectNo, postingDate and documentNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid parameter type or length.', 'Use the declared parameter format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Unsupported parameter.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'No reversible posted WIP, completed WIP, or native posting refusal.', 'Projects.WIP.Get'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Posting permission is required.', 'Ask for BIFROST Full ori and native project and posting permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'Preview only; nothing changed.', 'Repeat with expectedCount from the preview.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'The posted entry count changed.', 'Review the preview and send its expectedCount.'));
        exit(true);
    end;
    /// <summary>Documents transactional native writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ExpectedCountUnitTxt: Label 'expectedCount counts posted WIP entries marked for reversal that have not yet been reversed. Preview by omitting expectedCount; nothing is posted when confirmation is required.', Locked = true;
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Posts correcting general ledger entries, marks eligible posted WIP reversed and preserves calculated WIP. ' + ExpectedCountUnitTxt);
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
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.WIP.Get', 'Inspect calculated and posted WIP.'));
        Related.Add(Contract.RelatedEntry('Projects.WIP.Calculate', 'Recalculate after reversal.'));
        Related.Add(Contract.RelatedEntry('Projects.WIP.Post', 'Post newly calculated WIP.'));
        exit(true);
    end;
    /// <summary>No additional workflow chapter is declared.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;
    /// <summary>Provides a minimal request example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Request: JsonObject;
    begin
        Request.Add('projectNo', 'XPROJECT');
        Request.Add('postingDate', '2026-10-31');
        Request.Add('documentNo', 'XWIP-REV');
        Example.Add('description', 'Preview eligible entries; repeat with expectedCount from the response to confirm.');
        Example.Add('data', Request);
        Examples.Add(Example);
        exit(true);
    end;
    /// <summary>Provides the English-only operation help chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use Reverse Only on Post WIP to G/L to correct posted project WIP. Calculated WIP stays unchanged. Review Projects.WIP.Get first, preview the entry count, then confirm. After reversal, use Projects.WIP.Calculate before posting again.';
        exit(true);
    end;
    /// <summary>Documents nested write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'postingDate and documentNo are required. The date cannot precede any entry being reversed. Completed WIP cannot be reversed. Requires BIFROST Full ori and native project and G/L posting permissions. Reversal posts correcting entries and deletes nothing.', Locked = true;
    begin
        Notes := NotesLbl;
        exit(true);
    end;
    /// <summary>Guards licensing and permissions before transactional execution.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Dispatch: Codeunit "Projects Write ori";
    begin
        if not AssertPermissions(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Dispatch.Execute(Argument, 'WIP', 'Reverse');
    end;

    /// <summary>Validates and counts exactly the posted entries the native reversal will affect.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        WIP: Codeunit "Projects WIP ori";
        CountLbl: Label 'posted project WIP entries to reverse', Comment = 'is-IS=bókaðar færslur verka í vinnslu sem á að bakfæra';
    begin
        if not AssertPermissions(Argument) then
            exit(false);
        Summary := CountLbl;
        exit(WIP.ValidateReverse(Argument, Count));
    end;

    local procedure AssertPermissions(var Argument: Record "Message Argument ori"): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        PostingGate: Codeunit "Proj. Posting Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, GetFilterTableNo(), true) then
            exit(false);
        if not PostingGate.AssertCanPost(Argument) then
            exit(false);
        if not Gate.AssertEnabled(Argument, Database::Job, true) then
            exit(false);
        if not Gate.AssertEnabled(Argument, Database::"Job WIP Entry", false) then
            exit(false);
        if not Gate.AssertEnabled(Argument, Database::"Job WIP G/L Entry", false) then
            exit(false);
        exit(true);
    end;
}
