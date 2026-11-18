namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Test extension only (projects#38): removes the X38M self-service fixture and reports what remains.</summary>
codeunit 97162 "TS Self Service Cleanup ori" implements "Msg Interface ori"
{
    /// <summary>Same gate as the seed.</summary>
    procedure IsEnabled(): Boolean
    var
        Fixture: Codeunit "TS Self Service Fixture ori";
    begin
        exit(Fixture.IsEnabled());
    end;

    /// <summary>No generic filter envelope is used.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Identifies this test-extension-only fixture operation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Test extension only: removes the X38M self-service fixture in a CRONUS verification company.');
    end;

    /// <summary>Declares that fixture cleanup writes test data.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Removes the fixture and counts the remaining X38M rows.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Fixture: Codeunit "TS Self Service Fixture ori";
        Response: JsonObject;
    begin
        Argument.AssertVersion1();
        if not IsEnabled() then
            Error('This test fixture requires a CRONUS verification company and native write permissions.');
        Fixture.Cleanup();
        Resource.SetFilter("No.", 'X38M-OWN|X38M-EMP');
        Header.SetFilter("Resource No.", 'X38M-OWN|X38M-EMP');
        Response.Add('status', 'Success');
        Response.Add('resourcesRemaining', Resource.Count());
        Response.Add('headersRemaining', Header.Count());
        Argument.SetResponseJson(Response);
    end;
}
