namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Adds or changes time sheet lines and their hours per day (Projects.TimeSheetLine.Set, projects#50).
/// </summary>
codeunit 70013599 "TS Line Set Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Implements IsEnabled for the time-sheet line set message.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        LineSetMgt: Codeunit "TS Line Set Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.TimeSheetLine.Set") then
            exit(false);
        exit(LineSetMgt.CanMaintainSheets());
    end;

    /// <summary>Implements GetFilterTableNo for the time-sheet line set message.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Implements GetDescription for the time-sheet line set message.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Adds or changes time sheet lines and hours per day.', Comment = 'is-IS=Bætir við eða breytir línum tímaskýrslu og klukkustundum eftir dögum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements GetKeywords for the time-sheet line set message.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, lines, hours, timesheets', Comment = 'is-IS=tímaskýrsla, línur, klukkustundir, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements GetSelectionDescription for the time-sheet line set message.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheetLine.Set: Adds or changes time sheet lines and hours per day.', Comment = 'is-IS=Projects.TimeSheetLine.Set: Bætir við eða breytir línum tímaskýrslu og klukkustundum eftir dögum.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Implements GetEnvelope for the time-sheet line set message.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetEnvelope(Envelope));
    end;

    /// <summary>Implements GetTarget for the time-sheet line set message.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetTarget(Target));
    end;

    /// <summary>Implements GetParameters for the time-sheet line set message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.AddParameters(Parameters));
    end;

    /// <summary>Implements GetResponse for the time-sheet line set message.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetResponse(Response));
    end;

    /// <summary>Implements GetErrors for the time-sheet line set message.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetErrors(Errors));
    end;

    /// <summary>Implements GetEffect for the time-sheet line set message.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetEffect(Effect));
    end;

    /// <summary>Implements GetMetering for the time-sheet line set message.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements GetRelated for the time-sheet line set message.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetRelated(Related));
    end;

    /// <summary>Implements GetWorkflow for the time-sheet line set message.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetWorkflow(Workflow));
    end;

    /// <summary>Implements GetExamples for the time-sheet line set message.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetExamples(Examples));
    end;

    /// <summary>Implements GetOverview for the time-sheet line set message.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetOverview(Overview));
    end;

    /// <summary>Implements GetNotes for the time-sheet line set message.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Line Set Contract ori";
    begin
        exit(Parts.GetNotes(Notes));
    end;

    /// <summary>Implements GetMessageDirection for the time-sheet line set message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements ExecuteBifrostTask for the time-sheet line set message.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        LineSetMgt: Codeunit "TS Line Set Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.TimeSheetLine.Set") then
            exit;
        Argument.AssertVersion1();
        LineSetMgt.Execute(Argument);
    end;
}
