namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Issue #4 native status, completion, block and unblock component tests.</summary>
codeunit 97105 "Projects Status Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_StatusPlanningQuoteOpen_UsesNativeValues()
    var
        Project: Record Job;
        Request: JsonObject;
        ChangeRequest: JsonObject;
    begin
        // Story #4, AC01 | Time: native Today modification field only | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        ChangeRequest.Add('projectNo', Request.GetText('projectNo'));
        ChangeRequest.Add('status', 'Planning');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Status::Planning, Project.Status, 'Planning must persist');
        ChangeRequest.Replace('status', 'Quote');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Status::Quote, Project.Status, 'Quote must persist');
        ChangeRequest.Replace('status', 'Open');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Status::Open, Project.Status, 'Open must persist');
    end;

    [Test]
    procedure Scenario_AC01_BlockAndUnblock_PreservesStatus()
    var
        Project: Record Job;
        Request: JsonObject;
        ChangeRequest: JsonObject;
    begin
        // Story #4, AC01 | Time: no date dependency | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        ChangeRequest.Add('projectNo', Request.GetText('projectNo'));
        ChangeRequest.Add('blocked', 'All');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Blocked::All, Project.Blocked, 'All block must persist');
        Assert.AreEqual(Project.Status::Open, Project.Status, 'Omitted status must be preserved');
        ChangeRequest.Replace('blocked', 'Posting');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Blocked::Posting, Project.Blocked, 'Posting block must persist');
        ChangeRequest.Replace('blocked', 'None');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Blocked::" ", Project.Blocked, 'None must unblock');
    end;

    [Test]
    [HandlerFunctions('CompletionMessageHandler')]
    procedure Scenario_AC01_Complete_InvokesNativeCompleteFlag()
    var
        Project: Record Job;
        Request: JsonObject;
        ChangeRequest: JsonObject;
    begin
        // Story #4, AC01 | Time: native WorkDate for default Ending Date; no WIP or ledger fixtures | Risk: None
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        ChangeRequest.Add('projectNo', Request.GetText('projectNo'));
        ChangeRequest.Add('status', 'Completed');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", ChangeRequest), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(Project.Status::Completed, Project.Status, 'Completed must persist');
        Assert.IsTrue(Project.Complete, 'Status validation must execute native completion, not only assign the enum');
        Assert.IsTrue(Project."Ending Date" >= WorkDate(), 'Native completion must set its ending date');
    end;

    [Test]
    procedure Scenario_AC01_NoStateChange_ReturnsMissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #4, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'A no-op must not silently report Success');
    end;

    [Test]
    procedure Scenario_AC01_InvalidState_ReturnsFormatError()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #4, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XDOESNOTEXIST');
        Request.Add('status', 'Released');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Unknown native status must fail before lookup');
    end;
    [MessageHandler]
    procedure CompletionMessageHandler(MessageText: Text[1024])
    var
        Project: Record Job;
    begin
        Assert.IsTrue(StrPos(MessageText, Project.FieldCaption("Ending Date")) > 0, 'Native completion must report its ending date change');
    end;

}
