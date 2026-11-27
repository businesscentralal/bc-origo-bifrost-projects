namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Submits open lines on one time sheet.
/// </summary>
codeunit 70013575 "TS Sheet Submit Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Handles IsEnabled for the Submit message contract.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.TimeSheet.Submit") then
            exit(false);
        exit(NativeMgt.CanMaintainSheets());
    end;

    /// <summary>Returns GetFilterTableNo for the Submit message contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns GetDescription for the Submit message contract.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Submits open time sheet lines for approval.', Comment = 'is-IS=Sendir inn opnar tímaskýrslulínur til samþykktar.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns GetKeywords for the Submit message contract.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, submit, timesheets', Comment = 'is-IS=tímaskýrsla, senda inn, tímaskýrslur, sendir inn';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns GetSelectionDescription for the Submit message contract.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheet.Submit: Submits open time sheet lines for approval.', Comment = 'is-IS=Projects.TimeSheet.Submit: Sendir opnar tímaskýrslulínur til samþykktar.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Returns GetEnvelope for the Submit message contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEnvelope(GetMessageType(), Envelope));
    end;

    /// <summary>Returns GetTarget for the Submit message contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetTarget(GetMessageType(), Target));
    end;

    /// <summary>Returns GetParameters for the Submit message contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.AddSubmitParameters(Parameters));
    end;

    /// <summary>Returns GetResponse for the Submit message contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetResponse(GetMessageType(), Response));
    end;

    /// <summary>Returns GetErrors for the Submit message contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetErrors(GetMessageType(), Errors));
    end;

    /// <summary>Returns GetEffect for the Submit message contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEffect(GetMessageType(), Effect));
    end;

    /// <summary>Returns GetMetering for the Submit message contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns GetRelated for the Submit message contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetRelated(GetMessageType(), Related));
    end;

    /// <summary>Returns GetWorkflow for the Submit message contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetWorkflow(GetMessageType(), Workflow));
    end;

    /// <summary>Returns GetExamples for the Submit message contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetExamples(GetMessageType(), Examples));
    end;

    /// <summary>Returns GetOverview for the Submit message contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetOverview(GetMessageType(), Overview));
    end;

    /// <summary>Returns GetNotes for the Submit message contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetNotes(GetMessageType(), Notes));
    end;

    local procedure GetMessageType(): Enum "Message Type ori"
    begin
        exit(Enum::"Message Type ori"::"Projects.TimeSheet.Submit");
    end;

    /// <summary>Returns GetMessageDirection for the Submit message contract.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Handles ExecuteBifrostTask for the Submit message contract.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.TimeSheet.Submit") then
            exit;
        Argument.AssertVersion1();
        NativeMgt.ExecuteSubmit(Argument);
    end;
}
