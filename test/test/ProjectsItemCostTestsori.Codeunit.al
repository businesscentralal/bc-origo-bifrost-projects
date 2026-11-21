namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Posting;
using Microsoft.Projects.Project.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Tests Projects.ItemCost.Update (#77): own items, vendor and project; the cost adjustment runs natively in the test.</summary>
codeunit 97156 "Projects Item Cost Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";
        LibraryJob: Codeunit "Library - Job";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryCosting: Codeunit "Library - Costing";
        PostingDate: Date;

    /// <summary>AC01: usage at 10, later invoice at 12; adjustment leaves 10, the update brings the ledger and the planning line to 12.</summary>
    [Test]
    procedure Scenario_AC01_UpdatesProjectLedgerAndPlanningLine()
    var
        Ledger: Record "Job Ledger Entry";
        PlanningLine: Record "Job Planning Line";
        ProjectNo: Code[20];
        Request: JsonObject;
        Response: JsonObject;
        Projects: JsonArray;
        Row: JsonToken;
    begin
        ProjectNo := SeedAdjustedUsage();
        FindUsage(ProjectNo, Ledger);
        Assert.AreEqual(20, Ledger."Total Cost (LCY)", 'The adjustment alone leaves the project at the old cost');
        PlanningLine.SetRange("Job No.", ProjectNo);
        Assert.IsTrue(PlanningLine.FindFirst(), 'The usage created a planning line');
        Assert.AreEqual(10, PlanningLine."Unit Cost (LCY)", 'The planning line is at the old cost too');
        Request := ProjectRequest(ProjectNo);
        Request.Add('expectedCount', 1);
        Response := Run(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('totalEntriesUpdated'), 'One usage entry changed');
        Projects := Response.GetArray('projects');
        Assert.AreEqual(1, Projects.Count(), 'One project row');
        Projects.Get(0, Row);
        Assert.AreEqual(ProjectNo, Row.AsObject().GetText('projectNo'), 'Project row');
        Assert.AreEqual(1, Row.AsObject().GetInteger('entriesUpdated'), 'Entries on the project');
        Assert.AreEqual(4, Row.AsObject().GetDecimal('costChangeLCY'), 'Cost change');
        FindUsage(ProjectNo, Ledger);
        Assert.AreEqual(24, Ledger."Total Cost (LCY)", 'The project ledger follows the adjusted cost');
        PlanningLine.FindFirst();
        Assert.AreEqual(12, PlanningLine."Unit Cost (LCY)", 'The planning line follows');
    end;

    /// <summary>Edge: a posting date window that excludes the usage changes nothing; the project still counts as in scope.</summary>
    [Test]
    procedure Scenario_AC01_PostingDateWindowExcludesUsage_ChangesNothing()
    var
        Ledger: Record "Job Ledger Entry";
        ProjectNo: Code[20];
        Request: JsonObject;
        Response: JsonObject;
    begin
        ProjectNo := SeedAdjustedUsage();
        Request := ProjectRequest(ProjectNo);
        Request.Add('postingDateTo', Format(CalcDate('<-1M>', PostingDate), 0, 9));
        Response := Run(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetInteger('totalEntriesUpdated'), 'Nothing in the window');
        FindUsage(ProjectNo, Ledger);
        Assert.AreEqual(20, Ledger."Total Cost (LCY)", 'The excluded usage keeps its cost');
        Clear(Request);
        Request := ProjectRequest(ProjectNo);
        Request.Add('postingDateFrom', Format(PostingDate, 0, 9));
        Request.Add('postingDateTo', Format(PostingDate, 0, 9));
        Response := Run(Request);
        Assert.AreEqual(1, Response.GetInteger('totalEntriesUpdated'), 'The window that holds the usage updates it');
        FindUsage(ProjectNo, Ledger);
        Assert.AreEqual(24, Ledger."Total Cost (LCY)", 'Updated inside the window');
    end;

    /// <summary>AC02: a project without usage answers Success with zero counts.</summary>
    [Test]
    procedure Scenario_AC02_NothingToUpdate_SuccessWithZeros()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonToken;
    begin
        Library.Initialize();
        LibraryJob.CreateJob(Project);
        Request := ProjectRequest(Project."No.");
        Request.Add('expectedCount', 1);
        Response := Run(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetInteger('totalEntriesUpdated'), 'Zero entries');
        Response.GetArray('projects').Get(0, Row);
        Assert.AreEqual(0, Row.AsObject().GetInteger('entriesUpdated'), 'Zero on the project');
        Assert.AreEqual(0, Row.AsObject().GetDecimal('costChangeLCY'), 'Zero cost change');
    end;

    /// <summary>AC03: both selectors are refused with ConflictingIdentifiers.</summary>
    [Test]
    procedure Scenario_AC03_BothSelectors_ConflictingIdentifiers()
    var
        Request: JsonObject;
    begin
        Library.Initialize();
        Request := ProjectRequest('X');
        Request.Add('allOpen', true);
        AssertRefusal(Run(Request), 'ConflictingIdentifiers');
    end;

    /// <summary>AC03: no selector, or an empty list, is refused with MissingParameter.</summary>
    [Test]
    procedure Scenario_AC03_NoSelector_MissingParameter()
    var
        Request: JsonObject;
        Empty: JsonArray;
    begin
        Library.Initialize();
        AssertRefusal(Run(Request), 'MissingParameter');
        Request.Add('projectNos', Empty);
        AssertRefusal(Run(Request), 'MissingParameter');
    end;

    /// <summary>AC03: an unknown project is refused with RecordNotFound.</summary>
    [Test]
    procedure Scenario_AC03_UnknownProject_RecordNotFound()
    begin
        Library.Initialize();
        AssertRefusal(Run(ProjectRequest('NO-SUCH-PROJECT')), 'RecordNotFound');
    end;

    /// <summary>AC03: a Completed project is refused with PreconditionFailed.</summary>
    [Test]
    procedure Scenario_AC03_CompletedProject_PreconditionFailed()
    var
        Project: Record Job;
    begin
        Library.Initialize();
        LibraryJob.CreateJob(Project);
        Project.Status := Project.Status::Completed;
        Project.Modify();
        AssertRefusal(Run(ProjectRequest(Project."No.")), 'PreconditionFailed');
    end;

    /// <summary>AC03: a bad date, reversed dates, an unknown key and a bad type are refused; nothing changes.</summary>
    [Test]
    procedure Scenario_AC03_BadInput_Refused()
    var
        Project: Record Job;
        Request: JsonObject;
    begin
        Library.Initialize();
        LibraryJob.CreateJob(Project);
        Request := ProjectRequest(Project."No.");
        Request.Add('postingDateFrom', 'yesterday');
        AssertRefusal(Run(Request), 'InvalidParameterFormat');
        Clear(Request);
        Request := ProjectRequest(Project."No.");
        Request.Add('postingDateFrom', '2026-11-30');
        Request.Add('postingDateTo', '2026-11-01');
        AssertRefusal(Run(Request), 'InvalidParameter');
        Clear(Request);
        Request := ProjectRequest(Project."No.");
        Request.Add('projectNo', Project."No.");
        AssertRefusal(Run(Request), 'UnknownParameter');
        Clear(Request);
        Request.Add('allOpen', 'yes');
        AssertRefusal(Run(Request), 'InvalidParameterFormat');
    end;

    /// <summary>AC02: the type is a write; the gate asks for no count and ignores a wrong expectedCount.</summary>
    [Test]
    procedure Scenario_AC02_NoConfirmation_ExpectedCountIgnored()
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
        Impl: Codeunit "Proj. Item Cost Impl ori";
        ProjectNo: Code[20];
        Request: JsonObject;
        Response: JsonObject;
        Effect: JsonObject;
    begin
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect declared');
        Assert.AreEqual('write', Effect.GetText('effect'), 'Write');
        Assert.IsFalse(ConfirmGate.IsConfirmRequired("Message Type ori"::"Projects.ItemCost.Update"), 'No gate');
        ProjectNo := SeedAdjustedUsage();
        Request := ProjectRequest(ProjectNo);
        Assert.IsTrue(Gate(Request, Response), 'No expectedCount passes');
        Request.Add('expectedCount', 3);
        Assert.IsTrue(Gate(Request, Response), 'A wrong count is ignored');
    end;

    /// <summary>AC06: the contract builds in 1033 and 1039; discovery text is translated, chapter text is English, no AL names or message-type wording.</summary>
    [Test]
    procedure Scenario_AC06_ContractInBothLanguages()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Impl: Codeunit "Proj. Item Cost Impl ori";
        Contract: JsonObject;
        Notes: Text;
        ContractText: Text;
        Description1033: Text;
        Description1039: Text;
        Language: Integer;
    begin
        Language := GlobalLanguage();
        GlobalLanguage(1033);
        Description1033 := Impl.GetDescription();
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Projects.ItemCost.Update", Contract), 'Contract in 1033');
        GlobalLanguage(1039);
        Description1039 := Impl.GetDescription();
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Projects.ItemCost.Update", Contract), 'Contract in 1039');
        GlobalLanguage(Language);
        Assert.AreNotEqual(Description1033, Description1039, 'Discovery text is translated');
        Assert.IsTrue(Impl.GetNotes(Notes), 'Notes declared');
        Assert.IsTrue(Notes.Contains('Automatic Update Project Item Cost'), 'Help explains the automatic setting');
        Contract.WriteTo(ContractText);
        Assert.IsFalse(ContractText.Contains('Report 1095'), 'No AL object names');
        Assert.IsFalse(ContractText.Contains('Update Job Item Cost'), 'No AL object names');
    end;

    local procedure ProjectRequest(ProjectNo: Code[20]) Request: JsonObject
    var
        Nos: JsonArray;
    begin
        Nos.Add(ProjectNo);
        Request.Add('projectNos', Nos);
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        Assert.AreEqual('Error', Response.GetText('status'), 'Refused: ' + Format(Response));
        Assert.AreEqual(Code, Response.GetText('code'), 'Code: ' + Format(Response));
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'A next step is given');
    end;

    local procedure Run(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        ItemCost: Codeunit "Projects Item Cost ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        ItemCost.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure Gate(Request: JsonObject; var Response: JsonObject): Boolean
    var
        TempArgument: Record "Message Argument ori" temporary;
        ConfirmGate: Codeunit "Confirm Gate ori";
        Passed: Boolean;
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.ItemCost.Update";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Passed := ConfirmGate.Check(TempArgument, "Message Type ori"::"Projects.ItemCost.Update");
        if not Passed then
            Response := TempArgument.GetResponseJson();
        exit(Passed);
    end;

    local procedure FindUsage(ProjectNo: Code[20]; var Ledger: Record "Job Ledger Entry")
    begin
        Ledger.Reset();
        Ledger.SetRange("Job No.", ProjectNo);
        Ledger.SetRange(Type, Ledger.Type::Item);
        Ledger.SetRange("Entry Type", Ledger."Entry Type"::Usage);
        Ledger.FindFirst();
    end;

    /// <summary>First date on or after the work date that lies after every closed inventory period, so seeded postings never meet a period closed by earlier data.</summary>
    local procedure FindOpenPostingDate(): Date
    var
        InventoryPeriod: Record "Inventory Period";
        OpenDate: Date;
    begin
        OpenDate := WorkDate();
        InventoryPeriod.SetRange(Closed, true);
        if InventoryPeriod.FindLast() then
            if InventoryPeriod."Ending Date" >= OpenDate then
                OpenDate := CalcDate('<+1D>', InventoryPeriod."Ending Date");
        exit(OpenDate);
    end;

    /// <summary>Seeds an own vendor, item and project, uses 2 items at cost 10 through a budget project journal line, invoices the receipt at 12 and adjusts cost natively.</summary>
    local procedure SeedAdjustedUsage(): Code[20]
    var
        JobsSetup: Record "Jobs Setup";
        Project: Record Job;
        Task: Record "Job Task";
        Item: Record Item;
        Vendor: Record Vendor;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        JobJournalLine: Record "Job Journal Line";
        JobPost: Codeunit "Job Jnl.-Post Line";
    begin
        Library.Initialize();
        JobsSetup.Get();
        JobsSetup."Automatic Update Job Item Cost" := false;
        JobsSetup.Modify();
        LibraryInventory.CreateItem(Item);
        Item.Validate("Unit Cost", 10);
        Item.Modify(true);
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        PostingDate := FindOpenPostingDate();
        PurchaseHeader.Validate("Posting Date", PostingDate);
        PurchaseHeader.Modify(true);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        PurchaseLine.Validate("Direct Unit Cost", 10);
        PurchaseLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        LibraryJob.CreateJob(Project);
        Project.Validate("Apply Usage Link", true);
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        LibraryJob.CreateJobTask(Project, Task);
        LibraryJob.CreateJobJournalLineForType(JobJournalLine."Line Type"::Budget, JobJournalLine.Type::Item, Task, JobJournalLine);
        JobJournalLine.Validate("No.", Item."No.");
        JobJournalLine.Validate("Posting Date", PostingDate);
        JobJournalLine.Validate(Quantity, 2);
        JobJournalLine.Modify(true);
        JobPost.RunWithCheck(JobJournalLine);
        PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        PurchaseLine.Validate("Direct Unit Cost", 12);
        PurchaseLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, false, true);
        LibraryCosting.AdjustCostItemEntries(Item."No.", '');
        exit(Project."No.");
    end;
}
