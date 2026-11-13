namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Reflection;
using System.TestLibraries.Utilities;

/// <summary>Proves native archive writes are refused before licensing for a read-only caller.</summary>
codeunit 97123 "Proj. Archive Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>No Native Permissions: Cannot Create Archive.</summary>
    [Test]
    procedure NoNativePermissions_CannotCreateArchive()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        Impl: Codeunit "Proj. Archive Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjArchiveTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Fixture setup enabled; missing native rights must cause the refusal');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'Caller without native rights cannot create an archive');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing and input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Names the required permission set');
    end;
    /// <summary>No native archive read rights denies the read adapter before input or licensing.</summary>
    [Test]
    procedure NoNativePermissions_CannotReadArchive()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        Impl: Codeunit "Proj. Archive Get Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjArchiveTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Fixture setup enabled; missing native rights must cause the refusal');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'No native archive read rights');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing and input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Read ori'), 'Names read permission set');
    end;
    /// <summary>Read plus native archive rights permits queries but requires Full for creation before licensing or writes.</summary>
    [Test]
    procedure ReadWithNativeArchiveWrites_RequiresFullForCreateOnly()
    var
        Archive: Record "Job Archive";
        TempArgument: Record "Message Argument ori" temporary;
        Adapter: Codeunit "Projects Archive ori";
        Impl: Codeunit "Proj. Archive Impl ori";
        Posting: Codeunit "Proj. Posting Gate ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('ProjArchiveNat ori');
        Assert.IsTrue(Archive.ReadPermission(), 'Native archive read actually present');
        Assert.IsTrue(Archive.WritePermission(), 'Native archive write actually present');
        Assert.IsFalse(Posting.HasPostingPermission(), 'Read role does not grant the feature Full token');
        Assert.IsTrue(Adapter.IsEnabled(false), 'Read plus native rights still enables archive queries');
        Assert.IsFalse(Adapter.IsEnabled(true), 'Read plus native writes cannot create versions');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Full boundary refuses before licensing or input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Refusal names the required feature role');
        Lower.AddPermissionSet('BIFROST Full ori');
        Assert.IsTrue(Posting.HasPostingPermission(), 'Full role grants the feature token');
        Assert.AreEqual(not HasAssignedResourceTables(), Adapter.IsEnabled(true), 'BC 29 also requires assigned-resource rights; BC 28 remains enabled');
        Lower.AddPermissionSet('SUPER');
        Assert.IsTrue(Adapter.IsEnabled(true), 'Full with all native archive rights enables creation');
    end;

    /// <summary>Missing BC 29 source rights and read-only destination rights return typed refusals before native archiving.</summary>
    [Test]
    procedure AssignedResourcePermissions_RefuseBeforeNativeArchive()
    var
        Project: Record Job;
        Archive: Record "Job Archive";
        JobsSetup: Record "Jobs Setup";
        Adapter: Codeunit "Projects Archive ori";
        Library: Codeunit "Projects Test Library ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Create a valid native fixture before restricting permissions; the runner rolls it back.
        Lower.PushPermissionSetWithoutDefaults('SUPER');
        Library.Initialize();
        Project."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Project."No."));
        Project.Insert(false);
        JobsSetup.Get();
        JobsSetup."Archive Jobs" := JobsSetup."Archive Jobs"::Always;
        JobsSetup.Modify(true);
        Request.Add('projectNo', Project."No.");
        Archive.SetRange("No.", Project."No.");

        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('ProjArchiveNat ori');
        Assert.IsTrue(Adapter.IsEnabled(false), 'Archive reads do not require live assigned-resource rights');
        if HasAssignedResourceTables() then begin
            Assert.IsFalse(HasNativePermission('Job Assigned Resource', false), 'Fixture lacks assigned-resource source read rights');
            AssertArchivePermissionDenied(Request);
            Assert.IsTrue(Archive.IsEmpty(), 'Missing source rights create no archive version');

            Lower.AddPermissionSet('Jobs - Read');
            Assert.IsTrue(HasNativePermission('Job Assigned Resource', false), 'Native source read right is now present');
            Assert.IsTrue(HasNativePermission('Job Assigned Resource Archive', false), 'Native destination read right is present');
            Assert.IsFalse(HasNativePermission('Job Assigned Resource Archive', true), 'Native destination is read-only');
            AssertArchivePermissionDenied(Request);
            Assert.IsTrue(Archive.IsEmpty(), 'Read-only destination creates no archive version');
            Lower.AddPermissionSet('SUPER');
        end;
        Assert.IsTrue(Adapter.IsEnabled(true), 'All rights present, or BC 28 without the optional tables');
        Response := ExecuteArchive(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetInteger('versionNo'), 'Denied calls did not allocate archive versions');
    end;

    local procedure AssertArchivePermissionDenied(Request: JsonObject)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Archive Impl ori";
        Adapter: Codeunit "Projects Archive ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Discovery refuses the restricted caller');
        Assert.IsFalse(Adapter.IsEnabled(true), 'Preflight refuses before native execution');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Adapter refuses before licensing and native execution');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Typed refusal provides corrective permissions');
        Response := ExecuteArchive(Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Execution boundary also refuses before native archiving');
    end;

    local procedure ExecuteArchive(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Adapter: Codeunit "Projects Archive ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Adapter.Execute(TempArgument, true);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure HasAssignedResourceTables(): Boolean
    var
        NativeTable: Record AllObj;
    begin
        NativeTable.SetRange("Object Type", NativeTable."Object Type"::Table);
        NativeTable.SetRange("Object Name", 'Job Assigned Resource');
        exit(not NativeTable.IsEmpty());
    end;

    local procedure HasNativePermission(TableName: Text[30]; NeedWrite: Boolean): Boolean
    var
        NativeTable: Record AllObj;
        Target: RecordRef;
    begin
        NativeTable.SetRange("Object Type", NativeTable."Object Type"::Table);
        NativeTable.SetRange("Object Name", TableName);
        NativeTable.FindFirst();
        Target.Open(NativeTable."Object ID");
        if NeedWrite then
            exit(Target.WritePermission());
        exit(Target.ReadPermission());
    end;
}
