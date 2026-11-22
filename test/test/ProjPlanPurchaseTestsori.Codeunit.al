namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;
using Microsoft.Purchases.Setup;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

/// <summary>Issue #74 acceptance tests, with owned raw project, vendor, item, stock and accounting data.</summary>
codeunit 97171 "Proj. Plan Purchase Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";
        Fixture: Codeunit "Proj. Plan Purch Fixture ori";

    /// <summary>AC01 Preview rolls back and two vendors produce linked orders.</summary>
    [Test]
    procedure PreviewThenCreateTwoVendors()
    var
        Planning: Record "Job Planning Line";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        PlanningRequest: JsonObject;
    begin
        // [SCENARIO] A new project needs two different items from different vendors.
        Request := Fixture.Seed(true);
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.FindFirst();
        PlanningRequest := Fixture.NewItemRequest(Planning."Job No.", 20000);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanningRequest), 'Success');
        Item.Get(PlanningRequest.GetText('no'));
        Fixture.ConfigurePurchaseItem(Item, Planning."Job No.");
        Request.Add('preview', true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('proposals').Count(), 'Two uncovered planning lines');
        Assert.AreEqual(0, Response.GetArray('purchaseOrders').Count(), 'Preview creates no orders');
        AssertScratchEmpty();
        Line.SetRange("Job No.", Planning."Job No.");
        Assert.IsTrue(Line.IsEmpty(), 'Preview retains no purchase lines');
        Request.Replace('preview', false);
        Request.Add('expectedCount', 2);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('purchaseOrders').Count(), 'One order per vendor');
        Assert.AreEqual(2, Line.Count(), 'Two linked item lines');
        if Line.FindSet() then
            repeat
                Assert.AreEqual('X100', Line."Job Task No.", 'Native task link');
                Assert.IsTrue(Line."Job Planning Line No." > 0, 'Native planning link');
                Header.Get(Line."Document Type", Line."Document No.");
                Assert.AreEqual(Header."Buy-from Vendor No.", Line."Buy-from Vendor No.", 'Native vendor');
            until Line.Next() = 0;
        AssertScratchEmpty();
    end;

    /// <summary>AC02 Native receipt and invoice post actual project usage.</summary>
    [Test]
    procedure ReceiveInvoicePostsProjectUsage()
    var
        Line: Record "Purchase Line";
        Header: Record "Purchase Header";
        Ledger: Record "Job Ledger Entry";
        Post: Codeunit "Purch.-Post";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] The link created by order planning must work through native posting.
        Request := Fixture.Seed(true);
        Request.Add('expectedCount', 1);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Line.SetRange("Job No.", Request.GetText('projectNo'));
        Line.FindFirst();
        Header.Get(Line."Document Type", Line."Document No.");
        Header.Validate("Vendor Invoice No.", Header."No.");
        Header.Receive := true;
        Header.Invoice := true;
        Header.Modify(true);
        Post.Run(Header);
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Ledger.SetRange("Job Task No.", 'X100');
        Ledger.SetRange("Entry Type", Ledger."Entry Type"::Usage);
        Ledger.SetRange(Type, Ledger.Type::Item);
        Ledger.CalcSums(Quantity);
        Assert.AreEqual(3, Ledger.Quantity, 'Receipt and invoice post three units of project usage');
    end;

    /// <summary>AC03 Real self-posted stock fully covers the planning line.</summary>
    [Test]
    procedure PostedStockIsSkipped()
    var
        Planning: Record "Job Planning Line";
        TempJournal: Record "Item Journal Line" temporary;
        Item: Record Item;
        Vendor: Record Vendor;
        Post: Codeunit "Item Jnl.-Post Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Self-posted stock covers all demand; no proposal or order is made.
        Request := Fixture.Seed(true);
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.FindFirst();
        Item.Get(Planning."No.");
        Vendor.Get(Item."Vendor No.");
        TempJournal."Line No." := 10000;
        TempJournal."Entry Type" := TempJournal."Entry Type"::"Positive Adjmt.";
        TempJournal.Validate("Posting Date", WorkDate());
        TempJournal.Validate("Document No.", Item."No.");
        TempJournal.Validate("Item No.", Item."No.");
        TempJournal.Validate("Gen. Bus. Posting Group", Vendor."Gen. Bus. Posting Group");
        TempJournal.Validate(Quantity, 3);
        TempJournal.Validate("Unit Cost", 7);
        Post.RunWithCheck(TempJournal);
        Request.Add('preview', true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('proposals').Count(), 'Stock covers demand');
        Assert.AreEqual(1, Response.GetArray('skipped').Count(), 'Covered demand is reported');
        Assert.AreEqual('coveredByStockOrSupply', FirstObject(Response.GetArray('skipped')).GetText('reason'), 'Explicit covered reason');
        AssertScratchEmpty();
    end;

    /// <summary>AC04 Existing scratch lines are preserved and calculation is refused.</summary>
    [Test]
    procedure ExistingOrderPlanningIsPreserved()
    var
        Scratch: Record "Requisition Line";
        Request: JsonObject;
        Response: JsonObject;
        Id: Guid;
    begin
        // [SCENARIO] A caller's pending work must never be removed by this operation.
        Request := Fixture.Seed(true);
        Scratch."Worksheet Template Name" := '';
        Scratch."Journal Batch Name" := Scratch.GetJnlBatchNameForOrderPlanning();
        Scratch."Line No." := 987654;
        Scratch."User ID" := CopyStr(UserId(), 1, MaxStrLen(Scratch."User ID"));
        Scratch.Insert(false);
        Id := Scratch.SystemId;
        Response := Execute(Request);
        AssertCode(Response, 'PreconditionFailed');
        Assert.IsTrue(Response.GetText('nextStep').Contains('Order Planning') or
            Response.GetText('nextStep').Contains('Pöntunaráætlun'), 'Names the localized page to finish');
        Assert.IsTrue(Scratch.GetBySystemId(Id), 'Caller scratch line survives');
        Scratch.Delete(true);
        Commit();
    end;

    /// <summary>AC02 The type is a write: no count is asked for, and a wrong expectedCount is ignored.</summary>
    [Test]
    procedure ExpectedCountIgnored_NoConfirmation()
    var
        Request: JsonObject;
    begin
        // [SCENARIO] Creating purchase orders is not posting, so neither a missing nor a wrong count refuses it.
        Request := Fixture.Seed(true);
        Request.Add('expectedCount', 99);
        Library.AssertStatus(Execute(Request), 'Success');
        AssertScratchEmpty();
    end;

    /// <summary>AC02 Without expectedCount the request runs at once.</summary>
    [Test]
    procedure NoExpectedCount_Runs()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := Fixture.Seed(true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetArray('purchaseOrders').Count(), 'The order is created');
    end;

    /// <summary>AC01 Repeated creation skips demand already supplied by its linked order.</summary>
    [Test]
    procedure ExistingSupplyIsSkipped()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] A second call must not purchase the same demand twice.
        Request := Fixture.Seed(true);
        Request.Add('expectedCount', 1);
        Library.AssertStatus(Execute(Request), 'Success');
        Request.Add('preview', true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('proposals').Count(), 'Existing supply covers demand');
        Assert.AreEqual(1, Response.GetArray('skipped').Count(), 'Existing supply reported');
        AssertScratchEmpty();
    end;

    /// <summary>AC05 Request validation rejects missing, malformed, conflicting and unknown parameters.</summary>
    [Test]
    procedure InvalidRequestParameters()
    var
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
    begin
        // [SCENARIO] Invalid syntax is refused before any native work.
        Fixture.Initialize(true);
        AssertCode(Execute(Request), 'MissingParameter');
        Request.Add('projectNo', 'XUNKNOWN74');
        Request.Add('unexpected', true);
        AssertCode(Execute(Request), 'UnknownParameter');
        Request.Remove('unexpected');
        Request.Add('preview', 'true');
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request.Replace('preview', true);
        Request.Add('taskNo', 'X100');
        Numbers.Add(10000);
        Request.Add('planningLineNos', Numbers);
        AssertCode(Execute(Request), 'ConflictingIdentifiers');
        Request.Remove('taskNo');
        Request.Remove('planningLineNos');
        Response := Execute(Request);
        AssertCode(Response, 'RecordNotFound');
    end;

    /// <summary>AC05 Missing planning lines and invalid overrides return stable errors.</summary>
    [Test]
    procedure MissingLineAndUnknownVendor()
    var
        Request: JsonObject;
        Numbers: JsonArray;
        Overrides: JsonArray;
        Override: JsonObject;
    begin
        // [SCENARIO] All selectors and overrides must refer to owned, existing data.
        Request := Fixture.Seed(true);
        Numbers.Add(99999);
        Request.Add('planningLineNos', Numbers);
        AssertCode(Execute(Request), 'RecordNotFound');
        Request.Remove('planningLineNos');
        Override.Add('planningLineNo', 10000);
        Override.Add('vendorNo', 'XUNKNOWN74');
        Overrides.Add(Override);
        Request.Add('vendorOverrides', Overrides);
        AssertCode(Execute(Request), 'RecordNotFound');
        AssertNoPurchase(Request);
    end;

    /// <summary>AC05 Nested malformed values, duplicates and unknown keys are refused.</summary>
    [Test]
    procedure MalformedNestedParameters()
    var
        Request: JsonObject;
        Numbers: JsonArray;
        Overrides: JsonArray;
        Override: JsonObject;
    begin
        // [SCENARIO] Nested arrays have the same strict validation as top-level values.
        Request := Fixture.Seed(true);
        Numbers.Add('10000');
        Request.Add('planningLineNos', Numbers);
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request.Remove('planningLineNos');
        Clear(Numbers);
        Numbers.Add(10000);
        Numbers.Add(10000);
        Request.Add('planningLineNos', Numbers);
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request.Remove('planningLineNos');
        Override.Add('planningLineNo', 10000);
        Override.Add('unknown', 1);
        Overrides.Add(Override);
        Request.Add('vendorOverrides', Overrides);
        AssertCode(Execute(Request), 'UnknownParameter');
        AssertNoPurchase(Request);
    end;

    /// <summary>AC01 Overrides choose the requested valid vendor.</summary>
    [Test]
    procedure VendorOverrideAndExactSelection()
    var
        Planning: Record "Job Planning Line";
        Item: Record Item;
        OtherItem: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        PlanningRequest: JsonObject;
        Numbers: JsonArray;
        Overrides: JsonArray;
        Override: JsonObject;
    begin
        // [SCENARIO] Only a selected line is ordered, using its override vendor.
        Request := Fixture.Seed(true);
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.FindFirst();
        Item.Get(Planning."No.");
        PlanningRequest := Fixture.NewItemRequest(Planning."Job No.", 20000);
        OtherItem.Get(PlanningRequest.GetText('no'));
        Fixture.ConfigurePurchaseItem(OtherItem, Planning."Job No.");
        Numbers.Add(10000);
        Request.Add('planningLineNos', Numbers);
        Override.Add('planningLineNo', 10000);
        Override.Add('vendorNo', OtherItem."Vendor No.");
        Overrides.Add(Override);
        Request.Add('vendorOverrides', Overrides);
        Request.Add('preview', true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(OtherItem."Vendor No.", FirstObject(Response.GetArray('proposals')).GetText('vendorNo'), 'Override vendor');
        Assert.AreEqual(1, Response.GetArray('proposals').Count(), 'Exact planning-line selection');
        AssertScratchEmpty();
    end;

    /// <summary>AC08 Help stays English while discovery and refusals are translated.</summary>
    [Test]
    procedure HelpAndRefusalsInBothLanguages()
    var
        Impl: Codeunit "Proj. Plan Purchase Impl ori";
        English: Text;
        Icelandic: Text;
        Overview: Text;
        OtherOverview: Text;
        OriginalLanguage: Integer;
    begin
        // [SCENARIO] Help chapters are English in every language; discovery is localized.
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := Impl.GetDescription();
        Impl.GetOverview(Overview);
        GlobalLanguage(1039);
        Icelandic := Impl.GetDescription();
        Impl.GetOverview(OtherOverview);
        GlobalLanguage(OriginalLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Translated discovery');
        Assert.AreEqual(Overview, OtherOverview, 'English-only help chapters');
    end;

    /// <summary>AC05 Blocked projects refuse before calculation.</summary>
    [Test]
    procedure BlockedProjectChangesNothing()
    var
        Project: Record Job;
        Request: JsonObject;
    begin
        // [SCENARIO] Purchasing is unavailable on a blocked project.
        Request := Fixture.Seed(true);
        Project.Get(Request.GetText('projectNo'));
        Project.Blocked := Project.Blocked::All;
        Project.Modify(true);
        AssertCode(Execute(Request), 'PreconditionFailed');
        AssertScratchEmpty();
        AssertNoPurchase(Request);
    end;

    /// <summary>AC01 Non-item and billable-only planning lines are reported as skipped.</summary>
    [Test]
    procedure BillableAndTextLinesAreSkipped()
    var
        Planning: Record "Job Planning Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Billing demand and text are never purchased.
        Request := Fixture.Seed(true);
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.FindFirst();
        Planning.Validate("Usage Link", false);
        Planning.Validate("Line Type", Planning."Line Type"::Billable);
        Planning.Modify(true);
        Request.Add('preview', true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual('billableOnly', FirstObject(Response.GetArray('skipped')).GetText('reason'), 'Billable-only reason');
        Planning.Validate(Type, Planning.Type::Text);
        Planning.Modify(true);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual('notItem', FirstObject(Response.GetArray('skipped')).GetText('reason'), 'Non-item reason');
        AssertNoPurchase(Request);
        AssertScratchEmpty();
    end;

    /// <summary>AC05 A late vendor refusal rolls back all calculation scratch.</summary>
    [Test]
    procedure InvalidVendorRollsBackWholeCalculation()
    var
        Item: Record Item;
        Planning: Record "Job Planning Line";
        Request: JsonObject;
    begin
        // [SCENARIO] A native calculated proposal without a usable vendor must leave no scratch or orders.
        Request := Fixture.Seed(true);
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.FindFirst();
        Item.Get(Planning."No.");
        Item.Validate("Vendor No.", '');
        Item.Modify(true);
        Request.Add('preview', true);
        AssertCode(Execute(Request), 'PreconditionFailed');
        AssertScratchEmpty();
        AssertNoPurchase(Request);
    end;

    /// <summary>Native errors roll back the entire planning and purchase transaction.</summary>
    [Test]
    procedure NativeFailureLeavesNoPurchasesOrScratch()
    var
        Setup: Record "Purchases & Payables Setup";
        Request: JsonObject;
    begin
        // [SCENARIO] Native purchase creation fails on missing numbering setup after planning has calculated.
        Request := Fixture.Seed(true);
        Setup.Get();
        Setup."Order Nos." := 'XUNKNOWN74';
        Setup.Modify(false);
        Request.Add('expectedCount', 1);
        AssertCode(Execute(Request), 'BusinessCentralError');
        AssertScratchEmpty();
        AssertNoPurchase(Request);
    end;

    local procedure FirstObject(Values: JsonArray): JsonObject
    var
        Token: JsonToken;
    begin
        Values.Get(0, Token);
        exit(Token.AsObject());
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Plan Purchase Impl ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.PlanningLine.CreatePurchaseOrder";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.SetRequestJson(Request);
        TempArgument.Insert(true);
        Commit();
        Impl.ExecuteNative(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure AssertCode(Response: JsonObject; CodeValue: Text)
    begin
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(CodeValue, Response.GetText('code'), 'Stable refusal code');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
    end;

    local procedure AssertScratchEmpty()
    var
        Scratch: Record "Requisition Line";
    begin
        Scratch.SetRange("Worksheet Template Name", '');
        Scratch.SetRange("User ID", UserId());
        Assert.IsTrue(Scratch.IsEmpty(), 'No scratch lines remain');
    end;

    local procedure AssertNoPurchase(Request: JsonObject)
    var
        Line: Record "Purchase Line";
    begin
        Line.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Line.IsEmpty(), 'Refused request created no purchases');
    end;

}
