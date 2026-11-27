namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Rejects submitted lines on one time sheet.
/// </summary>
codeunit 70013573 "TS Sheet Reject Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>IsEnabled for the time sheet decision contract.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.TimeSheet.Reject") then
            exit(false);
        exit(NativeMgt.CanMaintainSheets(true));
    end;

    /// <summary>GetFilterTableNo for the time sheet decision contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>GetDescription for the time sheet decision contract.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Rejects submitted time sheet lines.', Comment = 'is-IS=Hafnar innsendum tímaskýrslulínum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>GetKeywords for the time sheet decision contract.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, reject, timesheets', Comment = 'is-IS=tímaskýrsla, hafna, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>GetSelectionDescription for the time sheet decision contract.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheet.Reject: Rejects submitted time sheet lines.', Comment = 'is-IS=Projects.TimeSheet.Reject: Hafnar innsendum tímaskýrslulínum.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>GetEnvelope for the time sheet decision contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEnvelope(GetMessageType(), Envelope));
    end;

    /// <summary>GetTarget for the time sheet decision contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetTarget(GetMessageType(), Target));
    end;

    /// <summary>GetParameters for the time sheet decision contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.AddRejectParameters(Parameters));
    end;

    /// <summary>GetResponse for the time sheet decision contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetResponse(GetMessageType(), Response));
    end;

    /// <summary>GetErrors for the time sheet decision contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetErrors(GetMessageType(), Errors));
    end;

    /// <summary>GetEffect for the time sheet decision contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEffect(GetMessageType(), Effect));
    end;

    /// <summary>GetMetering for the time sheet decision contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>GetRelated for the time sheet decision contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetRelated(GetMessageType(), Related));
    end;

    /// <summary>GetWorkflow for the time sheet decision contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetWorkflow(GetMessageType(), Workflow));
    end;

    /// <summary>GetExamples for the time sheet decision contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetExamples(GetMessageType(), Examples));
    end;

    /// <summary>GetOverview for the time sheet decision contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetOverview(GetMessageType(), Overview));
    end;

    /// <summary>GetNotes for the time sheet decision contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetNotes(GetMessageType(), Notes));
    end;

    local procedure GetMessageType(): Enum "Message Type ori"
    begin
        exit(Enum::"Message Type ori"::"Projects.TimeSheet.Reject");
    end;

    /// <summary>GetMessageDirection for the time sheet decision contract.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>ExecuteBifrostTask for the time sheet decision contract.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.TimeSheet.Reject") then
            exit;
        Argument.AssertVersion1();
        NativeMgt.ExecuteReject(Argument);
    end;
}
