namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Seeds isolated native records for issue 62 tests and owned MCP verification.</summary>
codeunit 97134 "TS Pending Fixture ori" implements "Msg Interface ori"
{
    trigger OnRun()
    begin
        Seed();
    end;

    /// <summary>Fixture messages run only in a CRONUS verification company with native write rights.</summary>
    procedure IsEnabled(): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
    begin
        exit(CompanyName().ToUpper().StartsWith('CRONUS') and Header.WritePermission() and Line.WritePermission() and Detail.WritePermission() and Resource.WritePermission());
    end;

    /// <summary>No generic filter envelope is used.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Identifies this test-extension-only fixture operation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Test extension only: creates the isolated issue 62 fixture in a CRONUS verification company.');
    end;

    /// <summary>Declares that fixture creation writes test data.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Creates the fixture once through the authenticated dispatcher; never changes consent or licensing.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        Argument.AssertVersion1();
        if not IsEnabled() then
            Error('This test fixture requires a CRONUS verification company and native write permissions.');
        Seed();
        Response.Add('status', 'Success');
        Response.Add('resources', 2);
        Response.Add('headers', 2);
        Response.Add('lines', 4);
        Response.Add('details', 8);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Creates an isolated manager, foreign-manager and mixed-status dataset, refusing collisions.</summary>
    procedure Seed()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
    begin
        if Resource.Get('TS62-REGINN') or Resource.Get('TS62-OTHER') or Header.Get('TS62-A') or Header.Get('TS62-B') then
            Error('Issue 62 fixture already exists; inspect its provenance before reuse.');
        Resource.Init();
        Resource."No." := 'TS62-REGINN';
        Resource.Name := 'Issue 62 owned verification';
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Insert(false);
        Resource.Init();
        Resource."No." := 'TS62-OTHER';
        Resource.Name := 'Issue 62 other resource';
        Resource.Insert(false);
        AddHeader('TS62-A', 'TS62-REGINN', CopyStr(UserId(), 1, 50));
        AddHeader('TS62-B', 'TS62-OTHER', 'TS62-FOREIGN');
        AddLine('TS62-A', 10000, "Time Sheet Line Type"::Job, "Time Sheet Status"::Submitted, 3);
        AddLine('TS62-A', 20000, "Time Sheet Line Type"::Resource, "Time Sheet Status"::Open, 9);
        AddLine('TS62-A', 30000, "Time Sheet Line Type"::Absence, "Time Sheet Status"::Submitted, 4);
        AddLine('TS62-B', 10000, "Time Sheet Line Type"::Resource, "Time Sheet Status"::Submitted, 7);
    end;

    local procedure AddHeader(SheetNo: Code[20]; ResourceNo: Code[20]; Approver: Code[50])
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := SheetNo;
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := 20261102D;
        Header."Ending Date" := 20261108D;
        Header."Owner User ID" := CopyStr(UserId(), 1, 50);
        Header."Approver User ID" := Approver;
        Header.Insert(false);
    end;

    local procedure AddLine(SheetNo: Code[20]; LineNo: Integer; LineType: Enum "Time Sheet Line Type"; Status: Enum "Time Sheet Status"; Hours: Decimal)
    var
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        DayOffset: Integer;
    begin
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := LineNo;
        Line."Time Sheet Starting Date" := 20261102D;
        Line.Type := LineType;
        Line.Status := Status;
        Line.Description := 'Issue 62 owned verification';
        if LineType = LineType::Job then begin
            Line."Job No." := 'TS62-PROJECT';
            Line."Job Task No." := 'TS62-TASK';
        end;
        if LineType = LineType::Absence then
            Line."Cause of Absence Code" := 'TS62';
        Line.Insert(false);
        for DayOffset := 0 to 1 do begin
            Detail.Init();
            Detail."Time Sheet No." := SheetNo;
            Detail."Time Sheet Line No." := LineNo;
            Detail.Date := 20261102D + DayOffset;
            Detail.Type := LineType;
            Detail.Status := Status;
            Detail.Quantity := Hours + DayOffset;
            Detail.Insert(false);
        end;
    end;

    /// <summary>Deletes only records bearing the fixed issue 62 ownership identifiers.</summary>
    procedure Cleanup()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
    begin
        Detail.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Detail.DeleteAll(false);
        Line.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Line.DeleteAll(false);
        Header.SetFilter("No.", 'TS62-A|TS62-B');
        Header.DeleteAll(false);
        Resource.SetFilter("No.", 'TS62-REGINN|TS62-OTHER');
        Resource.DeleteAll(false);
    end;
}
