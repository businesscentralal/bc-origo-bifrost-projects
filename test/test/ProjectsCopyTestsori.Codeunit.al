namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;
using Microsoft.Finance.Dimension;

/// <summary>Issue #3 copy component tests use native Copy Job with isolated source and target records.</summary>
codeunit 97104 "Projects Copy Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_CopyTaskRange_CreatesOnlySelectedTasks()
    var
        TargetProject: Record Job;
        Task: Record "Job Task";
        SourceRequest: JsonObject;
        TaskRequest: JsonObject;
        Tasks: JsonArray;
        CopyRequest: JsonObject;
        Response: JsonObject;
        TargetNo: Code[20];
    begin
        // Story #3, AC01 | Time: native Today creation fields only | Risk: None
        SourceRequest := Library.NewProjectRequest();
        TaskRequest.Add('taskNo', 'X100');
        TaskRequest.Add('description', 'X First task');
        Tasks.Add(TaskRequest);
        Clear(TaskRequest);
        TaskRequest.Add('taskNo', 'X200');
        TaskRequest.Add('description', 'X Selected task');
        Tasks.Add(TaskRequest);
        SourceRequest.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", SourceRequest), 'Success');
        TargetNo := NewTargetNo();
        CopyRequest.Add('projectNo', SourceRequest.GetText('projectNo'));
        CopyRequest.Add('targetProjectNo', TargetNo);
        CopyRequest.Add('fromTaskNo', 'X200');
        CopyRequest.Add('toTaskNo', 'X200');
        CopyRequest.Add('copyDimensions', false);
        CopyRequest.Add('copyPrices', false);
        CopyRequest.Add('copyQuantity', false);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(TargetNo, Response.GetText('projectNo'), 'Success must name the new project');
        TargetProject.Get(TargetNo);
        Assert.AreEqual(TargetProject.Status::Planning, TargetProject.Status, 'Copy Job must apply native target status');
        Assert.IsTrue(Task.Get(TargetNo, 'X200'), 'Selected task must be copied');
        Assert.IsFalse(Task.Get(TargetNo, 'X100'), 'Excluded task must not be copied');
        Assert.IsTrue(Task.Get(SourceRequest.GetText('projectNo'), 'X100'), 'Source task must remain');
    end;

    [Test]
    procedure Scenario_AC01_DefaultCopy_PreservesDescriptionAndCustomer()
    var
        TargetProject: Record Job;
        SourceRequest: JsonObject;
        CopyRequest: JsonObject;
        TargetNo: Code[20];
    begin
        // Story #3, AC01 | Time: no date dependency | Risk: None
        SourceRequest := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", SourceRequest), 'Success');
        TargetNo := NewTargetNo();
        CopyRequest.Add('projectNo', SourceRequest.GetText('projectNo'));
        CopyRequest.Add('targetProjectNo', TargetNo);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest), 'Success');
        TargetProject.Get(TargetNo);
        Assert.AreEqual(SourceRequest.GetText('description'), TargetProject.Description, 'Omitted description must preserve source');
        Assert.AreEqual(SourceRequest.GetText('billToCustomerNo'), TargetProject."Bill-to Customer No.", 'Native copy must preserve customer');
    end;

    [Test]
    procedure Scenario_AC01_ExistingTarget_ReturnsNativeError()
    var
        Project: Record Job;
        SourceRequest: JsonObject;
        CopyRequest: JsonObject;
        Response: JsonObject;
    begin
        // Story #3, AC01 | Time: no date dependency | Risk: None
        SourceRequest := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", SourceRequest), 'Success');
        CopyRequest.Add('projectNo', SourceRequest.GetText('projectNo'));
        CopyRequest.Add('targetProjectNo', SourceRequest.GetText('projectNo'));
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Native duplicate must surface');
        Project.Get(SourceRequest.GetText('projectNo'));
        Assert.AreEqual(SourceRequest.GetText('description'), Project.Description, 'Source must survive failed copy');
    end;

    [Test]
    procedure Scenario_AC01_BadBooleanAndTarget_CollectBothErrors()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #3, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Request.Add('copyQuantity', 'false');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('MultipleErrors', Response.GetText('code'), 'Missing target and string Boolean must be collected');
        Assert.AreEqual(2, Response.GetArray('errors').Count(), 'Both malformed parameters must be reported');
    end;

    [Test]
    procedure Scenario_AC01_MissingSource_DoesNotCreateTarget()
    var
        Target: Record Job;
        Request: JsonObject;
        TargetNo: Code[20];
    begin
        // Story #3, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        TargetNo := NewTargetNo();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Request.Add('targetProjectNo', TargetNo);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", Request), 'Error');
        Assert.IsFalse(Target.Get(TargetNo), 'A missing source must not leave a target');
    end;

    local procedure NewTargetNo(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;
    [Test]
    [HandlerFunctions('DimensionConfirmHandler')]
    procedure Scenario_AC01_CopyPlanOptions_FiltersQuantityAndDimensions()
    var
        PlanningLine: Record "Job Planning Line";
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        DefaultDimension: Record "Default Dimension";
        PlanRequest: JsonObject;
        CopyRequest: JsonObject;
        TargetNo: Code[20];
        DimensionCode: Code[20];
    begin
        // Story #3, AC01 | Time: fixed2026-10-16 planning date | Risk: all business fixtures/dimensions self-created; no ledger posts
        PlanRequest := Library.NewPlanningRequest('Resource');
        PlanRequest.Replace('lineType', 'Budget');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanRequest), 'Success');
        PlanRequest.Replace('lineNo', 20000);
        PlanRequest.Replace('lineType', 'Billable');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanRequest), 'Success');
        DimensionCode := NewTargetNo();
        Dimension.Init();
        Dimension.Code := DimensionCode;
        Dimension.Name := 'X Projects copy dimension';
        Dimension.Insert(true);
        DimensionValue.Init();
        DimensionValue."Dimension Code" := DimensionCode;
        DimensionValue.Code := 'XVALUE';
        DimensionValue.Name := 'X Projects copy value';
        DimensionValue.Insert(true);
        DefaultDimension.Init();
        DefaultDimension."Table ID" := Database::Job;
        DefaultDimension."No." := CopyStr(PlanRequest.GetText('projectNo'), 1, 20);
        DefaultDimension."Dimension Code" := DimensionCode;
        DefaultDimension."Dimension Value Code" := DimensionValue.Code;
        DefaultDimension.Insert(true);
        TargetNo := NewTargetNo();
        CopyRequest.Add('projectNo', PlanRequest.GetText('projectNo'));
        CopyRequest.Add('targetProjectNo', TargetNo);
        CopyRequest.Add('planningLineType', 'Budget');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest), 'Success');
        PlanningLine.SetRange("Job No.", TargetNo);
        Assert.AreEqual(1, PlanningLine.Count(), 'Budget filter must exclude billable planning lines');
        PlanningLine.FindFirst();
        Assert.AreEqual(PlanningLine."Line Type"::Budget, PlanningLine."Line Type", 'Budget line must be copied');
        Assert.AreEqual(3, PlanningLine.Quantity, 'Default quantity option must copy quantity');
        Assert.AreEqual(11, PlanningLine."Unit Price", 'Default price option must copy source price');
        Assert.IsTrue(DefaultDimension.Get(Database::Job, TargetNo, DimensionCode), 'Default dimensions option must copy the owned dimension');
        TargetNo := NewTargetNo();
        CopyRequest.Replace('targetProjectNo', TargetNo);
        CopyRequest.Replace('planningLineType', 'Billable');
        CopyRequest.Add('copyQuantity', false);
        CopyRequest.Add('copyDimensions', false);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest), 'Success');
        PlanningLine.SetRange("Job No.", TargetNo);
        Assert.AreEqual(1, PlanningLine.Count(), 'Billable filter must exclude budget planning lines');
        PlanningLine.FindFirst();
        Assert.AreEqual(PlanningLine."Line Type"::Billable, PlanningLine."Line Type", 'Billable line must be copied');
        Assert.AreEqual(0, PlanningLine.Quantity, 'Disabled quantity option must clear copied quantity');
        Assert.IsFalse(DefaultDimension.Get(Database::Job, TargetNo, DimensionCode), 'Disabled dimensions option must not copy the owned dimension');
    end;

    [ConfirmHandler]
    procedure DimensionConfirmHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.IsTrue(StrPos(LowerCase(Question), 'dimension') > 0, 'Only the native owned-dimension update confirmation is expected');
        Reply := true;
    end;

}
