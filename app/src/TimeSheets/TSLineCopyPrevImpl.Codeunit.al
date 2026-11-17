namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Copies lines from the resource's previous time sheet.
/// </summary>
codeunit 70013563 "TS Line CopyPrev Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Implements IsEnabled for the time-sheet line message.</summary>
    procedure IsEnabled(): Boolean
    var
        NativeMgt: Codeunit "TS Fill Mgt ori";
    begin
        exit(NativeMgt.CanFillLines(false));
    end;

    /// <summary>Implements GetFilterTableNo for the time-sheet line message.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Implements GetDescription for the time-sheet line message.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Copies lines from the previous time sheet.', Comment = 'is-IS=Afritar línur úr fyrri tímaskýrslu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements GetKeywords for the time-sheet line message.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, copy, previous, timesheets', Comment = 'is-IS=tímaskýrsla, afrita, fyrri, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements GetSelectionDescription for the time-sheet line message.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheetLine.CopyFromPrevious: Copies lines from the previous time sheet.', Comment = 'is-IS=Projects.TimeSheetLine.CopyFromPrevious: Afritar línur úr fyrri tímaskýrslu.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Implements GetEnvelope for the time-sheet line message.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetEnvelope(GetMessageType(), Envelope));
    end;

    /// <summary>Implements GetTarget for the time-sheet line message.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetTarget(GetMessageType(), Target));
    end;

    /// <summary>Implements GetParameters for the time-sheet line message.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.AddCopyParameters(Parameters));
    end;

    /// <summary>Implements GetResponse for the time-sheet line message.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetResponse(GetMessageType(), Response));
    end;

    /// <summary>Implements GetErrors for the time-sheet line message.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetErrors(GetMessageType(), Errors));
    end;

    /// <summary>Implements GetEffect for the time-sheet line message.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetEffect(GetMessageType(), Effect));
    end;

    /// <summary>Implements GetMetering for the time-sheet line message.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements GetRelated for the time-sheet line message.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetRelated(GetMessageType(), Related));
    end;

    /// <summary>Implements GetWorkflow for the time-sheet line message.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetWorkflow(GetMessageType(), Workflow));
    end;

    /// <summary>Implements GetExamples for the time-sheet line message.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetExamples(GetMessageType(), Examples));
    end;

    /// <summary>Implements GetOverview for the time-sheet line message.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetOverview(GetMessageType(), Overview));
    end;

    /// <summary>Implements GetNotes for the time-sheet line message.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Fill Contract ori";
    begin
        exit(Parts.GetNotes(GetMessageType(), Notes));
    end;

    local procedure GetMessageType(): Enum "Message Type ori"
    begin
        exit(Enum::"Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious");
    end;

    /// <summary>Implements GetMessageDirection for the time-sheet line message.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements ExecuteBifrostTask for the time-sheet line message.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        NativeMgt: Codeunit "TS Fill Mgt ori";
    begin
        Argument.AssertVersion1();
        NativeMgt.ExecuteCopy(Argument);
    end;
}
