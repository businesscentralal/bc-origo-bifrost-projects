namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Projects.Visit.Stop adds the rounded hours of a running visit to the caller''s time sheet.</summary>
codeunit 70013437 "Proj. Visit Stop Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Stops the caller''s running visit and adds the rounded hours to that day.', Comment = 'is-IS=Stöðvar heimsókn kallanda sem er í gangi og bætir námunduðum stundum við þann dag.';
        KeywordsLbl: Label 'visit, stop, hours, time sheet, field', Comment = 'is-IS=heimsókn, stöðva, stundir, tímaskýrsla, vettvangur';
        OverviewLbl: Label 'Adds rounded hours to the open job line for the task. Travel uses the travel work type from Projects Setup. Work uses the task line without that work type. A missing line is created when the caller is planned on the task. Submitted and approved lines are left unchanged.', Comment = 'is-IS=Bætir námunduðum vinnustundum við opna verkefnalínu fyrir verkþáttinn. Ferð notar vinnugerð fyrir ferð úr uppsetningu verkefna. Vinna notar verkþáttarlínuna án þeirrar vinnugerðar. Lína sem vantar er stofnuð ef aðfang þess sem kallar er áætlað á verkþáttinn. Innsendum og samþykktum línum er ekki breytt.';
        NotesLbl: Label 'Zero hours after rounding keeps the visit and does not create a day. The same clientRequestId returns the first result. Nothing is deleted or submitted.', Comment = 'is-IS=Ef vinnustundir eru núll eftir námundun er heimsókninni haldið en enginn dagur stofnaður. Sama clientRequestId skilar fyrstu niðurstöðunni. Engu er eytt eða skilað inn.';

    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "Proj. Visit Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.Visit.Stop") then
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
        exit('Projects.Visit.Stop: ' + DescriptionLbl);
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
        VisitContract.AddStopParameters(Parameters);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        VisitContract: Codeunit "Proj. Visit Contract ori";
    begin
        VisitContract.AddStopResponse(Response);
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
        Related.Add(Contract.RelatedEntry('Projects.Visit.Start', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.Visit.Complete', KeywordsLbl));
        Related.Add(Contract.RelatedEntry('Projects.MyTimeSheet.Submit', KeywordsLbl));
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
        Examples.Add(Contract.Example('Projects.Visit.Stop', '{"type":"Projects.Visit.Stop","data":{"at":"2026-11-21T11:00:00"}}', '{"status":"Success","visitId":2,"hours":2.5,"timeSheetNo":"TS0001","timeSheetLineNo":20000,"day":"2026-11-21","summary":"2.5 hours written on 2026-11-21.","nextSteps":["Projects.Visit.Complete","Projects.MyTimeSheet.Submit"]}'));
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
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.Visit.Stop") then
            exit;
        Mgt.ExecuteStop(Argument);
    end;
}
