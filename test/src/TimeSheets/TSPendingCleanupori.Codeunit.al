namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Runs explicit cleanup of owned issue 62 live-verification records in the test extension only.</summary>
codeunit 97119 "TS Pending Cleanup ori" implements "Msg Interface ori"
{
    trigger OnRun()
    var
        Fixture: Codeunit "TS Pending Fixture ori";
    begin
        Fixture.Cleanup();
    end;

    /// <summary>Uses the same CRONUS-only native permission check as fixture creation.</summary>
    procedure IsEnabled(): Boolean
    var
        Fixture: Codeunit "TS Pending Fixture ori";
    begin
        exit(Fixture.IsEnabled());
    end;

    /// <summary>No generic filter envelope is used.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Identifies the test-extension-only cleanup operation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Test extension only: removes the fixed issue 62 fixture in a CRONUS verification company.');
    end;

    /// <summary>Declares fixture removal as a write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Removes the fixed fixture and returns verifiable remaining counts.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Fixture: Codeunit "TS Pending Fixture ori";
        Response: JsonObject;
    begin
        Argument.AssertVersion1();
        if not IsEnabled() then
            Error('This test fixture requires a CRONUS verification company and native write permissions.');
        Fixture.Cleanup();
        Resource.SetFilter("No.", 'TS62-REGINN|TS62-OTHER');
        Header.SetFilter("No.", 'TS62-A|TS62-B');
        Line.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Detail.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Response.Add('status', 'Success');
        Response.Add('resourcesRemaining', Resource.Count());
        Response.Add('headersRemaining', Header.Count());
        Response.Add('linesRemaining', Line.Count());
        Response.Add('detailsRemaining', Detail.Count());
        Argument.SetResponseJson(Response);
    end;
}
