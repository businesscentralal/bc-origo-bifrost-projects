namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;

/// <summary>
/// Implements the version 1 Projects.ItemCost.Update contract (#77): brings the item cost on project usage entries and
/// planning lines up to the adjusted item cost, as the Update Project Item Cost batch job does. Every refusal is
/// answered before anything changes; the native batch job runs in "Proj. Item Cost Process ori" so an error rolls back.
/// </summary>
codeunit 70013417 "Proj. Item Cost Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the posting token and the native rights before advertising availability.</summary>
    procedure IsEnabled(): Boolean
    var
        ItemCost: Codeunit "Projects Item Cost ori";
    begin
        exit(ItemCost.IsEnabled());
    end;

    /// <summary>Identifies the project table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Job);
    end;

    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Updates the item cost on project usage entries and planning lines to the adjusted item cost.', Comment = 'is-IS=Uppfærir vörukostnað á notkunarfærslum og áætlunarlínum verkefna í leiðréttan vörukostnað.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'update project item cost, project item cost, job item cost, cost adjustment, adjusted cost, project profitability, month end', Comment = 'is-IS=uppfæra vörukostnað verkefna, vörukostnaður verkefna, kostnaðarleiðrétting, leiðréttur kostnaður, vörukostnaður á verkefni, arðsemi verkefna, mánaðarlok';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Bring the item cost of project usage up to the adjusted item cost after a cost adjustment, as the Update Project Item Cost batch job does. Irreversible. Needed only when Automatic Update Project Item Cost is off in Projects Setup, or for projects adjusted earlier.', Comment = 'is-IS=Færðu vörukostnað verkefnanotkunar upp í leiðréttan vörukostnað eftir kostnaðarleiðréttingu, eins og keyrslan Uppfæra vörukostnað verkefna gerir. Óafturkræft. Aðeins nauðsynlegt þegar slökkt er á sjálfvirkri uppfærslu vörukostnaðar verkefna í uppsetningu verkefna, eða fyrir verkefni sem voru leiðrétt áður.';
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

    /// <summary>Declares the optional project selector.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.projectNos', 'project no. list', 'Exact project numbers; or send allOpen.'));
        exit(true);
    end;

    /// <summary>Declares the request parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemCost: Codeunit "Projects Item Cost ori";
    begin
        Parameters := ItemCost.Parameters();
        exit(true);
    end;

    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('projects', 'array', 'One entry per project in scope: projectNo, entriesUpdated (usage entries whose cost changed) and costChangeLCY (change in total cost, local currency).'));
        Fields.Add(Contract.ResponseField('totalEntriesUpdated', 'integer', 'Usage entries whose cost changed, over all projects. 0 when there was nothing to update.'));
        Fields.Add(Contract.ResponseField('summary', 'string', 'One sentence with the totals.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares the coded refusals and Business Central failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Both projectNos and allOpen were sent. Nothing was changed.', 'Send either projectNos or allOpen.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Neither projectNos nor allOpen was sent, or projectNos is empty. Nothing was changed.', 'Send projectNos with 1 to 100 project numbers, or allOpen as true.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A project in projectNos does not exist. Nothing was changed.', 'Send the numbers of existing projects.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'A project in projectNos has status Completed. Nothing was changed.', 'Leave the project out, or change its status with Projects.Project.SetStatus first.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong type or length, more than 100 projects were sent, or a date is not an ISO date. Nothing was changed.', 'Use the declared parameter schema.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'postingDateFrom is later than postingDateTo. Nothing was changed.', 'Send postingDateFrom on or before postingDateTo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has a key that is not declared. Nothing was changed.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the posting right or the Business Central permissions to change project ledger entries and planning lines. Nothing was changed.', 'Ask an administrator for BIFROST Full ori and the native project permissions.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refuses the update. Everything is rolled back.', 'Read the text, correct the cause and retry.'));
        exit(true);
    end;

    /// <summary>Documents the irreversible update.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('Every named project exists and is not Completed.');
        Preconditions.Add('The cost adjustment has been run for the items used on the projects.');
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'expectedCount counts the projects in scope: the projects named in projectNos, or every project in status Planning, Quote or Open for allOpen. Sets the cost of item usage entries to the adjusted cost, updates the planning lines that were created by the system and not yet transferred to an invoice, and moves the project link onto new value entries. Nothing is posted to the general ledger and nothing is deleted. To read the count without a side effect, send the same request without expectedCount while confirmation is enabled and read expected in the ConfirmationRequired answer; nothing is changed.');
        Effect.Add('idempotent', true);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>No additional app-specific meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Points to the related operations.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.Statistics.Get', 'You want to read the project profitability after the update.'));
        Related.Add(Contract.RelatedEntry('Projects.BudgetVsActual.Get', 'You want to compare the updated actual cost with the budget.'));
        exit(true);
    end;

    /// <summary>Shows the usual month-end sequence.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Projects.ItemCost.Update', 'After the cost adjustment has run, bring the project item cost up to the adjusted cost.'));
        Steps.Add(Contract.WorkflowStep('Projects.Statistics.Get', 'Read the project profitability.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides request examples.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Update two named projects',
            '{"type":"Projects.ItemCost.Update","data":{"projectNos":["JOB00010","JOB00020"],"expectedCount":2}}',
            '{"status":"Success","projects":[{"projectNo":"JOB00010","entriesUpdated":3,"costChangeLCY":24.5},{"projectNo":"JOB00020","entriesUpdated":0,"costChangeLCY":0}],"totalEntriesUpdated":3,"summary":"Updated the item cost on 3 project ledger entries in 2 projects."}'));
        Examples.Add(Contract.Example('Preview every open project',
            '{"type":"Projects.ItemCost.Update","data":{"allOpen":true}}',
            '{"status":"Error","code":"ConfirmationRequired","parameter":"expectedCount","expected":"12","nextStep":"Send the same request again with expectedCount set to 12."}'));
        exit(true);
    end;

    /// <summary>Provides the English help overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Brings the item cost on project usage entries and planning lines up to the adjusted item cost, the way the Update Project Item Cost batch job does. ' +
            'Use it after a cost adjustment so that project profitability is right. Irreversible.';
        exit(true);
    end;

    /// <summary>Documents the behaviour in English.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'When Automatic Update Project Item Cost is turned on in Projects Setup, Business Central already runs this update for the projects it adjusted at the end of every cost adjustment. ' +
            'Run the cost adjustment (Adjust Cost - Item Entries) first: this operation only brings the project up to the cost the adjustment has already calculated. ' +
            'This operation is needed only when that setting is off, or for projects that were adjusted earlier. ' +
            'Only usage of items on projects in status Planning, Quote or Open is updated; a Completed project named in projectNos is refused. ' +
            'postingDateFrom and postingDateTo limit the usage entries by posting date. ' +
            'Nothing is posted to the general ledger and nothing is deleted. When there is nothing to update the answer is Success with zero counts. ' +
            'Refusals and their nextStep are answered in the session language.';
        exit(true);
    end;

    /// <summary>Checks rights, licence and version, then updates the item cost.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemCost: Codeunit "Projects Item Cost ori";
        Input: Codeunit "Projects Followup Input ori";
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and the native permissions to change project ledger entries.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar heimildir til að breyta verkefnisfærslum.';
    begin
        if not ItemCost.IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ItemCost.Execute(Argument);
    end;
}
