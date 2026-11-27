namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Reopens submitted or approved lines up to a cutoff date.
/// </summary>
codeunit 70013574 "TS Sheet Reopen Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Implements the message interface chapter IsEnabled.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.TimeSheet.Reopen") then
            exit(false);
        exit(NativeMgt.CanReopenSheets());
    end;

    /// <summary>Implements the message interface chapter GetFilterTableNo.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Implements the message interface chapter GetDescription.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reopens submitted or approved time sheet lines.', Comment = 'is-IS=Opnar aftur innsendar eða samþykktar tímaskýrslulínur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements the message interface chapter GetKeywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, reopen, timesheets', Comment = 'is-IS=tímaskýrsla, opna aftur, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements the message interface chapter GetSelectionDescription.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheet.Reopen: Reopens submitted or approved time sheet lines.', Comment = 'is-IS=Projects.TimeSheet.Reopen: Opnar aftur innsendar eða samþykktar tímaskýrslulínur.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Implements the message interface chapter GetEnvelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEnvelope(GetMessageType(), Envelope));
    end;

    /// <summary>Implements the message interface chapter GetTarget.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetTarget(GetMessageType(), Target));
    end;

    /// <summary>Implements the message interface chapter GetParameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.AddReopenParameters(Parameters));
    end;

    /// <summary>Implements the message interface chapter GetResponse.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetResponse(GetMessageType(), Response));
    end;

    /// <summary>Implements the message interface chapter GetErrors.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetErrors(GetMessageType(), Errors));
    end;

    /// <summary>Implements the message interface chapter GetEffect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetEffect(GetMessageType(), Effect));
    end;

    /// <summary>Implements the message interface chapter GetMetering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements the message interface chapter GetRelated.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetRelated(GetMessageType(), Related));
    end;

    /// <summary>Implements the message interface chapter GetWorkflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetWorkflow(GetMessageType(), Workflow));
    end;

    /// <summary>Implements the message interface chapter GetExamples.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetExamples(GetMessageType(), Examples));
    end;

    /// <summary>Implements the message interface chapter GetOverview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetOverview(GetMessageType(), Overview));
    end;

    /// <summary>Implements the message interface chapter GetNotes.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Contract Parts ori";
    begin
        exit(Parts.GetNotes(GetMessageType(), Notes));
    end;

    local procedure GetMessageType(): Enum "Message Type ori"
    begin
        exit(Enum::"Message Type ori"::"Projects.TimeSheet.Reopen");
    end;

    /// <summary>Implements the message interface chapter GetMessageDirection.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements the message interface chapter ExecuteBifrostTask.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.TimeSheet.Reopen") then
            exit;
        Argument.AssertVersion1();
        NativeMgt.ExecuteReopen(Argument);
    end;
}
