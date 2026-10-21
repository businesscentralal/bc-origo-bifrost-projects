namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Proves allocation refuses restricted callers before licensing or data access.</summary>
codeunit 97121 "Proj. Allocation Perm Test ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>No Native Permissions: Refuses Before Reading Input.</summary>
    [Test]
    procedure NoNativePermissions_RefusesBeforeReadingInput()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Allocation Impl ori";
        Library: Codeunit "Projects Test Library ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Library.Initialize();
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjAllocTest ori');
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.ResourceAllocation.Get";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'Allocation is not enabled without native rights');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Refusal before licensing and input');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Read ori'), 'Next step names permission set');
    end;
}
