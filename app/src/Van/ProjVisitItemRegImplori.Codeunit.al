namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.VisitItem.Register adds the rounded hours of a running visit to the caller''s time sheet.</summary>
codeunit 70013472 "Proj. VisitItem Reg Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Registers parts used from the van on a task as open usage lines.', Comment = 'is-IS=Skráir vörur sem notaðar eru úr bílnum á verkþátt sem opnar notkunarlínur.';
        KeywordsLbl: Label 'van, parts, items, used, filter, cable, usage, field', Comment = 'is-IS=bíll, hlutir, vörur, notað, sía, kapall, notkun, vettvangur';
        OverviewLbl: Label 'Finds your time sheet line for the task, creating it when it is missing, resolves each part by item number, reference or description, and writes open usage lines at your van location. When any input matches more than one item nothing is written and ambiguous lists the candidates. A shortage at the van is a warning: the line is written and listed in shortages.', Comment = 'is-IS=Finds your time sheet line for the task, creating it when it is missing, resolves each part by item number, reference or description, and writes open usage lines at your van location. When any input matches more than one item nothing is written and ambiguous lists the candidates. A shortage at the van is a warning: the line is written and listed in shortages.';
        NotesLbl: Label 'The same clientRequestId returns the first result. Lot and serial numbers are required for tracked items; a serial number needs quantity 1. A wrong entry is rejected by the approver, then you register it again. Nothing is deleted or submitted. Ask the back office to restock the van with a transfer order.', Comment = 'is-IS=The same clientRequestId returns the first result. Lot and serial numbers are required for tracked items; a serial number needs quantity 1. A wrong entry is rejected by the approver, then you register it again. Nothing is deleted or submitted. Ask the back office to restock the van with a transfer order.';

    procedure IsEnabled(): Boolean
    var
        Mgt: Codeunit "Proj. Van Mgt ori";
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
        exit('Projects.VisitItem.Register: ' + DescriptionLbl);
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
        VisitContract: Codeunit "Proj. Van Contract ori";
    begin
        VisitContract.AddRegisterParameters(Parameters);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Van Contract ori";
    begin
        VisitContract.AddRegisterResponse(Response);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        VisitContract: Codeunit "Proj. Van Contract ori";
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
        Related.Add(Contract.RelatedEntry('Projects.VanStock.Get', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.Usage.Submit', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.Visit.Stop', KeywordsLbl));
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
        Examples.Add(Contract.Example('Projects.VisitItem.Register', '{"type":"Projects.VisitItem.Register","data":{"projectNo":"PR00010","taskNo":"1000","items":[{"description":"filter","quantity":2},{"itemNo":"CABLE","quantity":40}]}}', '{"status":"Success","lines":[{"entryNo":12,"itemNo":"FILTER-1","quantity":2,"locationCode":"VAN1","status":"Open"}],"shortages":[],"summary":"2 usage lines written from van location VAN1. They stay Open until you submit them.","nextSteps":["Projects.Usage.Submit","Projects.VanStock.Get"]}'));
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
        Mgt: Codeunit "Proj. Van Mgt ori";
    begin
        Mgt.ExecuteRegister(Argument);
    end;
}
