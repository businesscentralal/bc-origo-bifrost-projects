namespace Origo.Bifrost.Projects.Test;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.WIP;
using System.TestLibraries.Utilities;
/// <summary>Explicit posting permission boundary independent of native business rights and licensing.</summary>
codeunit 97107 "Proj. Posting Gate Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_ReadWithNativeWrite_Denied()
    var
        Job: Record Job;
        TempArgument: Record "Message Argument ori" temporary;
        Gate: Codeunit "Proj. Posting Gate ori";
        Impl: Codeunit "Proj. WIP Post Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #5 | Risk: native rights with Projects Read must not grant posting.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('Proj Gate Test ori');
        Assert.IsTrue(Job.WritePermission(), 'Native write permission is present');
        Assert.IsFalse(Gate.HasPostingPermission(), 'Projects Read grants no posting token write');
        Assert.IsFalse(Impl.IsEnabled(), 'Posting must not be advertised');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing');
        Assert.IsTrue(Response.GetText('error').Contains('BIFROST Full ori'), 'Denial names the required role');
    end;

    [Test]
    procedure Scenario_AC01_FullWithNativeWrite_Allowed()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Token: Record "Proj. Posting ori";
        Gate: Codeunit "Proj. Posting Gate ori";
        Impl: Codeunit "Proj. WIP Post Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
    begin
        // Story #5 | Risk: Projects Full grants gate; this is not shipping/licence acceptance.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('Proj Gate Test ori');
        TempArgument.Insert(true);
        Assert.IsTrue(Gate.HasPostingPermission(), 'Projects Full grants token write');
        Assert.IsTrue(Impl.IsEnabled(), 'Posting enabled with native rights and Projects Full');
        Assert.IsTrue(Gate.AssertCanPost(TempArgument), 'Gate allows caller');
        Assert.AreEqual(0, TempArgument.GetResponseContentLength(), 'Gate writes no response on success');
        Assert.AreEqual(0, Token.Count(), 'Permission token remains data-less');
    end;
}
