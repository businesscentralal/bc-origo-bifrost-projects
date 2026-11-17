namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Supplies strict empty-input contracts for test-extension-only fixture operations.</summary>
codeunit 97117 "TS Fixture Contract ori" implements "Msg Contract ori"
{
    /// <summary>Declares no subject or required input.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Only fixed fixture identifiers can be used.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No parameters are accepted, so the normal strict write validation remains active.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns either created fixture counts or remaining cleanup counts.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success after the fixed fixture operation.'));
        Fields.Add(Contract.ResponseField('resources', 'integer', 'Created resources for seed.'));
        Fields.Add(Contract.ResponseField('headers', 'integer', 'Created headers for seed.'));
        Fields.Add(Contract.ResponseField('lines', 'integer', 'Created lines for seed.'));
        Fields.Add(Contract.ResponseField('details', 'integer', 'Created details for seed.'));
        Fields.Add(Contract.ResponseField('resourcesRemaining', 'integer', 'Resources remaining after cleanup.'));
        Fields.Add(Contract.ResponseField('headersRemaining', 'integer', 'Headers remaining after cleanup.'));
        Fields.Add(Contract.ResponseField('linesRemaining', 'integer', 'Lines remaining after cleanup.'));
        Fields.Add(Contract.ResponseField('detailsRemaining', 'integer', 'Details remaining after cleanup.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Native fixture collisions and permission checks raise errors without partial setup.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares writes so the normal strict dispatcher checks apply.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        exit(true);
    end;

    /// <summary>Uses the standard dispatcher context.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No product workflow depends on these test-only types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No product workflow depends on these test-only types.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Uses an empty fixed-fixture request.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains that the fixture is restricted to the test extension and CRONUS companies.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Test extension only. Creates or removes fixed, isolated issue 62 native records in a CRONUS verification company with native write rights. Never changes consent, trial, licence, counters or provider configuration.';
        exit(true);
    end;

    /// <summary>No additional notes are needed.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;
}
