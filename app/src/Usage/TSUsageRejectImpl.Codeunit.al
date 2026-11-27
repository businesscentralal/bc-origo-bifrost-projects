namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Implements the version 1 Projects.Usage.Reject contract.</summary>
codeunit 70013413 "TS Usage Reject Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the permissions this message type needs.</summary>
    procedure IsEnabled(): Boolean
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "TS Usage Mgt ori";
    begin
        if not ProjectsDomainGate.IsTypeEnabled("Message Type ori"::"Projects.Usage.Reject") then
            exit(false);
        exit(Mgt.CanUse(4));
    end;

    /// <summary>Usage lines have no native filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Rejects submitted usage lines of a time sheet with an optional comment.', Comment = 'is-IS=Hafnar innsendum notkunarlínum tímaskýrslu með valfrjálsri athugasemd.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, usage, reject', Comment = 'is-IS=tímaskýrsla, notkun, hafna';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.Usage.Reject: Rejects submitted usage lines of a time sheet with an optional comment.', Comment = 'is-IS=Projects.Usage.Reject: Hafnar innsendum notkunarlínum tímaskýrslu með valfrjálsri athugasemd.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Declares the message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Declares the data-only version 1 envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "TS Usage Contract ori";
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
        Contract: Codeunit "TS Usage Contract ori";
    begin
        exit(Contract.GetParameters(4, Parameters));
    end;

    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "TS Usage Contract ori";
    begin
        exit(Contract.GetResponse(Response));
    end;

    /// <summary>Declares the Bifrost error codes.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Projects Contract ori";
    begin
        Errors := Contract.Errors();
        exit(true);
    end;

    /// <summary>Documents the effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "TS Usage Contract ori";
    begin
        exit(Contract.GetEffect(4, Effect));
    end;

    /// <summary>No additional meter is declared.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional related types are declared.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>No additional workflow chapter is declared.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No example is declared.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Documents the rules of this operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Only the approver named on the time sheet can reject, never the owner of the sheet. Only Submitted lines can be rejected. The comment is limited to 250 characters.', Comment = 'is-IS=Aðeins samþykktaraðilinn sem er nefndur á tímaskýrslunni getur hafnað, aldrei eigandi skýrslunnar. Aðeins innsendum línum er hægt að hafna. Athugasemd er mest 250 stafir.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Runs the operation after the license and version checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProjectsDomainGate: Codeunit "Projects Domain Gate ori";
        Mgt: Codeunit "TS Usage Mgt ori";
    begin
        if not ProjectsDomainGate.AssertTypeEnabled(Argument, "Message Type ori"::"Projects.Usage.Reject") then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Mgt.Execute(Argument, 4);
    end;
}
