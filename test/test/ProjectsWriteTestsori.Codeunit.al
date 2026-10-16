namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Issue #2 native component acceptance, strict validation and atomic failure tests. Shipping queue licensing remains separate.</summary>
codeunit 97101 "Projects Write Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_CreateProject_NativeFieldsPersist()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: Today sets native creation date | Risk: None
        Request := Library.NewProjectRequest();
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request);
        Library.AssertStatus(Response, 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Request.GetText('billToCustomerNo'), Project."Bill-to Customer No.", 'Customer must validate');
        Assert.AreEqual(Today(), Project."Creation Date", 'Native OnInsert must run');
        Assert.AreEqual('X Projects unit test', Project.Description, 'Description must persist');
    end;

    [Test]
    procedure Scenario_AC01_UpdateProject_PreservesOmittedFields()
    var
        Project: Record Job;
        Request: JsonObject;
        UpdateRequest: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: Today for native modification date | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        UpdateRequest.Add('projectNo', Request.GetText('projectNo'));
        UpdateRequest.Add('description', 'X Changed');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Update", UpdateRequest);
        Library.AssertStatus(Response, 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual('X Changed', Project.Description, 'Description must change');
        Assert.AreEqual(Request.GetText('billToCustomerNo'), Project."Bill-to Customer No.", 'Omitted customer must stay');
    end;

    [Test]
    procedure Scenario_AC01_NestedTasksAndTextLine_AllCreated()
    var
        Task: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        Request: JsonObject;
        TaskRequest: JsonObject;
        PlanRequest: JsonObject;
        Tasks: JsonArray;
        PlanningLines: JsonArray;
    begin
        // Story #2, AC01 | Time: no planning date for text line | Risk: None
        Request := Library.NewProjectRequest();
        PlanRequest.Add('lineNo', 10000);
        PlanRequest.Add('type', 'Text');
        PlanRequest.Add('description', 'X Nested line');
        PlanningLines.Add(PlanRequest);
        TaskRequest.Add('taskNo', 'X100');
        TaskRequest.Add('description', 'X Task');
        TaskRequest.Add('planningLines', PlanningLines);
        Tasks.Add(TaskRequest);
        Request.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        Task.Get(Request.GetText('projectNo'), 'X100');
        PlanningLine.Get(Task."Job No.", Task."Job Task No.", 10000);
        Assert.AreEqual('X Nested line', PlanningLine.Description, 'Nested planning line missing');
        Assert.AreEqual(PlanningLine.Type::Text, PlanningLine.Type, 'Native enum must be set');
    end;

    [Test]
    procedure Scenario_AC01_TaskCreateAndUpdate_PersistTotals()
    var
        Task: Record "Job Task";
        Request: JsonObject;
        TaskRequest: JsonObject;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        TaskRequest.Add('projectNo', Request.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'XTOTAL');
        TaskRequest.Add('taskType', 'Total');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        TaskRequest.Add('totaling', 'X100..X900');
        TaskRequest.Add('indentation', 2);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Update", TaskRequest), 'Success');
        Task.Get(Request.GetText('projectNo'), 'XTOTAL');
        Assert.AreEqual(Task."Job Task Type"::Total, Task."Job Task Type", 'Task type must validate');
        Assert.AreEqual('X100..X900', Task.Totaling, 'Totaling must persist');
        Assert.AreEqual(2, Task.Indentation, 'Indentation must persist');
    end;

    [Test]
    procedure Scenario_AC01_PlanCreateUpdateDelete_RunNativeTriggers()
    var
        PlanningLine: Record "Job Planning Line";
        Request: JsonObject;
        TaskRequest: JsonObject;
        PlanRequest: JsonObject;
    begin
        // Story #2, AC01 | Time: no planning date for text line | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        TaskRequest.Add('projectNo', Request.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'X100');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        PlanRequest.Add('projectNo', Request.GetText('projectNo'));
        PlanRequest.Add('taskNo', 'X100');
        PlanRequest.Add('lineNo', 10000);
        PlanRequest.Add('type', 'Text');
        PlanRequest.Add('description', 'X Original');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanRequest), 'Success');
        PlanRequest.Replace('description', 'X Changed');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Update", PlanRequest), 'Success');
        PlanningLine.Get(Request.GetText('projectNo'), 'X100', 10000);
        Assert.AreEqual('X Changed', PlanningLine.Description, 'Planning line update missing');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Delete", PlanRequest), 'Success');
        Assert.IsFalse(PlanningLine.Get(Request.GetText('projectNo'), 'X100', 10000), 'Native deletion missing');
    end;

    [Test]
    procedure Scenario_AC01_BadNativeCustomer_ReturnsBCError()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        Request.Replace('billToCustomerNo', 'X-NO-SUCH-CUSTOMER');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'BC field validation must surface through the contract');
        Assert.IsFalse(Project.Get(Request.GetText('projectNo')), 'Failed validation must not insert a project');
    end;

    [Test]
    procedure Scenario_AC01_DuplicateNestedTask_RollsBackProject()
    var
        Project: Record Job;
        Task: Record "Job Task";
        Request: JsonObject;
        TaskRequest: JsonObject;
        Tasks: JsonArray;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        TaskRequest.Add('taskNo', 'XDUP');
        Tasks.Add(TaskRequest);
        Tasks.Add(TaskRequest);
        Request.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Error');
        Assert.IsFalse(Project.Get(Request.GetText('projectNo')), 'Parent must roll back after second nested task fails');
        Assert.IsFalse(Task.Get(Request.GetText('projectNo'), 'XDUP'), 'First nested task must roll back too');
    end;

    [Test]
    procedure Scenario_AC01_WrongShapeAndMissingKeys_CollectAll()
    var
        Request: JsonObject;
        Response: JsonObject;
        Errors: JsonArray;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('quantity', true);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('MultipleErrors', Response.GetText('code'), 'Several missing identifiers and bad quantity must be collected');
        Errors := Response.GetArray('errors');
        Assert.AreEqual(4, Errors.Count(), 'projectNo, taskNo, lineNo and quantity errors must all be present');
    end;

    [Test]
    procedure Scenario_AC01_OverlongIdentifier_NoTruncationOrWrite()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        Request.Replace('projectNo', 'X12345678901234567890');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Identifier over 20 chars must not be silently truncated');
    end;

    [Test]
    procedure Scenario_AC01_ExactLengthIdentifier_Accepted()
    var
        Project: Record Job;
        Request: JsonObject;
    begin
        // Story #2, AC01 | Time: native Today fields only | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(20, StrLen(Project."No."), 'Exact boundary fixture must remain 20 characters');
    end;

    [Test]
    procedure Scenario_AC01_InvalidNestedShape_NoPartialWrites()
    var
        Project: Record Job;
        Request: JsonObject;
        Tasks: JsonArray;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        Tasks.Add(false);
        Request.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Error');
        Assert.IsFalse(Project.Get(Request.GetText('projectNo')), 'Shape validation must precede parent insertion');
    end;

    [Test]
    procedure Scenario_AC01_NullKey_ReturnsInvalidFormat()
    var
        Request: JsonObject;
        Response: JsonObject;
        NullValue: JsonValue;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        NullValue.SetValueToNull();
        Request.Add('projectNo', NullValue);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Update", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Null identifier must be a format error');
    end;
    [Test]
    procedure Scenario_AC01_NestedUpdate_PreservesOtherFields()
    var
        Task: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        Request: JsonObject;
        TaskRequest: JsonObject;
        PlanRequest: JsonObject;
        UpdateRequest: JsonObject;
        Tasks: JsonArray;
        PlanningLines: JsonArray;
    begin
        // Story #2, AC01 | Time: no planning date for text line | Risk: None
        Request := Library.NewProjectRequest();
        PlanRequest.Add('lineNo', 10000);
        PlanRequest.Add('type', 'Text');
        PlanRequest.Add('description', 'X Original plan');
        PlanningLines.Add(PlanRequest);
        TaskRequest.Add('taskNo', 'X100');
        TaskRequest.Add('description', 'X Original task');
        TaskRequest.Add('planningLines', PlanningLines);
        Tasks.Add(TaskRequest);
        Request.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        PlanRequest.Add('operation', 'Update');
        PlanRequest.Replace('description', 'X Updated plan');
        Clear(PlanningLines);
        PlanningLines.Add(PlanRequest);
        TaskRequest.Add('operation', 'Update');
        TaskRequest.Replace('planningLines', PlanningLines);
        Clear(Tasks);
        Tasks.Add(TaskRequest);
        UpdateRequest.Add('projectNo', Request.GetText('projectNo'));
        UpdateRequest.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Update", UpdateRequest), 'Success');
        Task.Get(Request.GetText('projectNo'), 'X100');
        PlanningLine.Get(Task."Job No.", Task."Job Task No.", 10000);
        Assert.AreEqual('X Original task', Task.Description, 'Omitted change must preserve task description');
        Assert.AreEqual('X Updated plan', PlanningLine.Description, 'Explicit nested update must persist');
    end;

    [Test]
    procedure Scenario_AC01_WrongTasksShape_ReturnsFormatError()
    var
        Request: JsonObject;
        TasksObject: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: root data arrays require shipping queue verification
        Request := Library.NewProjectRequest();
        TasksObject.Add('taskNo', 'X100');
        Request.Add('tasks', TasksObject);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'An object where tasks[] is required must fail before writing');
        Assert.AreEqual('tasks', Response.GetText('parameter'), 'Error must identify the payload key');
    end;

    [Test]
    procedure Scenario_AC01_InvalidDate_ReturnsFormatError()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: fixed invalid ISO date; Today ignored | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Request.Add('startingDate', '2026-02-30');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Update", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Impossible dates must fail before record lookup');
    end;

    [Test]
    procedure Scenario_AC01_FractionalAndZeroLine_RejectBeforeLookup()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Request.Add('taskNo', 'X100');
        Request.Add('lineNo', 1.5);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Delete", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Fractional primary key must fail validation');
        Request.Replace('lineNo', 0);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Delete", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Zero planning line number must fail validation');
    end;

    [Test]
    [CommitBehavior(CommitBehavior::Error)]
    procedure Scenario_AC01_OmitCommit_UsesCallerTransaction()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #2, AC01 | Time: native Today creation fields only | Risk: no explicit or implicit process commit allowed
        // [GIVEN] A self-created customer still inside this test's write transaction.
        Request := Library.NewProjectRequest();
        // [WHEN] The native process is run with the caller's Omit Commit flag.
        Response := Library.ExecuteNativeInTransaction("Message Type ori"::"Projects.Project.Create", Request);
        // [THEN] The process can see uncommitted caller data and succeeds without committing it.
        Library.AssertStatus(Response, 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Request.GetText('billToCustomerNo'), Project."Bill-to Customer No.", 'Uncommitted caller data must remain visible');
    end;

    [Test]
    procedure Scenario_AC01_ResourceLine_ValidatesQuantityCostAndPrice()
    begin
        // Story #2, AC01 | Time: fixed2026-10-16 planning date | Risk: all resource/UOM/posting groups are self-created
        AssertPlanningType('Resource', "Job Planning Line Type"::Resource);
    end;

    [Test]
    procedure Scenario_AC01_ItemLine_ValidatesQuantityCostAndPrice()
    begin
        // Story #2, AC01 | Time: fixed2026-10-16 planning date | Risk: all item/UOM/posting groups are self-created
        AssertPlanningType('Item', "Job Planning Line Type"::Item);
    end;

    [Test]
    procedure Scenario_AC01_GLLine_ValidatesQuantityCostAndPrice()
    begin
        // Story #2, AC01 | Time: fixed2026-10-16 planning date | Risk: all accounts/posting groups are self-created; nothing posts
        AssertPlanningType('G/L Account', "Job Planning Line Type"::"G/L Account");
    end;

    local procedure AssertPlanningType(Kind: Text; ExpectedType: Enum "Job Planning Line Type")
    var
        PlanningLine: Record "Job Planning Line";
        Request: JsonObject;
    begin
        Request := Library.NewPlanningRequest(Kind);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Request), 'Success');
        PlanningLine.Get(Request.GetText('projectNo'), 'X100', 10000);
        Assert.AreEqual(ExpectedType, PlanningLine.Type, 'Native line type must match the request');
        Assert.AreEqual(3, PlanningLine.Quantity, 'Native quantity must persist');
        Assert.AreEqual(7, PlanningLine."Unit Cost", 'Native cost must validate');
        Assert.AreEqual(11, PlanningLine."Unit Price", 'Native price must validate');
        Assert.AreEqual(21, PlanningLine."Total Cost", 'Native total cost must recalculate');
        Assert.AreEqual(33, PlanningLine."Total Price", 'Native total price must recalculate');
    end;

}
