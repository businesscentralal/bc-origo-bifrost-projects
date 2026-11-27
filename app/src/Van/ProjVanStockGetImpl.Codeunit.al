namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.VanStock.Get adds the rounded hours of a running visit to the caller''s time sheet.</summary>
codeunit 70013473 "Proj. VanStock Get Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Shows what is in your van after usage that is not posted yet.', Comment = 'is-IS=Sýnir vörur og birgðir í bílnum þínum eftir notkun sem er ekki bókuð enn.';
        KeywordsLbl: Label 'van, stock, inventory, available, minimum, parts', Comment = 'is-IS=bíll, birgðir, tiltækt, lágmark, vörur, hlutir';
        OverviewLbl: Label 'Reads the stock at your van location and subtracts open, submitted, approved and transferred usage lines that are not posted yet. Items below their reorder point are flagged belowMinimum.', Comment = 'is-IS=Les birgðir í birgðageymslu bílsins þíns og dregur frá opnar, innsendar, samþykktar og fluttar notkunarlínur sem hafa ekki enn verið bókaðar. Vörur undir endurpöntunarmarki eru merktar belowMinimum.';
        NotesLbl: Label 'Read only. To restock the van the back office uses the Inventory transfer order message types. The list is cut at 200 items.', Comment = 'is-IS=Aðeins lestur. Skrifstofan notar skilaboðategundir birgða fyrir flutningspantanir til að fylla á bílinn. Listinn takmarkast við 200 vörur.';

    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "Proj. Van Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.VanStock.Get") then
            exit(false);
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
        exit('Projects.VanStock.Get: ' + DescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
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
        VisitContract.AddStockParameters(Parameters);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Van Contract ori";
    begin
        VisitContract.AddStockResponse(Response);
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
        Effect.Add('effect', 'read');
        Effect.Add('idempotent', true);
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
        Related.Add(Contract.RelatedEntry('Projects.VisitItem.Register', KeywordsLbl));
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
        Examples.Add(Contract.Example('Projects.VanStock.Get', '{"type":"Projects.VanStock.Get","data":{"belowMinimumOnly":true}}', '{"status":"Success","location":"VAN1","items":[{"itemNo":"FILTER-1","description":"Filter","inventory":5,"pendingUsage":2,"available":3,"binCode":"","belowMinimum":true}],"summary":"1 items at VAN1."}'));
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
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "Proj. Van Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.VanStock.Get") then
            exit;
        Mgt.ExecuteStock(Argument);
    end;
}
