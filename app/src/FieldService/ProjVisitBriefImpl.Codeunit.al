namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Implements the version 1 Projects.VisitBrief.Get contract.</summary>
codeunit 70013428 "Proj. Visit Brief Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the permissions this message type needs.</summary>
    procedure IsEnabled(): Boolean
    var
        Mgt: Codeunit "Proj. Field Service Mgt ori";
    begin
        exit(Mgt.CanRead());
    end;

    /// <summary>Usage lines have no native filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads the caller''s project visit brief.', Comment = 'is-IS=Les yfirlit verkefnaheimsóknar kallanda.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'technician, project, visit, brief', Comment = 'is-IS=tæknimaður, verkefni, heimsókn, yfirlit';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.VisitBrief.Get: Reads the caller''s project visit brief.', Comment = 'is-IS=Projects.VisitBrief.Get: Les yfirlit verkefnaheimsóknar kallanda.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Declares the message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Declares the data-only version 1 envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetEnvelope(Envelope));
    end;

    /// <summary>No target keys are declared; the request data carries the keys.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares the request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetParameters(true, Parameters));
    end;

    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetResponse(true, Response));
    end;

    /// <summary>Declares the Bifrost error codes.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetErrors(Errors));
    end;

    /// <summary>Documents the effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('idempotent', true);
        exit(true);
    end;

    /// <summary>No additional meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional related types are declared.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetRelated(true, Related));
    end;

    /// <summary>No additional workflow chapter is declared.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No example is declared.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Proj. Field Contract ori";
    begin
        exit(Contract.GetExamples(true, Examples));
    end;

    /// <summary>Provides localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Read-only technician self-service. Requires BIFROST Read ori and PROJ FIELD TECH. The authenticated user owns the selected resource. No dispatcher access or writes.';
        exit(true);
    end;

    /// <summary>Documents the rules of this operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Dates are ISO 8601; date defaults to today. Visits sort by planning date, task and line number, with project number breaking ties. Hours use native resource units; use hours as the resource unit of measure. include is an array containing items and/or address; the default includes address. Remaining planned quantities include resources and items. Missing sheets or task lines return ready-made nextSteps without writing. Brief time totals cover all own sheets; day totals cover the requested date. history and followUps are empty until visit and follow-up features ship. Files are not read; use recordIds with other apps.';
        exit(true);
    end;

    /// <summary>Runs the operation after the license and version checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Mgt: Codeunit "Proj. Field Service Mgt ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Mgt.Execute(Argument, true);
    end;
}
