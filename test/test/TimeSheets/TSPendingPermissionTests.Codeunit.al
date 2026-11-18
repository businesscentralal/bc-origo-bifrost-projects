namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Exercises the real native permission refusal under restrictive permissions.</summary>
codeunit 97150 "TS Pending Permission Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>Names the assignable Projects role in the English native permission refusal.</summary>
    [Test]
    procedure Scenario_AC05_EnglishNoNativeRead_NamesProjectsRole()
    begin
        // Story #59, AC05 | Time: independent of dates | Risk: None
        AssertPermissionHint(1033, 'Assign the PROJ TS ADMIN permission set together with BIFROST Read ori or BIFROST Full ori.');
    end;

    /// <summary>Names the same role in the Icelandic native permission refusal.</summary>
    [Test]
    procedure Scenario_AC05_IcelandicNoNativeRead_NamesProjectsRole()
    begin
        // Story #59, AC05 | Time: independent of dates | Risk: None
        AssertPermissionHint(1039, 'Úthlutaðu heimildasamstæðunni PROJ TS ADMIN ásamt BIFROST Read ori eða BIFROST Full ori.');
    end;

    local procedure AssertPermissionHint(LanguageId: Integer; ExpectedHint: Text)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "TS Pending Approval ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
        OriginalLanguage: Integer;
    begin
        // [GIVEN] The Foundation Read role without Projects native time-sheet data grants.
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        // [WHEN] Discovery and execution check all native read permissions.
        Assert.IsFalse(Impl.IsEnabled(), 'Missing native reads disable discovery.');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        GlobalLanguage(OriginalLanguage);
        // [THEN] Refusal precedes data access and identifies the assignable Projects role.
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Permission denial.');
        Assert.AreEqual(ExpectedHint, Response.GetText('nextStep'), 'Localized Projects permission hint.');
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
