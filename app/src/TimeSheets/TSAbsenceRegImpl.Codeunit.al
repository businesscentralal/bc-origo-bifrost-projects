namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Registers an absence line and its daily hours.
/// </summary>
codeunit 70013554 "TS Absence Reg Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Checks the caller permissions required for absence registration.</summary>
    procedure IsEnabled(): Boolean
    var
        NativeMgt: Codeunit "TS Absence Mgt ori";
    begin
        exit(NativeMgt.CanMaintainSheets());
    end;

    /// <summary>Returns zero because this message addresses a time sheet through request parameters.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the localized description of absence registration.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Registers an absence line on a time sheet.', Comment = 'is-IS=Skráir fjarvistarlínu á tímaskýrslu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized absence discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'absence, time sheet, timesheets', Comment = 'is-IS=fjarvist, tímaskýrsla, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized message picker description.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.Absence.Register: Registers an absence line on a time sheet.', Comment = 'is-IS=Projects.Absence.Register: Skráir fjarvistarlínu á tímaskýrslu.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the supported task envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetEnvelope(GetMessageType(), Envelope));
    end;

    /// <summary>Describes the time-sheet identifier.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetTarget(GetMessageType(), Target));
    end;

    /// <summary>Lists the accepted absence registration parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.AddAbsenceParameters(Parameters));
    end;

    /// <summary>Describes the absence line returned on success.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetResponse(GetMessageType(), Response));
    end;

    /// <summary>Lists documented refusals and recovery steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetErrors(GetMessageType(), Errors));
    end;

    /// <summary>Describes the committed write and required permissions.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetEffect(GetMessageType(), Effect));
    end;

    /// <summary>Indicates that the type has no additional metering chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related discovery messages.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetRelated(GetMessageType(), Related));
    end;

    /// <summary>Describes the absence registration workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetWorkflow(GetMessageType(), Workflow));
    end;

    /// <summary>Provides an absence registration request and response example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetExamples(GetMessageType(), Examples));
    end;

    /// <summary>Returns the localized purpose of the message.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetOverview(GetMessageType(), Overview));
    end;

    /// <summary>Explains employee linking, weekend warnings and commit behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Absence Contract ori";
    begin
        exit(Parts.GetNotes(GetMessageType(), Notes));
    end;

    local procedure GetMessageType(): Enum "Message Type ori"
    begin
        exit(Enum::"Message Type ori"::"Projects.Absence.Register");
    end;

    /// <summary>Declares the message as an inbound write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the message version and dispatches isolated absence registration.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        NativeMgt: Codeunit "TS Absence Mgt ori";
    begin
        Argument.AssertVersion1();
        NativeMgt.ExecuteAbsence(Argument);
    end;
}
