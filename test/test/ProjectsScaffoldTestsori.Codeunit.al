namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Scaffold AC coverage for setup, registry, discovery, and administrative restrictions.</summary>
codeunit 97100 "Projects Scaffold Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_MissingSetup_EnabledWithoutInsert()
    var
        Setup: Record "Projects Setup ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        // Story #1, AC01 | Time: no date dependency | Risk: None
        // [GIVEN] The owned company's setup is absent.
        Setup.DeleteAll();
        // [WHEN] Discovery checks the native job table.
        // [THEN] Defaults are enabled without a discovery write.
        Assert.IsTrue(Gate.IsEnabled(Database::Job, true), 'Missing setup should default on');
        Assert.AreEqual(0, Setup.Count(), 'Discovery must not insert setup');
    end;

    [Test]
    procedure Scenario_AC01_DisabledSetup_ReturnsContractError()
    var
        Setup: Record "Projects Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
        Response: JsonObject;
    begin
        // Story #1, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Setup.Get();
        Setup.Enabled := false;
        Setup.Modify(true);
        TempArgument.Type := "Message Type ori"::"Projects.Project.Create";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Impl := "Message Type ori"::"Projects.Project.Create";
        Assert.IsFalse(Impl.IsEnabled(), 'Disabled type should not be advertised as enabled');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Disabled call should explain the company switch');
    end;

    [Test]
    procedure Scenario_AC01_SetupPageToggle_PersistsSwitch()
    var
        Setup: Record "Projects Setup ori";
        SetupPage: TestPage "Projects Setup ori";
    begin
        // Story #1, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        SetupPage.OpenEdit();
        SetupPage.Enabled.SetValue(false);
        SetupPage.Close();
        Setup.Get();
        Assert.IsFalse(Setup.Enabled, 'The user-facing setup switch must persist');
        Setup.InsertIfNotExists();
        Setup.Get();
        Assert.IsFalse(Setup.Enabled, 'Initialization must preserve the administrator choice');
    end;

    [Test]
    procedure Scenario_AC01_GenericSetupWrite_IsRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // Story #1, AC01 | Time: no date dependency | Risk: None
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Projects Setup ori", false), 'Generic writes must not bypass Projects Setup administration');
    end;

    [Test]
    procedure Scenario_AC02_SixteenTypes_HaveLocalizedDiscovery()
    var
        Impl: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Name: Text;
        Count: Integer;
        OriginalLanguage: Integer;
        English: Text;
    begin
        // Story #1, AC02 | Time: no date dependency | Risk: catalogue grows in later issue families
        Library.Initialize();
        OriginalLanguage := GlobalLanguage();
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        foreach Name in Names do
            if (Ordinals.Get(Names.IndexOf(Name)) >= 10078485) and (Ordinals.Get(Names.IndexOf(Name)) <= 10078584) then begin
                Assert.IsTrue(Name.StartsWith('Projects.'), 'Every owned enum value must use the Projects prefix');
                MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(Name)));
                Impl := MessageType;
                Discovery := MessageType;
                GlobalLanguage(1033);
                English := Impl.GetDescription();
                Assert.IsTrue(English <> '', 'English description missing for ' + Name);
                Assert.IsTrue(Discovery.GetKeywords() <> '', 'English keywords missing');
                GlobalLanguage(1039);
                Assert.AreNotEqual(English, Impl.GetDescription(), 'Icelandic description must be translated for ' + Name);
                Assert.IsTrue(Discovery.GetKeywords() <> '', 'Icelandic keywords missing');
                Count += 1;
            end;
        GlobalLanguage(OriginalLanguage);
        Assert.AreEqual(16, Count, 'Catalogue must contain the nine lifecycle types and WIP Get/Calculate; WIP Post is not registered');
    end;

    [Test]
    procedure Scenario_AC02_AllTypes_ExposeValidContract()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
        Name: Text;
        Parameters: JsonToken;
    begin
        // Story #1, AC02 | Time: no date dependency | Risk: None
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        foreach Name in Names do
            if (Ordinals.Get(Names.IndexOf(Name)) >= 10078485) and (Ordinals.Get(Names.IndexOf(Name)) <= 10078584) then begin
                Assert.IsTrue(Name.StartsWith('Projects.'), 'Every owned enum value must use the Projects prefix');
                Clear(Contract);
                MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(Name)));
                Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Contract missing for ' + Name);
                Assert.IsTrue(Contract.Get('parameters', Parameters), 'Parameter chapter missing for ' + Name);
                Assert.IsTrue(Parameters.AsArray().Count() > 0, 'Project identifier must be declared');
            end;
    end;
    [Test]
    procedure Scenario_AC01_RegistryEvent_ExposesOwnSetupPage()
    var
        TempApps: Record "Registered App ori" temporary;
        Registry: Codeunit "App Registry ori";
        ProjectsAppId: Guid;
    begin
        // Story #1, AC01 | Time: no date dependency | Risk: installed app registry only; no license or backend changes
        // [WHEN] Foundation builds the registry through its actual subscriber event.
        Registry.GetApps(TempApps);
        Evaluate(ProjectsAppId, 'c847bab7-2525-4ff5-93c4-15512b3be1e5');
        // [THEN] The Projects module resolves to its own setup page.
        Assert.IsTrue(TempApps.Get(ProjectsAppId), 'Projects must register with Foundation');
        Assert.AreEqual('Bifrost Projects', TempApps."App Name", 'Registry must expose this module name');
        Assert.AreEqual(Page::"Projects Setup ori", TempApps."Setup Page Id", 'Registry must expose the owned setup page');
    end;

}
