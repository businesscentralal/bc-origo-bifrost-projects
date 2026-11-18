namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Projects #49: native read permissions remain mandatory even with Foundation Read.</summary>
codeunit 97162 "TS Sheet Get Permission Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>Discovery and execution both refuse callers lacking native table reads.</summary>
    [Test]
    procedure AC02_MissingNativeRead_Denied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "TS Sheet Get Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        // [GIVEN] The caller has Foundation Read without native time-sheet read permissions.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        // [WHEN] Discovery and execution evaluate the native permissions.
        Assert.IsFalse(Impl.IsEnabled(), 'Discovery requires native reads.');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        // [THEN] The error is typed, actionable and contains no data.
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Native permissions required.');
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'Actionable refusal.');
        Assert.IsFalse(Response.Contains('timeSheets'), 'No data returned.');
    end;
}
