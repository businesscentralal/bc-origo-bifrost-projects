namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>
/// Test extension only (projects#38): seeds a fixed, self-owned dataset for live MCP verification of the
/// self-service and approval types. Everything carries the X38M prefix and is removed by Test.SelfServiceFixture.Cleanup.
/// </summary>
codeunit 97161 "TS Self Service Fixture ori" implements "Msg Interface ori"
{
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
        exit('Test extension only: creates the X38M self-service fixture in a CRONUS verification company.');
    end;

    /// <summary>Declares that fixture creation writes test data.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Creates the fixture once; refuses when it already exists.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        Argument.AssertVersion1();
        if not IsEnabled() then
            Error('This test fixture requires a CRONUS verification company and native write permissions.');
        Seed();
        Response.Add('status', 'Success');
        Response.Add('ownSheet', 'X38M-OWN1');
        Response.Add('queueSheet', 'X38M-Q1');
        Response.Add('foreignSheet', 'X38M-FOR');
        Response.Add('ownResource', 'X38M-OWN');
        Response.Add('foreignResource', 'X38M-EMP');
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Creates own, queued and foreign sheets for the calling user.</summary>
    procedure Seed()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Comment: Record "Time Sheet Comment Line";
        Caller: Code[50];
    begin
        if Resource.Get('X38M-OWN') or Resource.Get('X38M-EMP') or Header.Get('X38M-OWN1') or Header.Get('X38M-Q1') or Header.Get('X38M-FOR') then
            Error('The X38M fixture already exists; run Test.SelfServiceFixture.Cleanup first.');
        Caller := CopyStr(UpperCase(UserId()), 1, 50);
        AddResource('X38M-OWN', Caller, 'X38M-APPR');
        AddResource('X38M-EMP', 'X38M-EMPA', Caller);
        AddHeader('X38M-OWN1', 'X38M-OWN', Caller, 'X38M-APPR');
        AddHeader('X38M-Q1', 'X38M-EMP', 'X38M-EMPA', Caller);
        AddHeader('X38M-FOR', 'X38M-EMP', 'X38M-EMPA', 'X38M-APPR');
        AddLine('X38M-OWN1', 10000, "Time Sheet Status"::Open, 4);
        AddLine('X38M-OWN1', 20000, "Time Sheet Status"::Rejected, 2);
        Comment.Init();
        Comment."No." := 'X38M-OWN1';
        Comment."Time Sheet Line No." := 20000;
        Comment."Line No." := 10000;
        Comment.Date := 20991102D;
        Comment.Comment := 'X38M fixture rejection reason';
        Comment.Insert(false);
        AddLine('X38M-Q1', 10000, "Time Sheet Status"::Submitted, 6);
        AddLine('X38M-Q1', 20000, "Time Sheet Status"::Submitted, 3);
        AddLine('X38M-FOR', 10000, "Time Sheet Status"::Submitted, 5);
    end;

    /// <summary>Deletes only X38M fixture records, including sheets the MCP run created for X38M resources.</summary>
    procedure Cleanup()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Comment: Record "Time Sheet Comment Line";
        SheetFilter: Text;
    begin
        Header.SetFilter("Resource No.", 'X38M-OWN|X38M-EMP');
        if Header.FindSet() then
            repeat
                if SheetFilter <> '' then
                    SheetFilter += '|';
                SheetFilter += Header."No.";
            until Header.Next() = 0;
        if SheetFilter <> '' then begin
            Comment.SetFilter("No.", SheetFilter);
            Comment.DeleteAll(false);
            Detail.SetFilter("Time Sheet No.", SheetFilter);
            Detail.DeleteAll(false);
            Line.SetFilter("Time Sheet No.", SheetFilter);
            Line.DeleteAll(false);
            Header.DeleteAll(false);
        end;
        Resource.SetFilter("No.", 'X38M-OWN|X38M-EMP');
        Resource.DeleteAll(false);
    end;

    local procedure AddResource(ResourceNo: Code[20]; Owner: Code[50]; Approver: Code[50])
    var
        Resource: Record Resource;
    begin
        Resource.Init();
        Resource."No." := ResourceNo;
        Resource.Name := 'X38M self-service verification';
        Resource.Type := Resource.Type::Person;
        Resource."Base Unit of Measure" := 'HOUR';
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := Owner;
        Resource."Time Sheet Approver User ID" := Approver;
        Resource.Insert(false);
    end;

    local procedure AddHeader(SheetNo: Code[20]; ResourceNo: Code[20]; Owner: Code[50]; Approver: Code[50])
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := SheetNo;
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := 20991102D;
        Header."Ending Date" := 20991108D;
        Header."Owner User ID" := Owner;
        Header."Approver User ID" := Approver;
        Header.Insert(false);
    end;

    local procedure AddLine(SheetNo: Code[20]; LineNo: Integer; Status: Enum "Time Sheet Status"; Hours: Decimal)
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
    begin
        Header.Get(SheetNo);
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := LineNo;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        Line.Status := Status;
        Line."Approver ID" := Header."Approver User ID";
        Line.Description := 'X38M fixture line';
        Line.Insert(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := LineNo;
        Detail.Date := Header."Starting Date";
        Detail.Type := Line.Type;
        Detail.Status := Status;
        Detail.Quantity := Hours;
        Detail.Insert(false);
    end;
}
