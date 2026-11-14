namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Foundation.Reporting;
using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.Email;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #15 Projects.Quote.Send component tests. Every profile the tests send through has no channel enabled, so
/// nothing leaves the tenant; refusals are checked before anything is sent. Data is created per test with unique codes.
/// </summary>
codeunit 97140 "Projects Quote Send Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_RequestProfile_SendsQuote()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        Request: JsonObject;
        Response: JsonObject;
        Previous: Enum "Job Archive Option";
    begin
        // Story #15, AC01 | Time: no date dependency | Risk: profile without channels, nothing leaves the tenant
        Previous := SetArchiveRule("Job Archive Option"::Never);
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', LowerCase(Profile.Code));
        Response := Send(Request);
        SetArchiveRule(Previous);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(Project."No.", Response.GetText('projectNo'), 'projectNo');
        Assert.AreEqual(Project."Bill-to Customer No.", Response.GetText('customerNo'), 'customerNo');
        Assert.AreEqual(Profile.Code, Response.GetText('documentSendingProfileCode'), 'The request profile is used, compared in upper case');
        Assert.AreEqual('Request', Response.GetText('documentSendingProfileSource'), 'source');
        Assert.IsFalse(Response.GetBoolean('archived'), 'Archive Projects = Never stores no archive');
    end;

    [Test]
    procedure Scenario_AC01_CustomerProfile_UsedWithoutOverride()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        Customer: Record Customer;
        Request: JsonObject;
        Response: JsonObject;
        Previous: Enum "Job Archive Option";
    begin
        // Story #15, AC01 | Time: no date dependency | Risk: profile without channels
        Previous := SetArchiveRule("Job Archive Option"::Never);
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Customer.Get(Project."Bill-to Customer No.");
        Customer."Document Sending Profile" := Profile.Code;
        Customer.Modify(true);
        Request.Add('projectNo', Project."No.");
        Response := Send(Request);
        SetArchiveRule(Previous);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(Profile.Code, Response.GetText('documentSendingProfileCode'), 'The customer profile is used');
        Assert.AreEqual('Customer', Response.GetText('documentSendingProfileSource'), 'source');
    end;

    [Test]
    procedure Scenario_AC01_ArchiveAlways_StoresArchiveVersion()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        JobArchive: Record "Job Archive";
        Request: JsonObject;
        Response: JsonObject;
        Previous: Enum "Job Archive Option";
    begin
        // Story #15, AC04 edge case | Time: no date dependency | Risk: archive rows of the own project are removed
        Previous := SetArchiveRule("Job Archive Option"::Always);
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', Profile.Code);
        Response := Send(Request);
        SetArchiveRule(Previous);
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.GetBoolean('archived'), 'Archive Projects = Always archives the sent quote, as the card action does');
        JobArchive.SetRange("No.", Project."No.");
        Assert.AreEqual(1, JobArchive.Count(), 'One archive version');
        JobArchive.DeleteAll(true);
    end;

    [Test]
    procedure Scenario_AC02_OpenProject_RefusedPreconditionFailed()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #15, AC02 | Time: no date dependency | Risk: refused before sending
        CreateQuoteProject(Project);
        Project.Status := Project.Status::Open;
        Project.Modify(false);
        CreateProfile(Profile);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', Profile.Code);
        Response := Send(Request);
        AssertRefusal(Response, 'PreconditionFailed', 'projectNo', 'Set the project status to Quote');
        Assert.AreEqual(Format(Project.Status::Open), Response.GetText('received'), 'received names the current status');
    end;

    [Test]
    procedure Scenario_AC02_PlanningProject_Refused1039()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        // Story #15, AC02 + AC04 lcid 1039 | Time: no date dependency | Risk: refused before sending
        CreateQuoteProject(Project);
        Project.Status := Project.Status::Planning;
        Project.Modify(false);
        Request.Add('projectNo', Project."No.");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Send(Request);
        GlobalLanguage(PreviousLanguage);
        AssertRefusal(Response, 'PreconditionFailed', 'projectNo', 'Projects.Project.SetStatus');
        Assert.IsTrue(Response.GetText('error').Contains('aðeins verkefni'), 'The refusal is Icelandic: ' + Response.GetText('error'));
        Assert.IsTrue(Response.GetText('nextStep').Contains('Stilltu stöðu'), 'The nextStep is Icelandic: ' + Response.GetText('nextStep'));
    end;

    [Test]
    procedure Scenario_AC04_MissingProjectNo_MissingParameter()
    var
        Request: JsonObject;
    begin
        // Story #15, AC04 invalid input | Time: no date dependency | Risk: None
        Library.Initialize();
        AssertRefusal(Send(Request), 'MissingParameter', 'projectNo', 'projectNo');
    end;

    [Test]
    procedure Scenario_AC04_OverlongProfileAndNumericProject_BothReported()
    var
        Request: JsonObject;
        Response: JsonObject;
        Errors: JsonToken;
    begin
        // Story #15, AC04 invalid input | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 12345);
        Request.Add('documentSendingProfile', PadStr('', 21, 'A'));
        Response := Send(Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('MultipleErrors', Response.GetText('code'), 'Both problems are reported together');
        Assert.IsTrue(Response.Get('errors', Errors), 'errors[] lists each problem');
        Assert.AreEqual(2, Errors.AsArray().Count(), 'Two problems');
        Assert.IsTrue(Format(Response).Contains('documentSendingProfile'), 'The profile key is named');
        Assert.IsTrue(Format(Response).Contains('never cut'), 'The nextStep says a longer code is never cut');
    end;

    [Test]
    procedure Scenario_AC04_UnknownProject_RecordNotFound()
    var
        Request: JsonObject;
    begin
        // Story #15, AC04 invalid input | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XNOPROJECT15');
        AssertRefusal(Send(Request), 'RecordNotFound', 'projectNo', 'existing project');
    end;

    [Test]
    procedure Scenario_AC04_UnknownProfile_RecordNotFound()
    var
        Project: Record Job;
        Request: JsonObject;
    begin
        // Story #15, AC04 invalid input | Time: no date dependency | Risk: None
        CreateQuoteProject(Project);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', 'XNOPROFILE15');
        AssertRefusal(Send(Request), 'RecordNotFound', 'documentSendingProfile', 'existing Document Sending Profile');
    end;

    [Test]
    procedure Scenario_AC04_DiskProfile_RefusedBeforeSending()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        Request: JsonObject;
    begin
        // Story #15, AC04 edge case | Time: no date dependency | Risk: refused before sending
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Profile.Disk := Profile.Disk::PDF;
        Profile.Modify(false);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', Profile.Code);
        AssertRefusal(Send(Request), 'PreconditionFailed', 'documentSendingProfile', 'no Disk channel');
    end;

    [Test]
    procedure Scenario_AC04_EmailPromptProfile_RefusedBeforeSending()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        Request: JsonObject;
    begin
        // Story #15, AC04 edge case | Time: no date dependency | Risk: refused before sending
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Profile."E-Mail" := Profile."E-Mail"::"Yes (Prompt for Settings)";
        Profile.Modify(false);
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', Profile.Code);
        AssertRefusal(Send(Request), 'PreconditionFailed', 'documentSendingProfile', 'Yes (Use Default Settings)');
    end;

    [Test]
    procedure Scenario_AC04_EmailProfileWithoutAddress_NothingSent()
    var
        Project: Record Job;
        Profile: Record "Document Sending Profile";
        SentEmail: Record "Sent Email";
        EmailOutbox: Record "Email Outbox";
        Request: JsonObject;
        SentCount: Integer;
        QueuedCount: Integer;
    begin
        // Story #15, AC04 edge case | Time: no date dependency | Risk: refused before sending; no e-mail is queued
        CreateQuoteProject(Project);
        CreateProfile(Profile);
        Profile."E-Mail" := Profile."E-Mail"::"Yes (Use Default Settings)";
        Profile.Modify(false);
        SentCount := SentEmail.Count();
        QueuedCount := EmailOutbox.Count();
        Request.Add('projectNo', Project."No.");
        Request.Add('documentSendingProfile', Profile.Code);
        AssertRefusal(Send(Request), 'PreconditionFailed', 'email', 'customer e-mail address');
        Assert.AreEqual(SentCount, SentEmail.Count(), 'No e-mail was sent');
        Assert.AreEqual(QueuedCount, EmailOutbox.Count(), 'No e-mail was queued');
    end;

    [Test]
    procedure Scenario_AC05_TypeName_HasThreeParts()
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Name: Text;
    begin
        // Story #15, AC05 | Time: no date dependency | Risk: None
        MessageType := "Message Type ori"::"Projects.Quote.Send";
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        Name := Names.Get(Ordinals.IndexOf(MessageType.AsInteger()));
        Assert.AreEqual('Projects.Quote.Send', Name, 'Name');
        Assert.AreEqual(3, Name.Split('.').Count(), 'Exactly three dot-separated parts');
    end;

    local procedure Send(Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Quote Send Impl ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.Quote.Send";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Impl.SendQuote(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure CreateQuoteProject(var Project: Record Job)
    var
        Request: JsonObject;
    begin
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Project.Status := Project.Status::Quote;
        Project.Modify(false);
    end;

    local procedure CreateProfile(var Profile: Record "Document Sending Profile")
    begin
        Profile.Init();
        Profile.Code := CopyStr('XQ' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Profile.Code));
        Profile.Description := 'X Projects quote send test';
        Profile.Printer := Profile.Printer::No;
        Profile."E-Mail" := Profile."E-Mail"::No;
        Profile.Disk := Profile.Disk::No;
        Profile."Electronic Document" := Profile."Electronic Document"::No;
        Profile.Default := false;
        Profile.Insert(false);
    end;

    /// <summary>Sets Archive Projects and returns the previous rule.</summary>
    local procedure SetArchiveRule(Rule: Enum "Job Archive Option") Previous: Enum "Job Archive Option"
    var
        JobsSetup: Record "Jobs Setup";
    begin
        Library.Initialize();
        JobsSetup.Get();
        Previous := JobsSetup."Archive Jobs";
        JobsSetup."Archive Jobs" := Rule;
        JobsSetup.Modify(false);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; NextStepOrErrorPart: Text)
    begin
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), 'code: ' + Format(Response));
        Assert.AreEqual(ExpectedParameter, Response.GetText('parameter'), 'parameter: ' + Format(Response));
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Every refusal has a nextStep: ' + Format(Response));
        Assert.IsTrue(Format(Response).Contains(NextStepOrErrorPart), 'Expected text missing: ' + Format(Response));
    end;
}
