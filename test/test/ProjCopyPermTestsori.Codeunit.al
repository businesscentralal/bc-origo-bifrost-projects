namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue #3 rejects copy operations before licensing and writes for a caller without native project rights.</summary>
codeunit 97113 "Proj Copy Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    [Test]
    procedure Scenario_AC01_ReadRole_CopyDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        CopyImpl: Codeunit "Proj. Copy Impl ori";
        Response: JsonObject;
    begin
        // [GIVEN] The Foundation read role without native project write permissions.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        TempArgument.Type := "Message Type ori"::"Projects.Project.Copy";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        // [WHEN] The shipping copy implementation is invoked.
        Assert.IsFalse(CopyImpl.IsEnabled(), 'Copy must not be advertised without native rights');
        CopyImpl.ExecuteBifrostTask(TempArgument);
        // [THEN] Permission denial occurs before request processing or native changes.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Copy must deny a caller without native writes');
    end;
}
