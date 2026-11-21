namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>AC04: real restricted roles cannot create linked journal lines.</summary>
codeunit 97180 "Proj. Plan Jnl Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    /// <summary>The Read role is refused even with native project permissions.</summary>
    [Test]
    procedure AC04_ReadRoleRefused()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        // Story #81, AC04 | Time: none | Risk: Permission boundaries
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ USAGE');
        AssertDenied();
    end;

    /// <summary>The Full role without native journal rights is refused before validation.</summary>
    [Test]
    procedure AC04_FullWithoutNativeRights()
    var
        Lower: Codeunit "Library - Lower Permissions";
    begin
        // Story #81, AC04 | Time: none | Risk: Permission boundaries
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        AssertDenied();
    end;

    /// <summary>Native modify rights do not grant journal insert rights.</summary>
    [Test]
    procedure AC04_ModifyWithoutInsertRefused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Journal: Record "Job Journal Line";
        Lower: Codeunit "Library - Lower Permissions";
        Fixture: Codeunit "Proj. Plan Journal Fixture ori";
        Impl: Codeunit "Proj. Plan Journal Impl ori";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #81, AC04 | Time: own open posting date | Risk: Permission boundaries
        Lower.PushPermissionSetWithoutDefaults('SUPER');
        Request := Fixture.Seed();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.PlanningLine.TransferToJournal";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Journal."Journal Template Name" := CopyStr(Request.GetText('templateName'), 1, 10);
        Journal."Journal Batch Name" := 'X81';
        Journal."Line No." := 12345;
        Journal.Description := 'X existing line';
        Journal.Insert(false);
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('ProjJnlNoInsert ori');
        Journal.Description := 'X modify permitted without insert';
        Journal.Modify(false);
        Commit();
        Impl.Execute(TempArgument);
        Response := TempArgument.GetResponseJson();
        Lower.PushPermissionSetWithoutDefaults('SUPER');
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), Format(Response));
        Journal.SetRange("Journal Template Name", Request.GetText('templateName'));
        Assert.AreEqual(1, Journal.Count(), 'No lines created without insert rights');
        Journal.FindFirst();
        Assert.AreEqual('X modify permitted without insert', Journal.Description, 'Native modify permission was exercised');
    end;

    local procedure AssertDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Plan Journal Impl ori";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
    begin
        Assert.IsFalse(Impl.IsEnabled(), 'Disabled for restricted role');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Permission checked before licence and input');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable refusal');
    end;
}
