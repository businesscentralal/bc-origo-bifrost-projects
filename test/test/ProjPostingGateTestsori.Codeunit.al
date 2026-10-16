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
    procedure Scenario_AC01_FullWithoutPosting_Denied()
    var
        Job: Record Job;
        TempArgument: Record "Message Argument ori" temporary;
        Gate: Codeunit "Proj. Posting Gate ori";
        Impl: Codeunit "Proj. WIP Post Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #5 | Risk: native rights alone must never grant posting.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('Proj Gate Test ori');
        Assert.IsTrue(Job.WritePermission(), 'Native write permission is present');
        Assert.IsFalse(Gate.HasPostingPermission(), 'Full role excludes the token');
        Assert.IsFalse(Impl.IsEnabled(), 'Posting must not be advertised');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Denied before licensing');
        Assert.IsTrue(Response.GetText('error').Contains('BIFROST ProjPost ori'), 'Denial names the required role');
    end;

    [Test]
    procedure Scenario_AC01_ExplicitPostingRole_Allowed()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Token: Record "Proj. Posting ori";
        Gate: Codeunit "Proj. Posting Gate ori";
        Impl: Codeunit "Proj. WIP Post Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
    begin
        // Story #5 | Risk: explicit role grants gate only; this is not shipping/licence acceptance.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('Proj Gate Test ori');
        Lower.AddPermissionSet('BIFROST ProjPost ori');
        TempArgument.Insert(true);
        Assert.IsTrue(Gate.HasPostingPermission(), 'Explicit role grants token permission');
        Assert.IsTrue(Impl.IsEnabled(), 'Posting enabled with native rights and explicit token');
        Assert.IsTrue(Gate.AssertCanPost(TempArgument), 'Gate allows caller');
        Assert.AreEqual(0, TempArgument.GetResponseContentLength(), 'Gate writes no response on success');
        Assert.AreEqual(0, Token.Count(), 'Permission token remains data-less');
    end;
}
