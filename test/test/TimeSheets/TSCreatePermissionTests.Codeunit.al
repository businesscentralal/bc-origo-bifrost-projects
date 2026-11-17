namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>No-permission path of Projects.TimeSheet.Create.</summary>
codeunit 97143 "TS Create Permission Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC07_NoWritePermission_IsDisabledAndDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        CreateImpl: Codeunit "TS Sheet Create Impl ori";
        Request: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] a caller whose permissions do not include writing time sheets
        LibraryLowerPermissions.SetCustomerView();
        Assert.IsFalse(Header.WritePermission(), 'The lowered caller must not write time sheet headers.');

        // [WHEN] the type is asked whether it is enabled and is executed
        Assert.IsFalse(CreateImpl.IsEnabled(), 'The type must be disabled without write permission.');
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument."Type" := "Message Type ori"::"Projects.TimeSheet.Create";
        TempArgument."Version" := TempArgument."Version"::"1.0";
        TempArgument.Insert();
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNo', 'X-MISSING');
        TempArgument.SetRequestJson(Request);
        CreateImpl.ExecuteBifrostTask(TempArgument);

        // [THEN] it answers PermissionDenied with a next step naming the permission set
        TempArgument.GetResponseJson().Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal code.');
        TempArgument.GetResponseJson().Get('nextStep', Token);
        Assert.AreEqual('Assign the BIFROST Timeshts ori permission set.', Token.AsValue().AsText(), 'Refusal next step.');
    end;
}
