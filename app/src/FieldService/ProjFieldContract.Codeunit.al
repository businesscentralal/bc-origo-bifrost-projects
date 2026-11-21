namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>English help chapters and schemas for the technician read contracts.</summary>
codeunit 70013430 "Proj. Field Contract ori"
{
    Access = Internal;

    /// <summary>Declares a data-only version-one envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('dataRequired', false);
        exit(true);
    end;

    /// <summary>Declares accepted keys, including disambiguation for owners of several resources.</summary>
    procedure GetParameters(Brief: Boolean; var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('resourceNo', 'string', false, 'Owned resource, required when the caller owns several. Maximum 20 characters.'));
        Parameters.Add(Contract.Parameter('detail', 'string', false, 'Optional full detail; compact output is the default.'));
        if Brief then begin
            Parameters.Add(Contract.Parameter('projectNo', 'string', true, 'Existing project number, maximum 20 characters.'));
            Parameters.Add(Contract.Parameter('taskNo', 'string', true, 'Existing task number within the project, maximum 20 characters.'));
        end else begin
            Parameters.Add(Contract.Parameter('date', 'date', false, 'ISO date, defaults to today.'));
            Parameters.Add(Contract.Parameter('include', 'array', false, 'Optional items and address sections. Default: address.'));
        end;
        exit(true);
    end;

    /// <summary>Declares assembled read results and ready-made next actions.</summary>
    procedure GetResponse(Brief: Boolean; var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        if Brief then begin
            Fields.Add(Contract.ResponseField('project', 'object', 'projectNo and description.'));
            Fields.Add(Contract.ResponseField('task', 'object', 'taskNo and description.'));
            Fields.Add(Contract.ResponseField('site', 'object', 'Project ship-to snapshot: name, address, address2, city, postCode, country, phone.'));
            Fields.Add(Contract.ResponseField('planned', 'object', 'resources[] and items[] with no, description, remainingQuantity, unitOfMeasure, lineNo. Positive remaining quantities only.'));
            Fields.Add(Contract.ResponseField('myTime', 'object', 'Own loggedHours across all dates, timeSheetNo and timeSheetLineNo (nullable).'));
            Fields.Add(Contract.ResponseField('myUsage', 'array', 'Own task usage: entryNo, timeSheetNo, lineNo, type, no, date, quantity, unitOfMeasure, status, reversed and journal/ledger references.'));
            Fields.Add(Contract.ResponseField('recordIds', 'object', 'project and task systemIds for related apps.'));
            Fields.Add(Contract.ResponseField('history', 'array', 'Reserved for visit history; currently empty.'));
            Fields.Add(Contract.ResponseField('followUps', 'array', 'Reserved for follow-ups; currently empty.'));
        end else begin
            Fields.Add(Contract.ResponseField('technician', 'object', 'resourceNo and name of the caller.'));
            Fields.Add(Contract.ResponseField('visits', 'array', 'Each Resource planning line: projectNo, taskNo, description, customerName, phone, planningDate, lineNo, plannedHours, loggedHours, timeSheetNo, nullable timeSheetLineNo, openUsage; optional address and items.'));
            Fields.Add(Contract.ResponseField('nextVisit', 'object', 'First visit in planning order, or null when none.'));
        end;
        Fields.Add(Contract.ResponseField('summary', 'string', 'One sentence for the technician.'));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', 'Suggested type and parameters for creating a missing sheet or task line. No writes occur.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents every typed refusal and its corrective action.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required identifier is missing.', 'Send projectNo and taskNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value has the wrong type or format.', 'Use the documented types and ISO dates.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An unknown key was supplied.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The resource, project or task does not exist.', 'Use an existing identifier.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'The caller owns several resources.', 'Send resourceNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Missing rights or another owner.', 'Assign BIFROST Read ori and PROJ FIELD TECH; use an owned resource.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'No resource is mapped to the caller.', 'Ask an administrator to set your user as Time Sheet Owner User ID on your resource.'));
        exit(true);
    end;

    /// <summary>Lists the related self-service operations.</summary>
    procedure GetRelated(Brief: Boolean; var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.MyDay.Get', 'Read the day plan.'));
        Related.Add(Contract.RelatedEntry('Projects.VisitBrief.Get', 'Read one task brief.'));
        Related.Add(Contract.RelatedEntry('Projects.MyTimeSheet.Create', 'Create a missing time sheet.'));
        Related.Add(Contract.RelatedEntry('Projects.MyTimeSheetLine.Set', 'Add a missing project task line.'));
        Related.Add(Contract.RelatedEntry('Projects.Usage.List', 'Read your usage.'));
        exit(true);
    end;

    /// <summary>Provides one concrete request/response example per operation.</summary>
    procedure GetExamples(Brief: Boolean; var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Brief then
            Examples.Add(Contract.Example('Visit brief', '{"type":"Projects.VisitBrief.Get","data":{"projectNo":"XPROJECT","taskNo":"1000"}}', '{"status":"Success","project":{"projectNo":"XPROJECT"},"planned":{"resources":[],"items":[]},"myUsage":[],"history":[],"followUps":[]}'))
        else
            Examples.Add(Contract.Example('Day plan', '{"type":"Projects.MyDay.Get","data":{"date":"2026-11-20"}}', '{"status":"Success","technician":{"resourceNo":"XTECH","name":"X Technician"},"visits":[],"nextVisit":null,"nextSteps":[]}'));
        exit(true);
    end;
}
