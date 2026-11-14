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
        Setup: Record "Projects Setup ori";
        Impl: Codeunit "Proj. Allocation Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjAllocTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Owned test company Projects setup is enabled; the refusal must come from missing native rights');
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
