namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Exercises native purchase project-field validation and refusal paths on fresh unposted documents.</summary>
codeunit 97124 "Projects Purchase Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>The MCP fixture creates compatible owned posting setup before creating its inventory purchase.</summary>
    [Test]
    procedure Scenario_AC01_SelfSeededInventoryPurchaseHasValidPostingSetup()
    var
        PurchaseLine: Record "Purchase Line";
        ItemLedger: Record "Item Ledger Entry";
        Fixture: Codeunit "Proj. Purchase MCP Fixture ori";
        Manifest: JsonObject;
        PurchaseSystemId: Guid;
    begin
        // [SCENARIO] A fresh localized company can seed an unposted purchase and its own tracked stock.
        // [GIVEN] No pre-existing purchase or inventory fixture is supplied.
        // [WHEN] The MCP fixture creates all required master data and posting setup.
        Manifest := Fixture.Seed();
        // [THEN] The purchase is unposted and exactly ten owned tracked units exist.
        Evaluate(PurchaseSystemId, Manifest.GetText('purchaseSystemId'));
        PurchaseLine.GetBySystemId(PurchaseSystemId);
        Assert.AreEqual(Manifest.GetText('itemNo'), PurchaseLine."No.", 'Owned inventory purchase item');
        Assert.AreEqual(0, PurchaseLine."Quantity Received", 'The fixture does not receive the purchase');
        Assert.AreEqual(0, PurchaseLine."Quantity Invoiced", 'The fixture does not invoice the purchase');
        ItemLedger.SetRange("Item No.", Manifest.GetText('itemNo'));
        ItemLedger.SetRange("Lot No.", Manifest.GetText('lotNo'));
        ItemLedger.CalcSums(Quantity);
        Assert.AreEqual(10, ItemLedger.Quantity, 'Native posting created the owned tracked stock');
    end;

    /// <summary>Happy Path: Links Through Native Validation.</summary>
    [Test]
    procedure HappyPath_LinksThroughNativeValidation()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest(PurchaseLine);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.GetBoolean('changed'), 'Initial native link changed');
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        Assert.AreEqual(Request.GetText('projectNo'), PurchaseLine."Job No.", 'Project native field validated');
        Assert.AreEqual(Request.GetText('taskNo'), PurchaseLine."Job Task No.", 'Task native field validated');
        Assert.AreEqual(0, PurchaseLine."Quantity Received", 'No receipt posted');
        Assert.AreEqual(0, PurchaseLine."Quantity Invoiced", 'No invoice posted');
    end;

    /// <summary>Edge: Repeat Link Is Unchanged.</summary>
    [Test]
    procedure Edge_RepeatLinkIsUnchanged()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest(PurchaseLine);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.IsFalse(Response.GetBoolean('changed'), 'Repeated link is idempotent');
    end;

    /// <summary>Blocked Project: Refuses Without Linking.</summary>
    [Test]
    procedure BlockedProject_RefusesWithoutLinking()
    var
        PurchaseLine: Record "Purchase Line";
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest(PurchaseLine);
        Project.Get(Request.GetText('projectNo'));
        Project.Blocked := Project.Blocked::All;
        Project.Modify(true);
        Response := Execute(Request);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Blocked project');
        Assert.AreEqual('Change the status with Projects.Project.SetStatus.', Response.GetText('nextStep'), 'Actionable status next step');
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        Assert.AreEqual('', PurchaseLine."Job No.", 'Refusal writes nothing');
    end;

    /// <summary>Received Line: Refuses Without Linking.</summary>
    [Test]
    procedure ReceivedLine_RefusesWithoutLinking()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest(PurchaseLine);
        PurchaseLine."Quantity Received" := 1;
        PurchaseLine.Modify(false);
        Response := Execute(Request);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Received line');
        Assert.AreEqual('Link before receiving; correct posted lines with a credit memo.', Response.GetText('nextStep'), 'Actionable posted-line next step');
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        Assert.AreEqual('', PurchaseLine."Job No.", 'Refusal preserves native line');
    end;

    /// <summary>Conflicting System Id And Document Key: Refuses.</summary>
    [Test]
    procedure ConflictingSystemIdAndDocumentKey_Refuses()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Request: JsonObject;
        OtherRequest: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest(PurchaseLine);
        OtherRequest := NewRequest(OtherLine);
        Request.Add('documentType', 'Order');
        Request.Add('documentNo', OtherLine."Document No.");
        Request.Add('lineNo', OtherLine."Line No.");
        Response := Execute(Request);
        Assert.AreEqual('ConflictingIdentifiers', Response.GetText('code'), 'Different purchase lines');
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        OtherLine.GetBySystemId(OtherLine.SystemId);
        Assert.AreEqual('', PurchaseLine."Job No.", 'First line unchanged');
        Assert.AreEqual('', OtherLine."Job No.", 'Second line unchanged');
    end;

    /// <summary>Common Refusals: Validate Before Writing.</summary>
    [Test]
    procedure CommonRefusals_ValidateBeforeWriting()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Required project/task');
        Request := NewRequest(PurchaseLine);
        Request.Add('unknown', true);
        Response := Execute(Request);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'Unknown key');
        Request.Remove('unknown');
        Request.Replace('systemId', 'invalid-guid');
        Response := Execute(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Malformed SystemId');
        Request.Replace('systemId', Format(CreateGuid(), 0, 4));
        Response := Execute(Request);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing line');
    end;

    /// <summary>Dedicated Fields: Block Generic Writes And Advertise Hint.</summary>
    [Test]
    procedure DedicatedFields_BlockGenericWritesAndAdvertiseHint()
    var
        PurchaseLine: Record "Purchase Line";
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        Request: JsonObject;
        Fixture: JsonObject;
        Row: JsonObject;
        Fields: JsonObject;
        Data: JsonArray;
        Response: JsonObject;
        FieldNames: List of [Text];
        FieldName: Text;
    begin
        Fixture := NewRequest(PurchaseLine);
        FieldNames.Add('Job No.');
        FieldNames.Add('Job Task No.');
        FieldNames.Add('Job Line Type');
        FieldNames.Add('Job Planning Line No.');
        foreach FieldName in FieldNames do begin
            Clear(RequestContent);
            Clear(ResponseContent);
            Clear(Request);
            Clear(Row);
            Clear(Fields);
            Clear(Data);
            Fields.Add(FieldName, Fixture.GetText('projectNo'));
            Row.Add('id', Format(PurchaseLine.SystemId, 0, 4));
            Row.Add('fields', Fields);
            Data.Add(Row);
            Request.Add('data', Data);
            Request.WriteTo(RequestText);
            RequestContent.AddText(RequestText);
            // The supported dispatcher performs the real company/licensing checks and keeps rollback enabled.
            Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '39', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
            ResponseContent.GetSubText(ResponseText, 1);
            Response.ReadFrom(ResponseText);
            Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Dedicated project-link field refused: ' + FieldName);
            Assert.IsTrue(Response.GetText('nextStep').Contains('Projects.PurchaseLine.Link'), 'Dedicated message hint');
        end;
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        Assert.AreEqual('', PurchaseLine."Job No.", 'Generic writes changed no project link');
    end;

    /// <summary>Public Foundation hint events route all four dedicated project-link fields.</summary>
    [Test]
    procedure DedicatedHints_AllFieldsRegistered()
    var
        PurchaseLine: Record "Purchase Line";
        TempArgument: Record "Message Argument ori" temporary;
        FieldNos: List of [Integer];
        FieldNo: Integer;
        Hint: Text;
    begin
        FieldNos.Add(PurchaseLine.FieldNo("Job No."));
        FieldNos.Add(PurchaseLine.FieldNo("Job Task No."));
        FieldNos.Add(PurchaseLine.FieldNo("Job Line Type"));
        FieldNos.Add(PurchaseLine.FieldNo("Job Planning Line No."));
        foreach FieldNo in FieldNos do begin
            Hint := TempArgument.GetDedicatedMessageTypeHintForField(Database::"Purchase Line", FieldNo);
            Assert.IsTrue(Hint.Contains('Projects.PurchaseLine.Link'), 'Real Foundation hint publisher is wired');
            Assert.IsTrue(Hint.Contains('Projects.ItemUsage.Post'), 'Both dedicated type hints');
        end;
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Purchase: Codeunit "Projects Purchase ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Purchase.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure NewRequest(var PurchaseLine: Record "Purchase Line") Request: JsonObject
    var
        Header: Record "Purchase Header";
        Vendor: Record Vendor;
        Item: Record Item;
        Project: Record Job;
        Task: Record "Job Task";
        PurchaseLibrary: Codeunit "Library - Purchase";
        InventoryLibrary: Codeunit "Library - Inventory";
        JobLibrary: Codeunit "Library - Job";
    begin
        Library.Initialize();
        PurchaseLibrary.CreateVendor(Vendor);
        InventoryLibrary.CreateItem(Item);
        PurchaseLibrary.CreatePurchaseDocumentWithItem(Header, PurchaseLine, Header."Document Type"::Order, Vendor."No.", Item."No.", 1, '', WorkDate());
        JobLibrary.CreateJob(Project);
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        JobLibrary.CreateJobTask(Project, Task);
        Request.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Request.Add('projectNo', Project."No.");
        Request.Add('taskNo', Task."Job Task No.");
    end;
}
