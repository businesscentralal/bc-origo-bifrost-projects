namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Implements the follow-up operation and its discovery contract.</summary>
codeunit 70013448 "Proj. FU Req Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Records follow-up work for the technician.', Comment = 'is-IS=Skráir eftirfylgnivinnu fyrir tæknimann.';
        KeywordsLbl: Label 'project, follow-up, request, technician, manager', Comment = 'is-IS=verkefni, eftirfylgni, beiðni, tæknimaður, stjórnandi';
        OverviewLbl: Label 'Technicians record extra work without changing the project. Managers preview and convert requests into tasks and planning lines, or reject them with a reason.', Locked = true;
        NotesLbl: Label 'Requests remain after a decision. Only open requests can be converted or rejected. Conversion preview performs native validation and rolls back all changes. No email is sent. Dates use YYYY-MM-DD. List defaults to your own requests for technicians and your managed projects for managers.', Locked = true;

    /// <summary>Implements the follow-up contract.</summary>
    procedure IsEnabled(): Boolean
    var
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
    begin
        exit(Mgt.CanRun(1));
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Projects.FollowUp.Request: ' + DescriptionLbl);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements the follow-up contract.</summary>
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

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        VisitContract: Codeunit "Proj. Follow-up Contract ori";
    begin
        VisitContract.AddParameters(Parameters, 1);
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Follow-up Contract ori";
    begin
        VisitContract.AddResponse(Response);
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        VisitContract: Codeunit "Proj. Follow-up Contract ori";
    begin
        VisitContract.AddErrors(Errors);
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.FollowUp.List', KeywordsLbl));
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Follow-up request', '{"type":"Projects.FollowUp.Request","data":{"projectNo":"P00010","taskNo":"1000","description":"Replace valve","estimatedHours":3}}', '{"status":"Success","summary":"Follow-up request processed."}'));
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Implements the follow-up contract.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
    begin
        Mgt.Execute(Argument, 1);
    end;
}
