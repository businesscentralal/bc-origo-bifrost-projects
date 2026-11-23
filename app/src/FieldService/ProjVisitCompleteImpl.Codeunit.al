namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.Visit.Complete finishes a visit and can register mileage on an open usage line.</summary>
codeunit 70013438 "Proj. Visit Complete Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Completes a visit and, with mileage, writes an open usage line on the task.', Comment = 'is-IS=Lýkur heimsókn og skrifar, með akstri, opna notkunarlínu á verkþáttinn.';
        KeywordsLbl: Label 'visit, complete, mileage, usage, time sheet, field', Comment = 'is-IS=heimsókn, ljúka, akstur, notkun, tímaskýrsla, vettvangur';
        OverviewLbl: Label 'Stops a running visit first, then marks it completed. Mileage is an open resource usage line on the task line, using the mileage resource and its unit from Projects Setup. Nothing is submitted.', Comment = 'is-IS=Stöðvar fyrst heimsókn sem er í gangi og merkir hana síðan lokið. Akstur er skráður sem opin aðfanganotkunarlína á verkþáttarlínuna með akstursaðfangi og einingu þess úr uppsetningu verkefna. Engu er skilað inn.';
        NotesLbl: Label 'The same clientRequestId returns the first result. Hours and usage lines that are already open stay. Nothing is deleted.', Comment = 'is-IS=Sama clientRequestId skilar fyrstu niðurstöðunni. Vinnustundir og notkunarlínur sem eru þegar opnar haldast. Engu er eytt.';

    procedure IsEnabled(): Boolean
    var
        Mgt: Codeunit "Proj. Visit Mgt ori";
    begin
        exit(Mgt.CanRun());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Projects.Visit.Complete: ' + DescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

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

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        VisitContract: Codeunit "Proj. Visit Contract ori";
    begin
        VisitContract.AddCompleteParameters(Parameters);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Visit Contract ori";
    begin
        VisitContract.AddCompleteResponse(Response);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        VisitContract: Codeunit "Proj. Visit Contract ori";
    begin
        VisitContract.AddErrors(Errors);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Projects.Visit.SignOff', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.FollowUp.Request', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.MyTimeSheet.Submit', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.Usage.Submit', KeywordsLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Projects.Visit.Complete', '{"type":"Projects.Visit.Complete","data":{"visitId":2,"mileageKm":42,"outcome":"Done"}}', '{"status":"Success","visit":{"visitId":2,"status":"Completed"},"usageEntryNo":10,"summary":"Visit 2 completed. Mileage 42.","nextSteps":["Projects.Visit.SignOff","Projects.FollowUp.Request","Projects.MyTimeSheet.Submit","Projects.Usage.Submit"]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Mgt: Codeunit "Proj. Visit Mgt ori";
    begin
        Mgt.ExecuteComplete(Argument);
    end;
}
