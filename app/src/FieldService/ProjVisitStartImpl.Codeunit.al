namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.Visit.Start records that the caller is travelling or working on a task.</summary>
codeunit 70013436 "Proj. Visit Start Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Starts a travel or work visit on the caller''s own time sheet.', Comment = 'is-IS=Byrjar ferð eða vinnu á eigin tímaskýrslu kallanda.';
        KeywordsLbl: Label 'visit, start, travel, work, time sheet, field', Comment = 'is-IS=heimsókn, byrja, ferð, vinna, tímaskýrsla, vettvangur';
        OverviewLbl: Label 'Writes one running visit for the caller. Travel and work are separate visits. A second start while one is running is refused unless autoStop is true, which stops the running visit and adds its rounded hours first. Hours stay on an open time sheet line.', Comment = 'is-IS=Skráir eina heimsókn í gangi fyrir þann sem kallar. Ferð og vinna eru aðskildar heimsóknir. Önnur byrjun meðan heimsókn er í gangi er ekki leyfð nema autoStop sé true; þá er heimsókninni í gangi fyrst lokið og námunduðum vinnustundum hennar bætt við. Vinnustundirnar haldast á opinni tímaskýrslulínu.';
        NotesLbl: Label 'A missing week is not created. Rounding uses Projects Setup. The same clientRequestId returns the first result. Nothing is deleted.', Comment = 'is-IS=Vika sem vantar er ekki stofnuð. Námundun fylgir uppsetningu verkefna. Sama clientRequestId skilar fyrstu niðurstöðunni. Engu er eytt.';

    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "Proj. Visit Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.Visit.Start") then
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
        exit('Projects.Visit.Start: ' + DescriptionLbl);
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
        VisitContract.AddStartParameters(Parameters);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Visit Contract ori";
    begin
        VisitContract.AddStartResponse(Response);
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
        Related.Add(Contract.RelatedEntry('Projects.Visit.Stop', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.Visit.Complete', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.MyTimeSheet.Create', KeywordsLbl));
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
        Examples.Add(Contract.Example('Projects.Visit.Start', '{"type":"Projects.Visit.Start","data":{"projectNo":"P00010","taskNo":"1000","kind":"travel","at":"2026-11-21T08:00:00"}}', '{"status":"Success","visitId":1,"startedAt":"2026-11-21T08:00:00","summary":"Travel started on project P00010, task 1000."}'));
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
        Mgt: Codeunit "Proj. Visit Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.Visit.Start") then
            exit;
        Mgt.ExecuteStart(Argument);
    end;
}
