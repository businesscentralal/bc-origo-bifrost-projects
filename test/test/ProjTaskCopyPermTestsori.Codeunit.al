namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>AC06: Restrictive role checks refuse copying before licensing, input or writes.</summary>
codeunit 97176 "Proj. Task Copy Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>AC06: The Full role without native task write rights is refused.</summary>
    [Test]
    procedure AC06_FullWithoutNativeModify()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        AssertDenied();
    end;

    /// <summary>AC06: The Read role is refused even with native task modify rights.</summary>
    [Test]
    procedure AC06_ReadWithNativeModify()
    var
        Task: Record "Job Task";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('ProjIndentNative ori');
        Assert.IsTrue(Task.WritePermission(), 'Native modify right is actually present');
        AssertDenied();
    end;

    /// <summary>AC06: task modify rights do not authorize inserting copied tasks.</summary>
    [Test]
    procedure AC06_FullWithModifyButNoInsert()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Task: Record "Job Task";
        Lower: Codeunit "Library - Lower Permissions";
        Library: Codeunit "Projects Test Library ori";
        Fixture: Codeunit "Proj. Task Copy Fixture ori";
        Impl: Codeunit "Proj. Task Copy Impl ori";
        Assert: Codeunit "Library Assert";
        Manifest: JsonObject;
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('SUPER');
        Manifest := Fixture.Seed();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.Task.CopyFrom";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Fixture.Request(Manifest));
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('ProjCopyNoInsert ori');
        Impl.Execute(TempArgument);
        Response := TempArgument.GetResponseJson();
        Lower.PushPermissionSetWithoutDefaults('SUPER');
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Missing native insert refused');
        Task.SetRange("Job No.", Manifest.GetText('targetProjectNo'));
        Assert.AreEqual(1, Task.Count(), 'Target unchanged without insert rights');
        Fixture.Cleanup(Manifest);
    end;

    local procedure AssertDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Task Copy Impl ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Copy disabled for restricted caller');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing and input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Names required feature role');
    end;
}
