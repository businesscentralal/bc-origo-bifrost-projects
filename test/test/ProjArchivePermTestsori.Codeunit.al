namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Archive;
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
        Assert.IsTrue(Adapter.IsEnabled(true), 'Full with all native archive rights enables creation');
    end;

}
