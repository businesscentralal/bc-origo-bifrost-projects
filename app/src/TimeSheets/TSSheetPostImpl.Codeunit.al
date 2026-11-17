namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>
/// Posts approved time sheet lines through the job journal.
/// </summary>
codeunit 70013572 "TS Sheet Post Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Implements the message interface chapter IsEnabled.</summary>
    procedure IsEnabled(): Boolean
    var
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        exit(NativeMgt.CanPostSheets());
    end;

    /// <summary>Implements the message interface chapter GetFilterTableNo.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Implements the message interface chapter GetDescription.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts approved time sheet lines.', Comment = 'is-IS=Bókar samþykktar tímaskýrslulínur.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements the message interface chapter GetKeywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, post, timesheets', Comment = 'is-IS=tímaskýrsla, bóka, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements the message interface chapter GetSelectionDescription.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheet.Post: Posts approved time sheet lines.', Comment = 'is-IS=Projects.TimeSheet.Post: Bókar samþykktar tímaskýrslulínur.';
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
        exit(Parts.AddPostParameters(Parameters));
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
        exit(Enum::"Message Type ori"::"Projects.TimeSheet.Post");
    end;

    /// <summary>Implements the message interface chapter GetMessageDirection.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements the message interface chapter ExecuteBifrostTask.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        NativeMgt: Codeunit "TS Native Mgt ori";
    begin
        Argument.AssertVersion1();
        NativeMgt.ExecutePost(Argument);
    end;
}
