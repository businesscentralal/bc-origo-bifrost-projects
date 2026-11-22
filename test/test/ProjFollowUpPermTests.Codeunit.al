namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Technician and manager separation for follow-up operations (#87 AC01/04/05).</summary>
codeunit 97189 "Proj. Follow-up Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Proj. Follow-up Fixture ori";
        Tests: Codeunit "Proj. Follow-up Tests ori";

    [Test]
    procedure Scenario_AC05_ReadOnlyCannotRequest()
    var
        Lower: Codeunit "Library - Lower Permissions";
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
        Response: JsonObject;
        Request: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsFalse(Mgt.CanRun(1), 'Read role has no follow-up write grant.');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Read-only refusal.');
    end;

    [Test]
    procedure Scenario_AC01_AC05_TechnicianRequestAndList()
    var
        Header: Record "Proj. Follow-up Request ori";
        Line: Record "Proj. Follow-up Req. Line ori";
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Manifest: JsonObject;
        Response: JsonObject;
        Request: JsonObject;
        Id: Integer;
        Dump: Text;
    begin
        Manifest := Fixture.Seed();
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ FIELD TECH');
        Assert.IsTrue(Header.ReadPermission(), 'Header read.');
        Assert.IsFalse(Header.WritePermission(), 'Technician has no delete grant.');
        Assert.IsTrue(Line.ReadPermission(), 'Line read.');
        Assert.IsFalse(Line.WritePermission(), 'Technician has no line delete grant.');
        Assert.IsTrue(Mgt.CanRun(1), 'Technician follow-up capability.');
        Assert.IsFalse(Task.WritePermission(), 'Technician cannot write tasks.');
        Assert.IsFalse(Planning.WritePermission(), 'Technician cannot write planning lines.');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.Request", Tests.RequestJson(Manifest));
        Response.WriteTo(Dump);
        Assert.AreEqual('Success', Response.GetText('status'), Dump);
        Id := Response.GetInteger('requestId');
        Request.Add('projectNo', Manifest.GetText('projectNo'));
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.List", Request);
        Assert.AreEqual(1, Response.GetArray('requests').Count(), 'Own request visible.');
        Request.Add('resourceNo', 'ANOTHER-TECH');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.List", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Another technician refused.');
        Clear(Request);
        Request.Add('requestId', Id);
        Request.Add('target', 'newTask');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Technician cannot convert.');
        Request.Remove('target');
        Request.Add('reason', 'Not needed');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.Reject", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Technician cannot reject.');
    end;

    [Test]
    procedure Scenario_AC04_ManagerCannotSeeOtherProjects()
    var
        Project: Record Job;
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Project.Get(Manifest.GetText('projectNo'));
        Project."Project Manager" := 'X87OTHER';
        Project.Modify(false);
        Request.Add('projectNo', Manifest.GetText('projectNo'));
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.List", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Manager scoped to responsible projects.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC05_NoPermissionRefused()
    var
        Lower: Codeunit "Library - Lower Permissions";
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('D365 READ');
        Assert.IsFalse(Mgt.CanRun(1), 'Native read alone cannot write follow-ups.');
        Response := Tests.Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'No-permission call refused.');
    end;

    [Test]
    procedure Z_CleanupLastFixture()
    begin
        Fixture.CleanupLast();
        Commit();
    end;
}
