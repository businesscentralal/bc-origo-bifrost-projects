namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
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
}
