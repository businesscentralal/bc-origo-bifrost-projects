namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.WIP;
using Origo.Bifrost;

/// <summary>Implements the version 1 Projects.WIPMethod.Get contract.</summary>
codeunit 70009240 "Proj. WIP Method Get ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    /// <summary>Checks company enablement and native table write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::"Job WIP Method", false));
    end;
    /// <summary>Returns the native target table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Job WIP Method");
    end;
    /// <summary>Describes this operation in the session language.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Lists project WIP methods and their recognized cost and sales settings.', Comment = 'is-IS=Sýnir VÍV-aðferðir verkefna og stillingar fyrir færðan kostnað og sölu.';
    begin
        exit(DescriptionLbl);
    end;
    /// <summary>Provides localized discovery terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'project, job, WIP, method, recognized costs, recognized sales, get', Comment = 'is-IS=verkefni, verk, VÍV, aðferð, færður kostnaður, færð sala, lesa';
    begin
        exit(KeywordsLbl);
    end;
    /// <summary>Distinguishes this operation during discovery.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;
    /// <summary>Declares the inbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;
    /// <summary>Declares the data-only version 1 envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;
    /// <summary>Declares the target keys.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.code', 'WIP method code', 'Exact native WIP method code; omitted on Get lists all methods.'));
        exit(true);
    end;
    /// <summary>Declares the request parameters and nested schemas.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Methods: Codeunit "Projects WIP Methods ori";
    begin
        Parameters := Methods.Parameters(false);
        exit(true);
    end;
    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        Field: JsonObject;
    begin
        Field.Add('name', 'status');
        Field.Add('type', 'string');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'methods');
        Field.Add('type', 'array');
        Field.Add('description', 'Methods with code, description, recognizedCosts, recognizedSales, wipCost, wipSales, valid and systemDefined. Enum values are stable English names at every language.');
        Fields.Add(Field);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;
    /// <summary>Declares contract and native validation failures.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Methods: Codeunit "Projects WIP Methods ori";
    begin
        Errors := Methods.Errors();
        exit(true);
    end;
    /// <summary>Documents transactional native writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'None.');
        Effect.Add('idempotent', true);
        exit(true);
    end;
    /// <summary>No additional app-specific meter is declared.</summary>
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
    /// <summary>Provides a minimal request example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('code', 'CUSTOM');

        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;
    /// <summary>Provides localized operation help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Lists project WIP methods and their recognized cost and sales settings.';
        exit(true);
    end;
    /// <summary>Documents nested write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Version 1.0. Subject is not used. Send a JSON object. Get without code lists all methods. Set requires code, creates a missing custom method and preserves omitted fields on update. Recognized cost and sales values use exact English enum names in every language. System-defined methods and methods referenced by calculated or posted WIP entries cannot be changed. Use a new custom code instead. Native validation failures roll back the entire change. No posting or deletion occurs.';
        exit(true);
    end;
    /// <summary>Checks company, permissions, licence and version before processing WIP methods.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Methods: Codeunit "Projects WIP Methods ori";
    begin
        if not Methods.AssertEnabled(Argument, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Methods.Execute(Argument);
    end;
}
