namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Text;
using System.Utilities;

/// <summary>Self-contained raw fixtures for follow-up tests, including reversible resource mapping.</summary>
codeunit 97190 "Proj. Follow-up Fixture ori" implements "Msg Interface ori"
{
    SingleInstance = true;
    var
        LastManifest: JsonObject;

    /// <summary>Creates only X87 records and records every displaced caller mapping for restoration.</summary>
    procedure Seed() Manifest: JsonObject
    var
        Resource: Record Resource;
        Unit: Record "Unit of Measure";
        ProductGroup: Record "Gen. Product Posting Group";
        BusinessGroup: Record "Gen. Business Posting Group";
        ResourceUnit: Record "Resource Unit of Measure";
        ItemUnit: Record "Item Unit of Measure";
        Customer: Record Customer;
        Project: Record Job;
        Task: Record "Job Task";
        Item: Record Item;
        Prior: JsonArray;
        Owner: JsonObject;
        Prefix: Code[20];
        Staging: Codeunit "Blob Staging ori";
        TempBlob: Codeunit "Temp Blob";
        Base64: Codeunit "Base64 Convert";
        InStr: InStream;
        OutStr: OutStream;
        StagingId: Guid;
    begin
        if LastManifest.Contains('projectNo') then
            Cleanup(LastManifest);
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UserId(), 1, 50));
        if Resource.FindSet(true) then
            repeat
                Clear(Owner);
                Owner.Add('no', Resource."No.");
                Owner.Add('owner', Resource."Time Sheet Owner User ID");
                Prior.Add(Owner);
                Resource."Time Sheet Owner User ID" := 'X87ISOLATED';
                Resource.Modify(false);
            until Resource.Next() = 0;
        Resource.Reset();
        Prefix := CopyStr('X87' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Unit.Code := CopyStr(Prefix, 1, 10);
        Unit.Description := 'X Follow-up hours';
        Unit.Insert(false);
        ProductGroup.Code := Unit.Code;
        ProductGroup.Insert(false);
        BusinessGroup.Code := Unit.Code;
        BusinessGroup.Insert(false);
        Resource.Init();
        Resource."No." := Prefix;
        Resource."Gen. Prod. Posting Group" := ProductGroup.Code;
        Resource.Name := 'X Follow-up technician';
        Resource."Base Unit of Measure" := Unit.Code;
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, 50);
        Resource.Insert(false);
        ResourceUnit."Resource No." := Prefix;
        ResourceUnit.Code := Unit.Code;
        ResourceUnit."Qty. per Unit of Measure" := 1;
        ResourceUnit.Insert(false);
        Customer."No." := Prefix;
        Customer."Gen. Bus. Posting Group" := BusinessGroup.Code;
        Customer.Name := 'X Follow-up customer';
        Customer.Insert(false);
        Item."No." := Prefix;
        Item."Gen. Prod. Posting Group" := ProductGroup.Code;
        Item.Description := 'X Replacement valve';
        Item.Type := Item.Type::"Non-Inventory";
        Item."Base Unit of Measure" := Unit.Code;
        Item.Insert(false);
        ItemUnit."Item No." := Prefix;
        ItemUnit.Code := Unit.Code;
        ItemUnit."Qty. per Unit of Measure" := 1;
        ItemUnit.Insert(false);
        Project."No." := Prefix;
        Project.Description := 'X Follow-up project';
        Project.Status := Project.Status::Open;
        Project."Bill-to Customer No." := Prefix;
        Project."Sell-to Customer No." := Prefix;
        Project."Project Manager" := CopyStr(UserId(), 1, 50);
        Project.Insert(false);
        Task."Job No." := Prefix;
        Task."Job Task No." := '1000';
        Task."Job Task Type" := Task."Job Task Type"::Posting;
        Task.Description := 'X Original task';
        Task.Insert(false);
        Manifest.Add('projectNo', Prefix);
        Manifest.Add('resourceNo', Prefix);
        Manifest.Add('itemNo', Prefix);
        Manifest.Add('taskNo', '1000');
        Manifest.Add('unit', Unit.Code);
        Manifest.Add('priorResources', Prior);
        TempBlob.CreateOutStream(OutStr);
        Base64.FromBase64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', OutStr);
        TempBlob.CreateInStream(InStr);
        StagingId := Staging.Create(InStr, 'demo-valve.png', 'image/png', 'FollowUp87 test');
        Manifest.Add('stagingId', Format(StagingId, 0, 4));
        LastManifest := Manifest;
    end;

    /// <summary>Restores mappings and removes only records named by the fixture.</summary>
    procedure Cleanup(Manifest: JsonObject)
    var
        Header: Record "Proj. Follow-up Request ori";
        Line: Record "Proj. Follow-up Req. Line ori";
        Planning: Record "Job Planning Line";
        Task: Record "Job Task";
        Project: Record Job;
        Resource: Record Resource;
        Item: Record Item;
        Customer: Record Customer;
        Unit: Record "Unit of Measure";
        ProductGroup: Record "Gen. Product Posting Group";
        BusinessGroup: Record "Gen. Business Posting Group";
        ResourceUnit: Record "Resource Unit of Measure";
        ItemUnit: Record "Item Unit of Measure";
        Token: JsonToken;
        Prefix: Code[20];
        Staging: Codeunit "Blob Staging ori";
        TempBlob: Codeunit "Temp Blob";
        StagingId: Guid;
    begin
        Prefix := CopyStr(Manifest.GetText('projectNo'), 1, 20);
        if CopyStr(Prefix, 1, 3) <> 'X87' then
            Error('Only X87 fixture records can be removed.');
        Header.SetRange("Project No.", Prefix);
        if Header.FindSet() then
            repeat
                Line.SetRange("Request No.", Header."Entry No.");
                Line.DeleteAll(false);
            until Header.Next() = 0;
        Header.DeleteAll(false);
        Planning.SetRange("Job No.", Prefix);
        Planning.DeleteAll(false);
        Task.SetRange("Job No.", Prefix);
        Task.DeleteAll(false);
        if Project.Get(Prefix) then
            Project.Delete(false);
        ResourceUnit.SetRange("Resource No.", Prefix);
        ResourceUnit.DeleteAll(false);
        ItemUnit.SetRange("Item No.", Prefix);
        ItemUnit.DeleteAll(false);
        if Resource.Get(Prefix) then
            Resource.Delete(false);
        if Item.Get(Prefix) then
            Item.Delete(false);
        if Customer.Get(Prefix) then
            Customer.Delete(false);
        if Unit.Get(Manifest.GetText('unit')) then
            Unit.Delete(false);
        if ProductGroup.Get(Manifest.GetText('unit')) then
            ProductGroup.Delete(false);
        if BusinessGroup.Get(Manifest.GetText('unit')) then
            BusinessGroup.Delete(false);
        foreach Token in Manifest.GetArray('priorResources') do
            if Resource.Get(Token.AsObject().GetText('no')) then begin
                Resource."Time Sheet Owner User ID" := CopyStr(Token.AsObject().GetText('owner'), 1, 50);
                Resource.Modify(false);
            end;
        if Manifest.Contains('stagingId') then begin
            Evaluate(StagingId, Manifest.GetText('stagingId'));
            Staging.Take(StagingId, TempBlob);
        end;
        Clear(LastManifest);
    end;

    /// <summary>Restores the last failed test fixture in this session.</summary>
    procedure CleanupLast()
    begin
        if LastManifest.Contains('projectNo') then
            Cleanup(LastManifest);
    end;

    /// <summary>Test-only seed is available on an own tenant with the test extension installed.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(CompanyName().StartsWith('CRONUS'));
    end;

    /// <summary>No filter envelope.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the fixture purpose.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Seeds X87 follow-up verification data.');
    end;

    /// <summary>Outbound fixture response.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Seeds data; cleanup is a direct helper, never a delete operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        if not IsEnabled() then
            Error('Only CRONUS test companies are allowed.');
        Response := Seed();
        Response.Add('status', 'Success');
        Argument.SetResponseJson(Response);
    end;
}
