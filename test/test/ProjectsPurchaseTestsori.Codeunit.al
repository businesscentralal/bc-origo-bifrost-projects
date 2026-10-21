namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
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
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
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
            Clear(TempArgument);
            Clear(Request);
            Clear(Row);
            Clear(Fields);
            Clear(Data);
            TempArgument.ID := CreateGuid();
            TempArgument.Type := "Message Type ori"::"Data.Records.Set";
            TempArgument.Version := "Message Version ori"::"1.0";
            TempArgument.Subject := '39';
            TempArgument.Insert(true);
            Fields.Add(FieldName, Fixture.GetText('projectNo'));
            Row.Add('id', Format(PurchaseLine.SystemId, 0, 4));
            Row.Add('fields', Fields);
            Data.Add(Row);
            Request.Add('data', Data);
            TempArgument.SetRequestJson(Request);
            Impl := TempArgument.Type;
            // Runs the real public Foundation path; no licensing/EULA test hook or bypass.
            Impl.ExecuteBifrostTask(TempArgument);
            Response := TempArgument.GetResponseJson();
            Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Dedicated project-link field refused: ' + FieldName);
            Assert.IsTrue(Response.GetText('nextStep').Contains('Projects.PurchaseLine.Link'), 'Dedicated message hint');
        end;
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        Assert.AreEqual('', PurchaseLine."Job No.", 'Generic writes changed no project link');
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
        PurchaseLibrary.CreatePurchaseDocumentWithItem(Header, PurchaseLine, Header."Document Type"::Order, Vendor."No.", Item."No.", 1, '', 20260105D);
        JobLibrary.CreateJob(Project);
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        JobLibrary.CreateJobTask(Project, Task);
        Request.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Request.Add('projectNo', Project."No.");
        Request.Add('taskNo', Task."Job Task No.");
    end;
}
