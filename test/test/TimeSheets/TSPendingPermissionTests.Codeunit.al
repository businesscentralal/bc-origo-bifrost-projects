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
        Assert.AreEqual('Assign the PROJ TS ADMIN permission set together with BIFROST Read ori or BIFROST Full ori.', Response.GetText('nextStep'), 'Required exact hint (#65).');
    end;

    /// <summary>#65: BIFROST Read ori together with PROJ TS ADMIN enables the pending-approval read again.</summary>
    [Test]
    procedure Scenario_65_ReadAndAdmin_EnablesPendingApproval()
    var
        Impl: Codeunit "TS Pending Approval ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
    begin
        // [GIVEN] The Foundation Read role and the Base App data set.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('PROJ TS ADMIN');
        // [WHEN] Discovery checks the native read permissions.
        // [THEN] The type is enabled.
        Assert.IsTrue(Impl.IsEnabled(), 'BIFROST Read ori and PROJ TS ADMIN grant every native read the type needs.');
    end;
}
