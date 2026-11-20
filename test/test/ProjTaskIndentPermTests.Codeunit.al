namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>AC04: Restrictive role checks refuse indentation before licensing, input or writes.</summary>
codeunit 97115 "Proj. Indent Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>AC04: The Full role without native task write rights is refused.</summary>
    [Test]
    procedure AC04_FullWithoutNativeModify()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        AssertDenied();
    end;

    /// <summary>AC04: The Read role is refused even with native task modify rights.</summary>
    [Test]
    procedure AC04_ReadWithNativeModify()
    var
        Lower: Codeunit "Library - Lower Permissions";
        Task: Record "Job Task";
        Assert: Codeunit "Library Assert";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('ProjIndentNative ori');
        Assert.IsTrue(Task.WritePermission(), 'Native modify right is actually present');
        AssertDenied();
    end;

    local procedure AssertDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Task Indent Impl ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Indent disabled for restricted caller');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing and input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Names required feature role');
    end;
}
