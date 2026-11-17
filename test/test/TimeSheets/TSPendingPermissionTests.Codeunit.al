namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Exercises the real native permission refusal under restrictive permissions.</summary>
codeunit 97150 "TS Pending Permission Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>Verifies Scenario AC02 AC06 NoNativeRead RefusesWithPermissionHint.</summary>
    [Test]
    procedure Scenario_AC02_AC06_NoNativeRead_RefusesWithPermissionHint()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "TS Pending Approval ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        // [GIVEN] The Foundation Read token, with no Timesheets native table permissions.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        // [WHEN] Discovery and execution check all native read permissions.
        Assert.IsFalse(Impl.IsEnabled(), 'Missing native reads disable discovery.');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        // [THEN] The refusal is actionable and happens before reading any time sheet.
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Permission denial.');
        Assert.AreEqual('Ask for the Timesheets permission set.', Response.GetText('nextStep'), 'Required exact hint.');
    end;
}
