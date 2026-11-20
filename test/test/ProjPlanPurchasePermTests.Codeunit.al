namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue #74: no native modify rights and read-role refusals before any write.</summary>
codeunit 97172 "Proj Plan Purch Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>AC06 NoPurchaseRights PermissionDenied.</summary>
    [Test]
    procedure Scenario_AC06_NoPurchaseRights_PermissionDenied()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('ProjAllocTest ori');
        AssertDenied();
    end;

    /// <summary>AC06 ReadRole PermissionDenied.</summary>
    [Test]
    procedure Scenario_AC06_ReadRole_PermissionDenied()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('ProjAllocTest ori');
        AssertDenied();
    end;

    local procedure AssertDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Plan Purchase Impl ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Caller cannot create purchases');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing or input');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
    end;
}
