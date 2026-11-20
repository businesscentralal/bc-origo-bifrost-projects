namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>AC05 (#77): Projects.ItemCost.Update is refused without the posting right or without native project rights.</summary>
codeunit 97157 "Proj. Item Cost Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>A read-only Projects role with native write rights gets PermissionDenied and nothing is advertised.</summary>
    [Test]
    procedure Scenario_AC05_ReadRole_PermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Item Cost Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('Proj Cost Test ori');
        Assert.IsFalse(Impl.IsEnabled(), 'Not advertised to a read role');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Assert.AreEqual('PermissionDenied', TempArgument.GetResponseJson().GetText('code'), 'Denied before licensing');
    end;

    /// <summary>The Full role without native project rights gets PermissionDenied.</summary>
    [Test]
    procedure Scenario_AC05_NoNativeRights_PermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Item Cost Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Assert.IsFalse(Impl.IsEnabled(), 'Not advertised without native rights');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Assert.AreEqual('PermissionDenied', TempArgument.GetResponseJson().GetText('code'), 'Denied');
    end;

    /// <summary>The Full role with native project rights is enabled.</summary>
    [Test]
    procedure Scenario_AC05_FullRole_Enabled()
    var
        Impl: Codeunit "Proj. Item Cost Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('Proj Cost Test ori');
        Assert.IsTrue(Impl.IsEnabled(), 'Enabled with the posting right and native rights');
    end;
}
