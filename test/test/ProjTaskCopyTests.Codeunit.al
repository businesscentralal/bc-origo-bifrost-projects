namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue 79: native copying, atomic refusals, confirmation and bilingual contracts.</summary>
codeunit 97175 "Proj. Task Copy Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";
        Fixture: Codeunit "Proj. Task Copy Fixture ori";

    /// <summary>AC01: inclusive range and defaults append without changing existing tasks.</summary>
    [Test]
    procedure AC01_DefaultOptionsAndInclusiveRange()
    var
        Manifest: JsonObject;
        Response: JsonObject;
        Task: Record "Job Task";
        Line: Record "Job Planning Line";
        TaskDimension: Record "Job Task Dimension";
    begin
        Manifest := Fixture.Seed();
        Response := Execute(Fixture.Request(Manifest));
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('copiedTasks').Count(), 'Both range boundaries copied');
        Assert.AreEqual('1000', Response.GetArray('copiedTasks').GetObject(0).GetText('taskNo'), 'Stable ordering');
        Assert.AreEqual('1999', Response.GetArray('copiedTasks').GetObject(1).GetText('taskNo'), 'Inclusive upper boundary');
        Assert.AreEqual(2, Response.GetInteger('copiedPlanningLines'), 'Budget and Billable lines copied');
        Assert.AreEqual(2, Response.GetArray('copiedTasks').GetObject(0).GetInteger('planningLines'), 'Per-task line count');
        Assert.AreEqual(0, Response.GetArray('copiedTasks').GetObject(1).GetInteger('planningLines'), 'Empty task included');
        Assert.IsFalse(Task.Get(Manifest.GetText('targetProjectNo'), '2000'), 'Outside range excluded');
        Task.Get(Manifest.GetText('targetProjectNo'), 'XKEEP');
        Assert.AreEqual('X Task copy test', Task.Description, 'Existing task preserved');
        Task.Get(Manifest.GetText('sourceProjectNo'), '1000');
        Line.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Assert.IsTrue(Line.FindFirst(), 'Native lines exist');
        Assert.AreEqual(3, Line.Quantity, 'Quantity copied by default');
        Assert.AreEqual(11, Line."Unit Price", 'Prices copied by default');
        Assert.IsTrue(TaskDimension.Get(Manifest.GetText('targetProjectNo'), '1000', Manifest.GetText('dimensionCode')), 'Task dimension copied');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC01: native options omit quantities, prices and task dimensions.</summary>
    [Test]
    procedure AC01_DisabledOptionsBudgetFilter()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Line: Record "Job Planning Line";
        TaskDimension: Record "Job Task Dimension";
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Add('copyQuantity', false);
        Request.Add('copyPrices', false);
        Request.Add('copyDimensions', false);
        Request.Add('planningLineType', 'Budget');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('copiedPlanningLines'), 'Only Budget copied');
        Line.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Line.FindFirst();
        Assert.AreEqual(Line."Line Type"::Budget, Line."Line Type", 'Native line type');
        Assert.AreEqual(0, Line.Quantity, 'Quantity cleared');
        Assert.AreEqual(0, Line."Unit Price", 'Price cleared');
        Assert.IsFalse(TaskDimension.Get(Manifest.GetText('targetProjectNo'), '1000', Manifest.GetText('dimensionCode')), 'Dimension not copied');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC01: Billable filter chooses only billable planning lines.</summary>
    [Test]
    procedure AC01_BillableFilter()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Line: Record "Job Planning Line";
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Add('planningLineType', 'Billable');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('copiedPlanningLines'), 'Billable filter count');
        Line.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Line.FindFirst();
        Assert.AreEqual(Line."Line Type"::Billable, Line."Line Type", 'Billable line type');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC02: Usage entries become native Budget planning lines; Sale entries are excluded.</summary>
    [Test]
    procedure AC02_LedgerUsageConversion()
    begin
        CheckLedger(false);
    end;

    /// <summary>AC02 edge: Sale entries become Billable planning lines with native quantity reversal.</summary>
    [Test]
    procedure AC02_LedgerSaleConversion()
    begin
        CheckLedger(true);
    end;

    local procedure CheckLedger(Sale: Boolean)
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Line: Record "Job Planning Line";
    begin
        Manifest := Fixture.Seed();
        Fixture.SeedLedger(Manifest, false);
        Fixture.SeedLedger(Manifest, true);
        Request := Fixture.Request(Manifest);
        Request.Add('source', 'ledgerEntries');
        if Sale then
            Request.Add('ledgerEntryType', 'Sale')
        else
            Request.Add('ledgerEntryType', 'Usage');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('copiedPlanningLines'), 'Only requested ledger entry type converted; original planning lines not copied');
        Line.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Line.FindFirst();
        Assert.AreEqual(3, Line.Quantity, 'Native ledger conversion quantity');
        Assert.AreEqual(Manifest.GetText('resourceNo'), Line."No.", 'Self-seeded resource converted');
        if Sale then
            Assert.AreEqual(Line."Line Type"::Billable, Line."Line Type", 'Sale becomes Billable')
        else
            Assert.AreEqual(Line."Line Type"::Budget, Line."Line Type", 'Usage becomes Budget');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC03: all colliding task numbers are named and no earlier task is copied.</summary>
    [Test]
    procedure AC03_CollisionsRefuseWholeRange()
    var
        Manifest: JsonObject;
        Response: JsonObject;
        Task: Record "Job Task";
    begin
        Manifest := Fixture.Seed();
        Fixture.AddTask(CopyStr(Manifest.GetText('targetProjectNo'), 1, 20), '1999');
        Response := Execute(Fixture.Request(Manifest));
        AssertCode(Response, 'ConflictingIdentifiers');
        Assert.IsTrue(Format(Response).Contains('1999'), 'Collision named');
        Assert.IsFalse(Task.Get(Manifest.GetText('targetProjectNo'), '1000'), 'No partial copy before collision');
        Fixture.AddTask(CopyStr(Manifest.GetText('targetProjectNo'), 1, 20), '1000');
        Response := Execute(Fixture.Request(Manifest));
        Assert.IsTrue(Format(Response).Contains('1000'), 'First collision named');
        Assert.IsTrue(Format(Response).Contains('1999'), 'Second collision named');
        AssertNoLines(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: same source and target is a conflict even with differently cased identifiers.</summary>
    [Test]
    procedure AC04_SameProjectConflict()
    var
        Manifest: JsonObject;
        Request: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Replace('targetProjectNo', LowerCase(Manifest.GetText('sourceProjectNo')));
        AssertCode(Execute(Request), 'ConflictingIdentifiers');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: completed and fully blocked targets refuse without changes.</summary>
    [Test]
    procedure AC04_TargetStateRefusals()
    var
        Manifest: JsonObject;
        Project: Record Job;
    begin
        Manifest := Fixture.Seed();
        Project.Get(Manifest.GetText('targetProjectNo'));
        Project.Status := Project.Status::Completed;
        Project.Modify(false);
        AssertCode(Execute(Fixture.Request(Manifest)), 'PreconditionFailed');
        Project.Status := Project.Status::Open;
        Project.Blocked := Project.Blocked::All;
        Project.Modify(false);
        AssertCode(Execute(Fixture.Request(Manifest)), 'PreconditionFailed');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: unknown projects are refused with actionable stable errors.</summary>
    [Test]
    procedure AC04_UnknownProjects()
    var
        Manifest: JsonObject;
        Request: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Replace('sourceProjectNo', 'XUNKNOWN79');
        AssertCode(Execute(Request), 'RecordNotFound');
        Request := Fixture.Request(Manifest);
        Request.Replace('targetProjectNo', 'XUNKNOWN79');
        AssertCode(Execute(Request), 'RecordNotFound');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: malformed options, ranges and scalar types never enter native copying.</summary>
    [Test]
    procedure AC04_InvalidOptionsAndRange()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        ParameterName: Text;
        Names: List of [Text];
    begin
        Manifest := Fixture.Seed();
        Names.Add('source');
        Names.Add('planningLineType');
        Names.Add('ledgerEntryType');
        Names.Add('copyPrices');
        Names.Add('copyQuantity');
        Names.Add('copyDimensions');
        foreach ParameterName in Names do begin
            Request := Fixture.Request(Manifest);
            Request.Add(ParameterName, 'bad');
            AssertCode(Execute(Request), 'InvalidParameterFormat');
        end;
        Request := Fixture.Request(Manifest);
        Request.Replace('fromTaskNo', '2000');
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request := Fixture.Request(Manifest);
        Request.Add('ledgerEntryType', 'Usage');
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request := Fixture.Request(Manifest);
        Request.Replace('expectedCount', -1);
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request.Replace('expectedCount', 1.5);
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request.Replace('expectedCount', '2');
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        Request := Fixture.Request(Manifest);
        Request.Replace('sourceProjectNo', 'X12345678901234567890');
        AssertCode(Execute(Request), 'InvalidParameterFormat');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: missing and unknown keys use distinct refusal codes.</summary>
    [Test]
    procedure AC04_MissingAndUnknownKeys()
    var
        Manifest: JsonObject;
        Request: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Remove('sourceProjectNo');
        AssertCode(Execute(Request), 'MissingParameter');
        Request := Fixture.Request(Manifest);
        Request.Remove('targetProjectNo');
        AssertCode(Execute(Request), 'MissingParameter');
        Request := Fixture.Request(Manifest);
        Request.Add('unknown', true);
        AssertCode(Execute(Request), 'UnknownParameter');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC02: a write type asks for no confirmation; expectedCount is accepted and ignored.</summary>
    [Test]
    procedure AC02_ExpectedCountIgnored_NoConfirmation()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Replace('expectedCount', 7);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('copiedTasks').Count(), 'The copy runs whatever expectedCount says');
        Fixture.Cleanup(Manifest);
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Remove('expectedCount');
        Library.AssertStatus(Execute(Request), 'Success');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC05 edge: empty inclusive ranges can be confirmed with zero.</summary>
    [Test]
    procedure AC05_EmptyRange()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Replace('fromTaskNo', '3000');
        Request.Replace('toTaskNo', '3999');
        Request.Replace('expectedCount', 0);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('copiedTasks').Count(), 'Empty range result');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC01 edge: omitted bounds copy every source task.</summary>
    [Test]
    procedure AC01_UnboundedRange()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := Fixture.Request(Manifest);
        Request.Remove('fromTaskNo');
        Request.Remove('toTaskNo');
        Request.Replace('expectedCount', 3);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(3, Response.GetArray('copiedTasks').Count(), 'All source tasks copied');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: a native error after copying the first task rolls back the whole batch.</summary>
    [Test]
    procedure AC04_NativeFailureRollsBackEarlierTask()
    var
        Manifest: JsonObject;
        Line: Record "Job Planning Line";
    begin
        Manifest := Fixture.Seed();
        Line.Get(Manifest.GetText('sourceProjectNo'), '1000', 10000);
        Line."Job Task No." := '1999';
        Line."Line No." := 30000;
        Line."No." := 'XMISSING79';
        Line.Insert(false);
        AssertCode(Execute(Fixture.Request(Manifest)), 'PreconditionFailed');
        AssertTargetUnchanged(Manifest);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC07: discovery is localized while help chapters stay English.</summary>
    [Test]
    procedure AC07_BilingualDiscoveryAndHelp()
    var
        Impl: Codeunit "Proj. Task Copy Impl ori";
        CopyProject: Codeunit "Proj. Copy Impl ori";
        OriginalLanguage: Integer;
        English: Text;
        Icelandic: Text;
        Overview: Text;
        Notes: Text;
        Effect: JsonObject;
        Parameters: JsonArray;
        EnglishParameters: Text;
        IcelandicParameters: Text;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := Impl.GetDescription();
        Impl.GetOverview(Overview);
        Impl.GetNotes(Notes);
        Impl.GetParameters(Parameters);
        Parameters.WriteTo(EnglishParameters);
        GlobalLanguage(1039);
        Assert.AreNotEqual(English, Impl.GetDescription(), 'Translated discovery');
        Impl.GetOverview(Icelandic);
        Assert.AreEqual(Overview, Icelandic, 'English overview');
        Impl.GetNotes(Icelandic);
        Assert.AreEqual(Notes, Icelandic, 'English notes');
        Clear(Parameters);
        Impl.GetParameters(Parameters);
        Parameters.WriteTo(IcelandicParameters);
        Assert.AreEqual(EnglishParameters, IcelandicParameters, 'English parameter chapter');
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', Effect.GetText('effect'), 'Effect classification');
        CopyProject.GetOverview(Overview);
        Assert.IsTrue(Overview.Contains('Projects.Task.CopyFrom'), 'New-target help names existing-target alternative');
        GlobalLanguage(OriginalLanguage);
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    begin
        exit(Library.ExecuteNative("Message Type ori"::"Projects.Task.CopyFrom", Request));
    end;

    local procedure AssertCode(Response: JsonObject; Code: Text)
    begin
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(Code, Response.GetText('code'), Format(Response));
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
    end;

    local procedure AssertNoLines(Manifest: JsonObject)
    var
        Line: Record "Job Planning Line";
    begin
        Line.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Assert.IsTrue(Line.IsEmpty(), 'No partial planning lines');
    end;

    local procedure AssertTargetUnchanged(Manifest: JsonObject)
    var
        Task: Record "Job Task";
    begin
        Task.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Assert.AreEqual(1, Task.Count(), 'Only pre-existing target task');
        AssertNoLines(Manifest);
    end;
}
