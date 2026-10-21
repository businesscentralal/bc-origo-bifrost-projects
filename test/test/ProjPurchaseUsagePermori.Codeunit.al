namespace Origo.Bifrost.Projects.Test;

using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Proves native purchase rights alone cannot authorize dedicated Full-only feature operations.</summary>
codeunit 97129 "Proj. Purchase Usage Perm ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>Native purchase write rights cannot replace the explicit BIFROST Full feature token.</summary>
    [Test]
    procedure NativePurchaseRightsWithoutFullToken_RefuseLink()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        PurchaseLine: Record "Purchase Line";
        Impl: Codeunit "Proj. Purchase Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjUsageTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Feature fixture enabled');
        Assert.IsTrue(PurchaseLine.WritePermission(), 'Native purchase write rights actually present');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'Native rights alone do not grant feature Full');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Refusal before licensing or argument read');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Names Full permission set');
    end;

    /// <summary>Read-only feature token and no native posting rights refuse item consumption before licensing.</summary>
    [Test]
    procedure NoNativePostingOrFullToken_RefuseItemUsage()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        Impl: Codeunit "Proj. Item Usage Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('ProjUsageTest ori');
        Assert.IsTrue(Setup.IsEnabled(), 'Feature fixture enabled');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Assert.IsFalse(Impl.IsEnabled(), 'Item usage cannot post without Full/native rights');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Refusal before licensing or argument read');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Names Full permission set');
    end;
    /// <summary>The full feature role and every other guarded native right cannot replace tracking write permission.</summary>
    [Test]
    procedure FullWithoutReservationRights_DeniesBeforePosting()
    var
        Reservation: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Projects Setup ori";
        Usage: Codeunit "Projects Item Usage ori";
        Impl: Codeunit "Proj. Item Usage Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('ProjUsageTest ori');
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(true);
        Assert.IsFalse(Reservation.WritePermission(), 'The omitted native reservation right is actually absent');
        Assert.IsFalse(Usage.IsEnabled(), 'Every native posting right is required');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before input, licensing or native posting');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Actionable permission guidance');
        Lower.AddPermissionSet('ProjUsageResTest ori');
        Assert.IsTrue(Reservation.WritePermission(), 'Native reservation right now actually present');
        Assert.IsTrue(Usage.IsEnabled(), 'Completing native rights makes the permission gate available');
    end;

}
