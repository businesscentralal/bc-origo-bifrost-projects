namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;

/// <summary>Owns isolated native unit-test data. These component tests do not assert feature licensing or shipping MCP acceptance.</summary>
codeunit 97102 "Projects Test Library ori"
{
    Access = Internal;
    /// <summary>Initializes only the owned test company's missing project setup.</summary>
    procedure Initialize()
    var
        JobsSetup: Record "Jobs Setup";
        Setup: Record "Projects Setup ori";
    begin
        if not JobsSetup.Get() then begin
            JobsSetup.Init();
            JobsSetup.Insert(true);
        end;
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(true);
    end;
    /// <summary>Creates a fresh customer and project number for every test.</summary>
    procedure NewProjectRequest() Request: JsonObject
    var
        Customer: Record Customer;
        ProjectNo: Code[20];
    begin
        Initialize();
        ProjectNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(ProjectNo));
        Customer.Init();
        Customer."No." := ProjectNo;
        Customer.Name := 'X Projects unit test';
        Customer.Insert(true);
        Request.Add('projectNo', ProjectNo);
        Request.Add('billToCustomerNo', Customer."No.");
        Request.Add('description', 'X Projects unit test');
    end;
    /// <summary>Runs the native component after validation without initializing licence or backend data.</summary>
    procedure ExecuteNative(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Dispatch: Codeunit "Projects Write ori";
        Kind: Text;
        Operation: Text;
        TypeName: Text;
        Names: List of [Text];
        Ordinals: List of [Integer];
        Parts: List of [Text];
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        TypeName := Names.Get(Ordinals.IndexOf(MessageType.AsInteger()));
        Parts := TypeName.Split('.');
        Kind := Parts.Get(2);
        Operation := Parts.Get(3);
        Commit();
        Dispatch.Execute(TempArgument, Kind, Operation);
        Response := TempArgument.GetResponseJson();
    end;
    /// <summary>Executes the native component inside the caller's transaction without a Commit.</summary>
    procedure ExecuteNativeInTransaction(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Dispatch: Codeunit "Projects Write ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Dispatch.Execute(TempArgument, 'Project', 'Create');
        Response := TempArgument.GetResponseJson();
    end;

    /// <summary>Requires the expected status from the actual JSON response.</summary>
    procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Assert: Codeunit "Library Assert";
    begin
        Assert.AreEqual(Expected, Response.GetText('status'), 'Unexpected native component response: ' + Format(Response));
    end;
    /// <summary>Creates every business master used by a planning-line test; no demo item/resource/account is reused.</summary>
    procedure SeedPlanningMaster(CustomerNo: Code[20]; Kind: Text): Code[20]
    var
        Customer: Record Customer;
        GenBusGroup: Record "Gen. Business Posting Group";
        GenProdGroup: Record "Gen. Product Posting Group";
        PostingSetup: Record "General Posting Setup";
        UnitOfMeasure: Record "Unit of Measure";
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        Account: Record "G/L Account";
        CodeValue: Code[20];
    begin
        CodeValue := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(CodeValue));
        GenBusGroup.Init();
        GenBusGroup.Code := CodeValue;
        GenBusGroup.Description := 'X Projects native test';
        GenBusGroup.Insert(true);
        GenProdGroup.Init();
        GenProdGroup.Code := CodeValue;
        GenProdGroup.Description := 'X Projects native test';
        GenProdGroup.Insert(true);
        PostingSetup.Init();
        PostingSetup."Gen. Bus. Posting Group" := CodeValue;
        PostingSetup."Gen. Prod. Posting Group" := CodeValue;
        PostingSetup.Insert(true);
        Customer.Get(CustomerNo);
        Customer.Validate("Gen. Bus. Posting Group", CodeValue);
        Customer.Modify(true);
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := CopyStr(CodeValue, 1, MaxStrLen(UnitOfMeasure.Code));
        UnitOfMeasure.Description := 'X Projects unit';
        UnitOfMeasure.Insert(true);
        case Kind of
            'Item':
                begin
                    Item.Init();
                    Item."No." := CodeValue;
                    Item.Description := 'X Projects item';
                    Item.Type := Item.Type::"Non-Inventory";
                    Item."Gen. Prod. Posting Group" := CodeValue;
                    Item."Base Unit of Measure" := UnitOfMeasure.Code;
                    Item.Insert(true);
                    ItemUnit.Init();
                    ItemUnit."Item No." := Item."No.";
                    ItemUnit.Code := UnitOfMeasure.Code;
                    ItemUnit."Qty. per Unit of Measure" := 1;
                    ItemUnit.Insert(true);
                end;
            'Resource':
                begin
                    Resource.Init();
                    Resource."No." := CodeValue;
                    Resource.Name := 'X Projects resource';
                    Resource."Gen. Prod. Posting Group" := CodeValue;
                    Resource."Base Unit of Measure" := UnitOfMeasure.Code;
                    Resource.Insert(true);
                    ResourceUnit.Init();
                    ResourceUnit."Resource No." := Resource."No.";
                    ResourceUnit.Code := UnitOfMeasure.Code;
                    ResourceUnit."Qty. per Unit of Measure" := 1;
                    ResourceUnit.Insert(true);
                end;
            'G/L Account':
                begin
                    Account.Init();
                    Account."No." := CodeValue;
                    Account.Name := 'X Projects account';
                    Account."Account Type" := Account."Account Type"::Posting;
                    Account."Direct Posting" := true;
                    Account."Gen. Bus. Posting Group" := CodeValue;
                    Account."Gen. Prod. Posting Group" := CodeValue;
                    Account.Insert(true);
                end;
        end;
        exit(CodeValue);
    end;

    /// <summary>Creates a project and posting task, then returns a complete self-seeded planning-line request.</summary>
    procedure NewPlanningRequest(Kind: Text) PlanningRequest: JsonObject
    var
        ProjectRequest: JsonObject;
        TaskRequest: JsonObject;
        MasterNo: Code[20];
    begin
        ProjectRequest := NewProjectRequest();
        MasterNo := SeedPlanningMaster(CopyStr(ProjectRequest.GetText('billToCustomerNo'), 1, 20), Kind);
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Project.Create", ProjectRequest), 'Success');
        TaskRequest.Add('projectNo', ProjectRequest.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'X100');
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        PlanningRequest.Add('projectNo', ProjectRequest.GetText('projectNo'));
        PlanningRequest.Add('taskNo', 'X100');
        PlanningRequest.Add('lineNo', 10000);
        PlanningRequest.Add('type', Kind);
        PlanningRequest.Add('no', MasterNo);
        PlanningRequest.Add('lineType', 'Both Budget and Billable');
        PlanningRequest.Add('planningDate', '2026-10-16');
        PlanningRequest.Add('quantity', 3);
        PlanningRequest.Add('unitCost', 7);
        PlanningRequest.Add('unitPrice', 11);
    end;

}
