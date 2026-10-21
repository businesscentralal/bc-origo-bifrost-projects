namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Verifies real native archive snapshots and read-only archive queries with isolated project fixtures.</summary>
codeunit 97122 "Projects Archive Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>Happy Path: Native Archive Includes Tasks And Planning.</summary>
    [Test]
    procedure HappyPath_NativeArchiveIncludesTasksAndPlanning()
    var
        Request: JsonObject;
        Response: JsonObject;
        Snapshot: JsonObject;
    begin
        Request.Add('projectNo', NewProject());
        Response := Execute(Request, true);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('versionNo'), 'Fresh project first archive version');
        Request.Add('versionNo', 1);
        Response := Execute(Request, false);
        Snapshot := Response.GetArray('versions').GetObject(0);
        Assert.AreEqual('X archive project', Snapshot.GetText('description'), 'Project copied by native archive');
        Assert.AreEqual('X task', Snapshot.GetArray('tasks').GetObject(0).GetText('description'), 'Native task snapshot');
        Assert.AreEqual(3, Snapshot.GetArray('planningLines').GetObject(0).GetDecimal('quantity'), 'Native planning quantity');
    end;

    /// <summary>Edge: Two Archives Create Distinct Immutable Versions.</summary>
    [Test]
    procedure Edge_TwoArchivesCreateDistinctImmutableVersions()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
        Versions: JsonArray;
    begin
        Project.Get(NewProject());
        Request.Add('projectNo', Project."No.");
        Assert.AreEqual(1, Execute(Request, true).GetInteger('versionNo'), 'First version');
        Project.Description := 'X changed project';
        Project.Modify(true);
        Assert.AreEqual(2, Execute(Request, true).GetInteger('versionNo'), 'Second version');
        Response := Execute(Request, false);
        Versions := Response.GetArray('versions');
        Assert.AreEqual(2, Versions.Count(), 'List both versions');
        Assert.IsFalse(Versions.GetObject(0).Contains('tasks'), 'List response omits expanded snapshot');
        Request.Add('versionNo', 1);
        Response := Execute(Request, false);
        Assert.AreEqual('X archive project', Response.GetArray('versions').GetObject(0).GetText('description'), 'First archive remains immutable');
        Request.Replace('versionNo', 2);
        Response := Execute(Request, false);
        Assert.AreEqual('X changed project', Response.GetArray('versions').GetObject(0).GetText('description'), 'Second archive has changed source');
    end;

    /// <summary>Invalid Input: Archive Disabled Writes Nothing.</summary>
    [Test]
    procedure InvalidInput_ArchiveDisabledWritesNothing()
    var
        Setup: Record "Jobs Setup";
        Archive: Record "Job Archive";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('projectNo', NewProject());
        Setup.Get();
        Setup."Archive Jobs" := Setup."Archive Jobs"::Never;
        Setup.Modify(true);
        Response := Execute(Request, true);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Native archiving switch required');
        Assert.AreEqual('Turn on Archive Projects in Jobs Setup.', Response.GetText('nextStep'), 'Actionable setup next step');
        Archive.SetRange("No.", Request.GetText('projectNo'));
        Assert.IsTrue(Archive.IsEmpty(), 'No version created on refusal');
    end;

    /// <summary>Read Missing Version And Project: Return Record Not Found.</summary>
    [Test]
    procedure ReadMissingVersionAndProject_ReturnRecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('projectNo', NewProject());
        Response := Execute(Request, true);
        Library.AssertStatus(Response, 'Success');
        Request.Add('versionNo', 99);
        Response := Execute(Request, false);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing version is not an empty success');
        Assert.AreEqual('List versions with Projects.ProjectArchive.Get.', Response.GetText('nextStep'), 'Version discovery next step');
        Request.Replace('projectNo', NewNumber());
        Response := Execute(Request, false);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing archive project');
        Request.Remove('versionNo');
        Response := Execute(Request, true);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing source project');
    end;

    /// <summary>Read Archive Survives Missing Live Project.</summary>
    [Test]
    procedure ReadArchiveSurvivesMissingLiveProject()
    var
        Project: Record Job;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Project.Get(NewProject());
        Request.Add('projectNo', Project."No.");
        Response := Execute(Request, true);
        Library.AssertStatus(Response, 'Success');
        Project.Delete(false);
        Request.Add('versionNo', 1);
        Response := Execute(Request, false);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetArray('versions').Count(), 'Archive read does not depend on live project');
    end;

    /// <summary>Common Refusals: No Partial Archive.</summary>
    [Test]
    procedure CommonRefusals_NoPartialArchive()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(Request, true);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Required project number');
        Request.Add('projectNo', 1);
        Response := Execute(Request, true);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Wrong identifier JSON type');
        Request.Replace('projectNo', NewProject());
        Request.Add('unexpected', true);
        Response := Execute(Request, true);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'Unknown key refused');
        Request.Remove('unexpected');
        Request.Add('versionNo', 0);
        Response := Execute(Request, false);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Version must be positive');
        Response := Execute(Request, true);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'Archive cannot accept a caller-selected version');
    end;

    /// <summary>Read Is Scoped By Project And Version.</summary>
    [Test]
    procedure ReadIsScopedByProjectAndVersion()
    var
        Request: JsonObject;
        OtherRequest: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('projectNo', NewProject());
        OtherRequest.Add('projectNo', NewProject());
        Response := Execute(Request, true);
        Library.AssertStatus(Response, 'Success');
        Response := Execute(OtherRequest, true);
        Library.AssertStatus(Response, 'Success');
        Request.Add('versionNo', 1);
        Response := Execute(Request, false);
        Assert.AreEqual(1, Response.GetArray('versions').Count(), 'Other project archive excluded');
        Assert.AreEqual(Request.GetText('projectNo'), Response.GetArray('versions').GetObject(0).GetText('projectNo'), 'Exact project archive');
    end;

    local procedure Execute(Request: JsonObject; CreateVersion: Boolean): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Archive: Codeunit "Projects Archive ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Archive.Execute(TempArgument, CreateVersion);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure NewNumber(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure NewProject(): Code[20]
    var
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Setup: Record "Jobs Setup";
    begin
        Library.Initialize();
        Setup.Get();
        Setup."Archive Jobs" := Setup."Archive Jobs"::Always;
        Setup.Modify(true);
        Project."No." := NewNumber();
        Project.Description := 'X archive project';
        Project.Insert(true);
        Task."Job No." := Project."No.";
        Task."Job Task No." := 'X100';
        Task.Description := 'X task';
        Task.Insert(true);
        Planning."Job No." := Project."No.";
        Planning."Job Task No." := Task."Job Task No.";
        Planning."Line No." := 10000;
        Planning.Description := 'X planning';
        Planning.Quantity := 3;
        Planning.Insert(false);
        exit(Project."No.");
    end;
}
