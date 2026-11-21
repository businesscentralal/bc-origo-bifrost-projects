namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue 78: verifies native indentation, atomic failures and the complete request contract with owned data.</summary>
codeunit 97169 "Proj. Task Indent Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>AC01: Two nested levels produce native ranges and a second call changes nothing.</summary>
    [Test]
    procedure AC01_NestedTasksAndIdempotency()
    var
        ProjectNo: Code[20];
        Response: JsonObject;
        Rows: JsonArray;
        Row: JsonToken;
    begin
        ProjectNo := NewProject();
        AddTask(ProjectNo, '100', "Job Task Type"::"Begin-Total");
        AddTask(ProjectNo, '200', "Job Task Type"::"Begin-Total");
        AddTask(ProjectNo, '300', "Job Task Type"::Posting);
        AddTask(ProjectNo, '400', "Job Task Type"::"End-Total");
        AddTask(ProjectNo, '500', "Job Task Type"::"End-Total");
        Response := ExecuteProject(ProjectNo);
        Library.AssertStatus(Response, 'Success');
        Rows := Response.GetArray('tasks');
        Assert.AreEqual(5, Rows.Count(), 'All project tasks returned');
        AssertTask(ProjectNo, Rows.GetObject(0), 0, '');
        AssertTask(ProjectNo, Rows.GetObject(1), 1, '');
        AssertTask(ProjectNo, Rows.GetObject(2), 2, '');
        AssertTask(ProjectNo, Rows.GetObject(3), 1, '200..400');
        AssertTask(ProjectNo, Rows.GetObject(4), 0, '100..500');
        Assert.AreEqual('Posting', Rows.GetObject(2).GetText('taskType'), 'Stable enum name');
        Assert.AreEqual(5, Response.GetObject('summary').GetInteger('changedCount'), 'Every seeded indentation changed');
        Response := ExecuteProject(ProjectNo);
        Assert.AreEqual(0, Response.GetObject('summary').GetInteger('changedCount'), 'Second call is idempotent');
        foreach Row in Response.GetArray('tasks') do
            Assert.IsFalse(Row.AsObject().GetBoolean('changed'), 'Every task unchanged on second call');
        Cleanup(ProjectNo);
    end;

    /// <summary>AC02: A late unmatched End-Total rolls back earlier native modifications.</summary>
    [Test]
    procedure AC02_UnmatchedEndTotalRollsBack()
    var
        Task: Record "Job Task";
        ProjectNo: Code[20];
        Response: JsonObject;
    begin
        ProjectNo := NewProject();
        AddTask(ProjectNo, '100', "Job Task Type"::Posting);
        AddTask(ProjectNo, '200', "Job Task Type"::"End-Total");
        Response := ExecuteProject(ProjectNo);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Native structure error classified');
        Assert.IsTrue(Response.GetText('error').Contains('200'), 'Native reason identifies unmatched task');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Corrective next step');
        Task.Get(ProjectNo, '100');
        Assert.AreEqual(9, Task.Indentation, 'Earlier native update rolled back');
        Task.Get(ProjectNo, '200');
        Assert.AreEqual(9, Task.Indentation, 'Invalid task unchanged');
        Assert.AreEqual('', Task.Totaling, 'No totaling written');
        Cleanup(ProjectNo);
    end;

    /// <summary>AC03: Missing, malformed, overlength and unknown input have stable refusal codes.</summary>
    [Test]
    procedure AC03_ParameterRefusals()
    var
        Request: JsonObject;
        Value: JsonToken;
    begin
        AssertCode(Request, 'MissingParameter');
        Request.Add('projectNo', '');
        AssertCode(Request, 'MissingParameter');
        Request.Replace('projectNo', 123);
        AssertCode(Request, 'InvalidParameterFormat');
        Value.ReadFrom('null');
        Request.Replace('projectNo', Value);
        AssertCode(Request, 'InvalidParameterFormat');
        Request.Replace('projectNo', '123456789012345678901');
        AssertCode(Request, 'InvalidParameterFormat');
        Request.Replace('projectNo', 'X-NOT-FOUND');
        AssertCode(Request, 'RecordNotFound');
        Request.Add('indent', true);
        AssertCode(Request, 'UnknownParameter');
    end;

    /// <summary>AC01/AC03: Empty projects succeed and the exact 20-character boundary is accepted.</summary>
    [Test]
    procedure AC01_EmptyProjectAndLengthBoundary()
    var
        ProjectNo: Code[20];
        Response: JsonObject;
    begin
        ProjectNo := NewProject();
        Assert.AreEqual(20, StrLen(ProjectNo), 'Fixture exercises maximum number length');
        Response := ExecuteProject(ProjectNo);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('tasks').Count(), 'Empty project has no tasks');
        Assert.AreEqual(0, Response.GetObject('summary').GetInteger('changedCount'), 'No changes');
        Cleanup(ProjectNo);
    end;

    /// <summary>AC02: Native depth limit is preserved and an overflow rolls back all tasks.</summary>
    [Test]
    procedure AC02_DepthLimitRollsBack()
    var
        Task: Record "Job Task";
        ProjectNo: Code[20];
        Index: Integer;
        Response: JsonObject;
    begin
        ProjectNo := NewProject();
        for Index := 1 to 11 do
            AddTask(ProjectNo, CopyStr(Format(100 + Index, 0, 9), 1, 20), "Job Task Type"::"Begin-Total");
        Response := ExecuteProject(ProjectNo);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Native depth limit');
        Task.SetRange("Job No.", ProjectNo);
        Task.FindSet();
        repeat
            Assert.AreEqual(9, Task.Indentation, 'All depth changes rolled back');
        until Task.Next() = 0;
        Cleanup(ProjectNo);
    end;

    /// <summary>AC05: Chapters remain English while discovery and recovery instructions are translated.</summary>
    [Test]
    procedure AC05_LocalizedDiscoveryAndEnglishHelp()
    var
        Impl: Codeunit "Proj. Task Indent Impl ori";
        OriginalLanguage: Integer;
        English: Text;
        Icelandic: Text;
        Overview: Text;
        Parameters: JsonArray;
        Errors: JsonArray;
        ChapterEnglish: Text;
        ChapterIcelandic: Text;
        Notes: Text;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := Impl.GetDescription();
        Impl.GetParameters(Parameters);
        Impl.GetErrors(Errors);
        Parameters.WriteTo(ChapterEnglish);
        ChapterEnglish += Format(Errors);
        Impl.GetOverview(Overview);
        Impl.GetNotes(Notes);
        GlobalLanguage(1039);
        Icelandic := Impl.GetDescription();
        Assert.AreNotEqual(English, Icelandic, 'Discovery translated');
        Clear(Parameters);
        Clear(Errors);
        Impl.GetParameters(Parameters);
        Impl.GetErrors(Errors);
        Parameters.WriteTo(ChapterIcelandic);
        ChapterIcelandic += Format(Errors);
        Assert.AreEqual(ChapterEnglish, ChapterIcelandic, 'Contract chapters remain English');
        Impl.GetOverview(Icelandic);
        Assert.AreEqual(Overview, Icelandic, 'Overview remains English');
        Impl.GetNotes(Icelandic);
        Assert.AreEqual(Notes, Icelandic, 'Notes remain English');
        GlobalLanguage(OriginalLanguage);
    end;

    /// <summary>Seeds isolated raw fixtures for the public MCP verification; the following cleanup test removes them.</summary>
    [Test]
    procedure SeedMcpFixtures()
    var
        Project: Record Job;
        ProjectNo: Code[20];
        Lcid: Integer;
        Languages: List of [Integer];
    begin
        Library.Initialize();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach Lcid in Languages do begin
            ProjectNo := CopyStr('X78MCP' + Format(Lcid, 0, 9), 1, 20);
            if not Project.Get(ProjectNo) then begin
                Project.Init();
                Project."No." := ProjectNo;
                Project.Description := 'X78 indentation test';
                Project.Insert(false);
                AddTask(ProjectNo, '100', "Job Task Type"::"Begin-Total");
                AddTask(ProjectNo, '200', "Job Task Type"::"Begin-Total");
                AddTask(ProjectNo, '300', "Job Task Type"::Posting);
                AddTask(ProjectNo, '400', "Job Task Type"::"End-Total");
                AddTask(ProjectNo, '500', "Job Task Type"::"End-Total");
            end;
            ProjectNo := CopyStr('X78MCPBAD' + Format(Lcid, 0, 9), 1, 20);
            if not Project.Get(ProjectNo) then begin
                Project.Init();
                Project."No." := ProjectNo;
                Project.Description := 'X78 indentation test';
                Project.Insert(false);
                AddTask(ProjectNo, '100', "Job Task Type"::Posting);
                AddTask(ProjectNo, '200', "Job Task Type"::"End-Total");
            end;
        end;
        Commit();
        Project.SetRange(Description, 'X78 indentation test');
        Assert.AreEqual(4, Project.Count(), 'Four owned MCP projects, no demo records');
    end;

    /// <summary>Removes only this story's own AL and MCP fixtures on the worker tenant.</summary>
    [Test]
    procedure CleanupMcpFixtures()
    var
        Project: Record Job;
        Task: Record "Job Task";
    begin
        Project.SetFilter(Description, '%1|%2', 'X78 indentation test', 'X indent fixture');
        if Project.FindSet() then
            repeat
                Task.SetRange("Job No.", Project."No.");
                Task.DeleteAll(false);
                Project.Delete(false);
            until Project.Next() = 0;
        Commit();
        Assert.IsTrue(Project.IsEmpty(), 'No owned indentation fixtures remain');
    end;

    local procedure NewProject(): Code[20]
    var
        Project: Record Job;
    begin
        Library.Initialize();
        Project."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Project.Description := 'X indent fixture';
        Project.Insert(false);
        exit(Project."No.");
    end;

    local procedure AddTask(ProjectNo: Code[20]; TaskNo: Code[20]; TaskType: Enum "Job Task Type")
    var
        Task: Record "Job Task";
    begin
        Task."Job No." := ProjectNo;
        Task."Job Task No." := TaskNo;
        Task."Job Task Type" := TaskType;
        Task.Indentation := 9;
        Task.Insert(false);
    end;

    local procedure ExecuteProject(ProjectNo: Code[20]): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('projectNo', ProjectNo);
        exit(Execute(Request));
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    begin
        exit(Library.ExecuteNative("Message Type ori"::"Projects.Task.Indent", Request));
    end;

    local procedure AssertCode(Request: JsonObject; Code: Text)
    var
        Response: JsonObject;
    begin
        Response := Execute(Request);
        Assert.AreEqual('Error', Response.GetText('status'), 'Refusal status');
        Assert.AreEqual(Code, Response.GetText('code'), 'Stable error code');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable recovery');
    end;

    local procedure AssertTask(ProjectNo: Code[20]; Row: JsonObject; Indentation: Integer; Totaling: Text)
    var
        Task: Record "Job Task";
    begin
        Assert.AreEqual(Indentation, Row.GetInteger('indentation'), 'Response indentation');
        Assert.AreEqual(Totaling, Row.GetText('totaling'), 'Response totaling');
        Assert.IsTrue(Row.GetBoolean('changed'), 'Changed from fixture');
        Task.Get(ProjectNo, Row.GetText('taskNo'));
        Assert.AreEqual(Indentation, Task.Indentation, 'Persisted indentation');
        Assert.AreEqual(Totaling, Task.Totaling, 'Persisted totaling');
    end;

    local procedure Cleanup(ProjectNo: Code[20])
    var
        Project: Record Job;
        Task: Record "Job Task";
    begin
        Task.SetRange("Job No.", ProjectNo);
        Task.DeleteAll(false);
        Project.Get(ProjectNo);
        Project.Delete(false);
        Commit();
    end;
}
