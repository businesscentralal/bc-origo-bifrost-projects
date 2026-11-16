namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Verifies report execution refuses missing native read rights before input or licensing.</summary>
codeunit 97127 "Proj. Report Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>Missing native report permissions produces a named permission refusal without execution.</summary>
    [Test]
    procedure NoNativeReportRights_RefusesBeforeExecution()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        Impl: Codeunit "Proj. Report Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjReportTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Fixture setup enabled; missing native rights must cause refusal');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'No native report read rights');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'No report rendering before permission refusal');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Read ori'), 'Names the permission set');
    end;
}
