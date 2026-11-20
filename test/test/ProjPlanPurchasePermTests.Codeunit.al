namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;

/// <summary>Issue #74: no native modify rights and read-role refusals before any write.</summary>
codeunit 97172 "Proj Plan Purch Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>AC07 Project rights without purchase rights are refused before calculation.</summary>
    [Test]
    procedure Scenario_AC07_NoPurchaseRights_PermissionDenied()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('Proj Purch NoPurchase ori');
        AssertProjectRightsWithoutPurchase();
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

    local procedure AssertProjectRightsWithoutPurchase()
    var
        Project: Record Job;
        Planning: Record "Job Planning Line";
        Purchase: Record "Purchase Header";
        Assert: Codeunit "Library Assert";
    begin
        Assert.IsTrue(Project.ReadPermission(), 'Caller can read projects');
        Assert.IsTrue(Planning.WritePermission(), 'Caller can maintain planning lines');
        Assert.IsFalse(Purchase.WritePermission(), 'Caller has no purchase document write rights');
    end;

    local procedure AssertDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Plan Purchase Impl ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
        Count: Integer;
        Summary: Text;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Caller cannot create purchases');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing or input');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
        Clear(TempArgument);
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.GetConfirmCount(TempArgument, Count, Summary), 'Foundation pre-dispatch count is also denied before licensing');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Counter cannot bypass native purchase rights');
    end;
}
