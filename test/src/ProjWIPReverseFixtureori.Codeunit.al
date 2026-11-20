namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Ledger;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>Creates raw owned usage and invoiced-sales records for native WIP reversal verification.</summary>
codeunit 97115 "Proj. WIP Reverse Fixture ori" implements "Msg Interface ori"
{
    /// <summary>Restricts this test-only seeder to CRONUS test companies.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(CompanyName().ToUpper().StartsWith('CRONUS'));
    end;

    /// <summary>No filter envelope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Identifies the non-shipping fixture.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Test extension only: seed owned WIP reversal data.');
    end;

    /// <summary>Seeding writes test data.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Returns the exact request and unique marker needed for verification and cleanup.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        if not IsEnabled() then
            Error('This fixture requires a CRONUS verification company.');
        Argument.AssertVersion1();
        Response.Add('request', Seed(false));
        Response.Add('status', 'Success');
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Seeds a project, task, method, accounts, usage and a raw posted invoice; the WIP engine itself is never mocked.</summary>
    procedure Seed(ExpectDimensionPrompt: Boolean) Request: JsonObject
    var
        Ledger: Record "Job Ledger Entry";
        Invoice: Record "Sales Invoice Header";
        Line: Record "Sales Invoice Line";
        Library: Codeunit "Projects Test Library ori";
        ProjectNo: Code[20];
        EntryNo: Integer;
    begin
        Request := Library.NewEconomicWIPRequest(ExpectDimensionPrompt);
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        Invoice."No." := ProjectNo;
        Invoice."Sell-to Customer No." := ProjectNo;
        Invoice."Bill-to Customer No." := ProjectNo;
        Invoice."Posting Date" := 20261016D;
        Invoice.Insert(false);
        Line."Document No." := ProjectNo;
        Line."Line No." := 10000;
        Line."Job No." := ProjectNo;
        Line."Job Task No." := 'X100';
        Line.Type := Line.Type::"G/L Account";
        Line."No." := ProjectNo;
        Line.Quantity := 1;
        Line.Amount := 10;
        Line.Insert(false);
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Job No." := ProjectNo;
        Ledger."Job Task No." := 'X100';
        Ledger."Entry Type" := Ledger."Entry Type"::Sale;
        Ledger.Type := Ledger.Type::"G/L Account";
        Ledger."No." := ProjectNo;
        Ledger."Document No." := ProjectNo;
        Ledger."Posting Date" := 20261016D;
        Ledger.Quantity := -1;
        Ledger."Line Amount (LCY)" := -10;
        Ledger."Total Price (LCY)" := -10;
        Ledger.Insert(true);
    end;
}
