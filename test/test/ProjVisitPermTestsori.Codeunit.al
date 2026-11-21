namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Utilities;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Diagnostics;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Permission tests for field visits (projects#83, AC06). Team Member on SaaS stays NOT_RUN.</summary>
codeunit 97187 "Proj. Visit Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ReadOnly_IsRefused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "Proj. Visit Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsFalse(Mgt.CanRun(), 'Read alone cannot record a visit.');
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        Mgt.ExecuteStart(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', TextOf(Response, 'code'), 'Missing PROJ VISIT is PermissionDenied.');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains('PROJ VISIT'), 'The next step names PROJ VISIT.');
    end;

    [Test]
    procedure TechGrants_CanStart()
    var
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
    begin
        // A run with test isolation disabled can leave All Fields logging on the visit table.
        // Clear it before any write, so the change log does not cache that choice for this session.
        ClearVisitChangeLog();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo);
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ TS SELF');
        Lower.AddPermissionSet('PROJ VISIT');
        Assert.AreEqual('', MissingGrants(), MissingGrants());
        Response := Run("Message Type ori"::"Projects.Visit.Start", ProjectNo, TaskNo);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
    end;

    [Test]
    procedure ProjVisit_HasNoJournalTableData()
    var
        Expanded: Record "Expanded Permission";
    begin
        Expanded.SetRange("Role ID", 'PROJ VISIT');
        Expanded.SetRange("Object Type", Expanded."Object Type"::"Table Data");
        Expanded.SetFilter("Object ID", '%1|%2|%3', Database::"Job Journal Line", Database::"Job Ledger Entry", Database::"Res. Journal Line");
        Expanded.SetRange("Insert Permission", Expanded."Insert Permission"::Yes);
        Assert.IsTrue(Expanded.IsEmpty(), 'PROJ VISIT grants no journal or ledger insert.');
    end;

    local procedure ClearVisitChangeLog()
    var
        LogTable: Record "Change Log Setup (Table)";
        LogField: Record "Change Log Setup (Field)";
        ChangeLogMgt: Codeunit "Change Log Management";
    begin
        // AC08 can leave All Fields logging on this table. The change log keeps that choice
        // in a single-instance codeunit for the session, so a later restricted start still tries
        // to insert a change log entry. PROJ VISIT does not include that table.
        LogField.SetRange("Table No.", Database::"Proj. Field Visit ori");
        if not LogField.IsEmpty() then
            LogField.DeleteAll();
        if LogTable.Get(Database::"Proj. Field Visit ori") then
            LogTable.Delete();
        Clear(ChangeLogMgt);
    end;

    local procedure Prepare(var ResourceNo: Code[20]; var SheetNo: Code[20]; var ProjectNo: Code[20]; var TaskNo: Code[20])
    var
        Resource: Record Resource;
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        Header: Record "Time Sheet Header";
        Setup: Record "Projects Setup ori";
        WorkType: Record "Work Type";
        LibraryJob: Codeunit "Library - Job";
        LibraryResource: Codeunit "Library - Resource";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        Day: Date;
    begin
        Day := DT2Date(CurrentDateTime());
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", 'X83OTHER', false);
        LibraryResource.CreateResourceNew(Resource);
        Resource.Validate("Use Time Sheet", true);
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(UserId()), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Modify(true);
        ResourceNo := Resource."No.";
        WorkType.Init();
        WorkType.Code := CopyStr('P83' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(WorkType.Code));
        WorkType.Insert(true);
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Travel Work Type Code" := WorkType.Code;
        Setup."Rounding Minutes" := 1;
        Setup."Client Time Tolerance Hours" := 24;
        Setup."Allow Unplanned Tasks" := false;
        Setup.Modify(true);
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        ProjectNo := Job."No.";
        TaskNo := JobTask."Job Task No.";
        LibraryTimeSheet.CreateJobPlanningLine(Planning, ProjectNo, TaskNo, ResourceNo, Day);
        Header.Init();
        Header."No." := CopyStr('P83' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := Day;
        Header."Ending Date" := Day + 6;
        Header."Owner User ID" := CopyStr(UpperCase(UserId()), 1, MaxStrLen(Header."Owner User ID"));
        Header.Insert(false);
        SheetNo := Header."No.";
    end;

    local procedure Run(MessageType: Enum "Message Type ori"; ProjectNo: Code[20]; TaskNo: Code[20]) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        MsgInterface: Interface "Msg Interface ori";
        Request: JsonObject;
    begin
        Request.Add('projectNo', ProjectNo);
        Request.Add('taskNo', TaskNo);
        Request.Add('kind', 'work');
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        MsgInterface.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure MissingGrants() Reason: Text
    var
        Visit: Record "Proj. Field Visit ori";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Usage: Record "TS Usage Line ori";
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        WorkType: Record "Work Type";
        Resource: Record Resource;
        Setup: Record "Projects Setup ori";
    begin
        if not Visit.ReadPermission() then
            Reason += 'visitR ';
        if not Visit.WritePermission() then
            Reason += 'visitW ';
        if not Header.ReadPermission() then
            Reason += 'headerR ';
        if not Line.ReadPermission() then
            Reason += 'lineR ';
        if not Line.WritePermission() then
            Reason += 'lineW ';
        if not Detail.ReadPermission() then
            Reason += 'detailR ';
        if not Detail.WritePermission() then
            Reason += 'detailW ';
        if not Usage.ReadPermission() then
            Reason += 'usageR ';
        if not Usage.WritePermission() then
            Reason += 'usageW ';
        if not Job.ReadPermission() then
            Reason += 'jobR ';
        if not JobTask.ReadPermission() then
            Reason += 'taskR ';
        if not Planning.ReadPermission() then
            Reason += 'planR ';
        if not WorkType.ReadPermission() then
            Reason += 'workTypeR ';
        if not Resource.ReadPermission() then
            Reason += 'resourceR ';
        if not Setup.ReadPermission() then
            Reason += 'setupR ';
    end;

    local procedure Dump(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
        Result := CopyStr(Result, 1, 240);
    end;

    local procedure TextOf(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;
}
