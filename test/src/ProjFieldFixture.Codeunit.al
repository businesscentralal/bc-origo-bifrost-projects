namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Sales.Customer;
using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Own-tenant, raw-data fixtures for technician read tests and MCP. Cleanup is not a message operation.</summary>
codeunit 97180 "Proj. Field Fixture ori" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>Creates an owned resource, two visits today, one tomorrow, and own time and usage.</summary>
    procedure Seed(VisitCount: Integer) Manifest: JsonObject
    var
        Resource: Record Resource;
        Unit: Record "Unit of Measure";
        Customer: Record Customer;
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Item: Record Item;
        Usage: Record "TS Usage Line ori";
        Prefix: Code[15];
        ProjectNos: JsonArray;
        Index: Integer;
        FirstProject: JsonToken;
    begin
        Prefix := CopyStr('X82' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 15);
        Unit.Code := CopyStr(Prefix, 1, 10);
        Unit.Description := 'X Hours';
        Unit.Insert(false);
        Resource."No." := Prefix;
        Resource.Name := 'X Technician';
        Resource."Base Unit of Measure" := Unit.Code;
        Resource."Unit Cost" := 10;
        Resource."Unit Price" := 20;
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(UserId()), 1, 50);
        Resource.Insert(false);
        Customer."No." := Prefix;
        Customer.Name := 'X Site Customer';
        Customer.Insert(false);
        Item."No." := Prefix;
        Item.Description := 'X Planned part';
        Item."Base Unit of Measure" := Unit.Code;
        Item.Insert(false);
        Header."No." := Prefix;
        Header."Resource No." := Resource."No.";
        Header."Starting Date" := Today() - Date2DWY(Today(), 1) + 1;
        Header."Ending Date" := Header."Starting Date" + 6;
        Header."Owner User ID" := Resource."Time Sheet Owner User ID";
        Header."Approver User ID" := 'XAPPROVER82';
        Header.Insert(false);
        for Index := 1 to VisitCount + 1 do begin
            Clear(Project);
            Project."No." := CopyStr(Prefix + Format(Index, 0, 9), 1, 20);
            Project.Description := 'X Planned work';
            Project."Sell-to Customer No." := Customer."No.";
            Project."Bill-to Customer No." := Customer."No.";
            Project."Sell-to Customer Name" := Customer.Name;
            Project."Ship-to Name" := 'X Work site';
            Project."Ship-to Address" := 'X Site street';
            Project."Ship-to City" := 'X City';
            Project."Ship-to Post Code" := 'X100';
            Project."Ship-to Phone No." := 'X000';
            Project.Insert(false);
            ProjectNos.Add(Project."No.");
            Clear(Task);
            Task."Job No." := Project."No.";
            Task."Job Task No." := CopyStr('X' + Format(Index, 0, 9), 1, 20);
            Task.Description := 'X Planned task';
            Task."Job Task Type" := Task."Job Task Type"::Posting;
            Task.Insert(false);
            Clear(Planning);
            Planning."Job No." := Project."No.";
            Planning."Job Task No." := Task."Job Task No.";
            Planning."Line No." := 10000;
            Planning.Type := Planning.Type::Resource;
            Planning."No." := Resource."No.";
            Planning.Quantity := 4;
            Planning."Remaining Qty." := 3;
            Planning."Unit of Measure Code" := Unit.Code;
            Planning."Planning Date" := Today();
            if Index > VisitCount then
                Planning."Planning Date" := Today() + 1;
            Planning.Insert(false);
            Planning."Line No." := 20000;
            Planning.Type := Planning.Type::Item;
            Planning."No." := Item."No.";
            Planning.Quantity := 5;
            Planning."Remaining Qty." := 2;
            Planning.Insert(false);
            Clear(Line);
            Line."Time Sheet No." := Header."No.";
            Line."Line No." := Index * 10000;
            Line."Time Sheet Starting Date" := Header."Starting Date";
            Line.Type := Line.Type::Job;
            Line."Job No." := Project."No.";
            Line."Job Task No." := Task."Job Task No.";
            Line.Insert(false);
            Clear(Detail);
            Detail."Time Sheet No." := Header."No.";
            Detail."Time Sheet Line No." := Line."Line No.";
            Detail.Date := Today();
            Detail.Quantity := 1.5;
            Detail.Insert(false);
            Clear(Usage);
            Usage."Time Sheet No." := Header."No.";
            Usage."Time Sheet Line No." := Line."Line No.";
            Usage."Resource No." := Resource."No.";
            Usage.Type := Usage.Type::Resource;
            Usage."No." := Resource."No.";
            Usage.Date := Today();
            Usage.Quantity := 1;
            Usage."Unit of Measure Code" := Unit.Code;
            Usage.Insert(false);
        end;
        Manifest.Add('resourceNo', Resource."No.");
        Manifest.Add('timeSheetNo', Header."No.");
        ProjectNos.Get(0, FirstProject);
        Manifest.Add('projectNo', FirstProject.AsValue().AsText());
        Manifest.Add('taskNo', 'X1');
        Manifest.Add('projects', ProjectNos);
        Manifest.Add('date', Format(Today(), 0, 9));
        Manifest.Add('unit', Unit.Code);
    end;

    /// <summary>Removes only records named by the self-seeded manifest.</summary>
    procedure Cleanup(Manifest: JsonObject)
    var
        Resource: Record Resource;
        Unit: Record "Unit of Measure";
        Customer: Record Customer;
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Usage: Record "TS Usage Line ori";
        Item: Record Item;
        Token: JsonToken;
        ProjectNo: Code[20];
        ResourceNo: Code[20];
    begin
        ResourceNo := CopyStr(Manifest.GetText('resourceNo'), 1, 20);
        if CopyStr(ResourceNo, 1, 3) <> 'X82' then
            Error('Only X82 fixtures can be removed.');
        foreach Token in Manifest.GetArray('projects') do begin
            ProjectNo := CopyStr(Token.AsValue().AsText(), 1, 20);
            Planning.SetRange("Job No.", ProjectNo);
            Planning.DeleteAll(false);
            Task.SetRange("Job No.", ProjectNo);
            Task.DeleteAll(false);
            if Project.Get(ProjectNo) then
                Project.Delete(false);
        end;
        Usage.SetRange("Time Sheet No.", ResourceNo);
        Usage.DeleteAll(false);
        Detail.SetRange("Time Sheet No.", ResourceNo);
        Detail.DeleteAll(false);
        Line.SetRange("Time Sheet No.", ResourceNo);
        Line.DeleteAll(false);
        if Header.Get(ResourceNo) then
            Header.Delete(false);
        if Resource.Get(ResourceNo) then
            Resource.Delete(false);
        if Item.Get(ResourceNo) then
            Item.Delete(false);
        if Customer.Get(ResourceNo) then
            Customer.Delete(false);
        if Unit.Get(Manifest.GetText('unit')) then
            Unit.Delete(false);
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
        exit('Seeds X82 technician verification data.');
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
        Response := Seed(2);
        Response.Add('status', 'Success');
        Argument.SetResponseJson(Response);
    end;
}
