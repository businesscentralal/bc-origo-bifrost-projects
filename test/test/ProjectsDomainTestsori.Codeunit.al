namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Environment.Configuration;
using System.TestLibraries.Utilities;

/// <summary>#113: Projects domains, setup guide and upgrade behaviour.</summary>
codeunit 97191 "Projects Domain Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Issue113_AC3_NewCompany_AllDomainsOff()
    var
        Setup: Record "Projects Setup ori";
        DomainGate: Codeunit "Projects Domain Gate ori";
        Ordinal: Integer;
    begin
        // [GIVEN] A company without a setup row, then with a freshly initialized row.
        Setup.DeleteAll();
        // [THEN] Every domain is off and a type of each domain is hidden.
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            Assert.IsFalse(Setup.IsDomainEnabled(Enum::"Projects Domain ori".FromInteger(Ordinal)), 'Missing row must count as off');
        Assert.IsFalse(DomainGate.IsTypeEnabled("Message Type ori"::"Projects.Project.Create"), 'Project operations must be off');
        Setup.InsertIfNotExists();
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            Assert.IsFalse(Setup.IsDomainEnabled(Enum::"Projects Domain ori".FromInteger(Ordinal)), 'A new setup row must start with every domain off');
        Assert.IsTrue(Setup.IsEnabled(), 'The company switch keeps its default');
    end;

    [Test]
    procedure Issue113_AC4_Upgrade_EnabledCompany_KeepsEverythingOn()
    var
        Setup: Record "Projects Setup ori";
        Ordinal: Integer;
    begin
        // [GIVEN] A 28.1.1 company with Projects enabled and no domain switches yet.
        Setup.DeleteAll();
        Setup.Init();
        Setup.Enabled := true;
        Setup.Insert();
        // [WHEN] The upgrade runs.
        Setup.UpgradeDomainsFromEnabled();
        // [THEN] Every domain is on.
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            Assert.IsTrue(Setup.IsDomainEnabled(Enum::"Projects Domain ori".FromInteger(Ordinal)), 'Upgrade must keep every domain on');
    end;

    [Test]
    procedure Issue113_AC4_Upgrade_MissingRow_KeepsEverythingOn()
    var
        Setup: Record "Projects Setup ori";
        Ordinal: Integer;
    begin
        // [GIVEN] A 28.1.1 company without a setup row (which meant enabled).
        Setup.DeleteAll();
        // [WHEN] The upgrade runs.
        Setup.UpgradeDomainsFromEnabled();
        // [THEN] Projects stays enabled with every domain on.
        Assert.IsTrue(Setup.IsEnabled(), 'Projects must stay enabled');
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            Assert.IsTrue(Setup.IsDomainEnabled(Enum::"Projects Domain ori".FromInteger(Ordinal)), 'Upgrade must turn every domain on');
    end;

    [Test]
    procedure Issue113_AC4_Upgrade_DisabledCompany_StaysOff()
    var
        Setup: Record "Projects Setup ori";
        Ordinal: Integer;
    begin
        // [GIVEN] A 28.1.1 company that switched Projects off.
        Setup.DeleteAll();
        Setup.Init();
        Setup.Enabled := false;
        Setup.Insert();
        // [WHEN] The upgrade runs.
        Setup.UpgradeDomainsFromEnabled();
        // [THEN] Nothing is turned on.
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            Assert.IsFalse(Setup.IsDomainEnabled(Enum::"Projects Domain ori".FromInteger(Ordinal)), 'Upgrade must not turn on a switched-off company');
    end;

    [Test]
    procedure Issue113_AC3_DisabledDomain_RefusesWithTypedErrorAndNextStep()
    begin
        // [GIVEN] Time sheets is off, other domains on.
        AssertDomainRefusal("Projects Domain ori"::TimeSheets, "Message Type ori"::"Projects.TimeSheet.Get", 'Time sheets');
    end;

    [Test]
    procedure Issue113_AC3_EachDomain_RefusesItsTypes()
    begin
        AssertDomainRefusal("Projects Domain ori"::ProjectOperations, "Message Type ori"::"Projects.Project.Create", 'Project operations');
        AssertDomainRefusal("Projects Domain ori"::TimeSheetUsage, "Message Type ori"::"Projects.Usage.Register", 'Time sheet usage');
        AssertDomainRefusal("Projects Domain ori"::FieldService, "Message Type ori"::"Projects.Visit.Start", 'Field service and van');
        AssertDomainRefusal("Projects Domain ori"::FollowUpRequests, "Message Type ori"::"Projects.FollowUp.Request", 'Follow-up requests');
        AssertDomainRefusal("Projects Domain ori"::Reports, "Message Type ori"::"Projects.Statistics.Get", 'Reports and statistics');
    end;

    [Test]
    procedure Issue113_AC5_DisabledDomain_RefusalInIcelandic()
    var
        SavedLanguage: Integer;
    begin
        // [GIVEN] The session runs in Icelandic (1039).
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [THEN] The refusal names the Icelandic domain caption.
        AssertDomainRefusal("Projects Domain ori"::TimeSheets, "Message Type ori"::"Projects.TimeSheet.Get", 'Tímaskýrslur');
        GlobalLanguage(SavedLanguage);
    end;

    [Test]
    procedure Issue113_AC3_DomainMap_CoversEveryProjectsType()
    var
        DomainGate: Codeunit "Projects Domain Gate ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
        Counts: array[6] of Integer;
    begin
        // [THEN] The 72 Projects types map to the six domains as decided on the card.
        Names := Enum::"Message Type ori".Names();
        Ordinals := Enum::"Message Type ori".Ordinals();
        for Index := 1 to Names.Count() do
            if Names.Get(Index).StartsWith('Projects.') then
                Counts[DomainGate.DomainOf(Enum::"Message Type ori".FromInteger(Ordinals.Get(Index))).AsInteger() + 1] += 1;
        Assert.AreEqual(27, Counts[1], 'Project operations');
        Assert.AreEqual(20, Counts[2], 'Time sheets');
        Assert.AreEqual(7, Counts[3], 'Time sheet usage');
        Assert.AreEqual(9, Counts[4], 'Field service and van');
        Assert.AreEqual(4, Counts[5], 'Follow-up requests');
        Assert.AreEqual(5, Counts[6], 'Reports and statistics');
    end;

    [Test]
    procedure Issue113_AC1_Wizard_SavesDomainsOnFinish()
    var
        Setup: Record "Projects Setup ori";
        Wizard: TestPage "Projects Setup Wizard ori";
    begin
        // [GIVEN] Every domain is off.
        Library.Initialize();
        Setup.Get();
        Setup.SetAllDomains(false);
        Setup.Modify();
        // [WHEN] The guide turns on Time sheets and Field service, sets a field service value and finishes.
        Wizard.OpenEdit();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.TimeSheets.SetValue(true);
        Wizard.FieldServiceAndVan.SetValue(true);
        Wizard.NextStep.Invoke();
        Wizard.RoundingMinutes.SetValue(15);
        Wizard.NextStep.Invoke();
        Wizard.Finish.Invoke();
        // [THEN] The choices are stored for the company and other domains stay off.
        Setup.Get();
        Assert.IsTrue(Setup."Time Sheets", 'Time sheets must be saved');
        Assert.IsTrue(Setup."Field Service and Van", 'Field service must be saved');
        Assert.IsFalse(Setup."Project Operations", 'Untouched domains stay off');
        Assert.AreEqual(15, Setup."Rounding Minutes", 'Field service settings must be saved');
    end;

    [Test]
    procedure Issue113_AC1_Wizard_CancelWritesNothing()
    var
        Setup: Record "Projects Setup ori";
        Wizard: TestPage "Projects Setup Wizard ori";
    begin
        // [GIVEN] Every domain is off.
        Library.Initialize();
        Setup.Get();
        Setup.SetAllDomains(false);
        Setup.Modify();
        // [WHEN] The guide changes a domain but is closed without Finish.
        Wizard.OpenEdit();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.ProjectOperations.SetValue(true);
        Wizard.Close();
        // [THEN] Nothing is saved.
        Setup.Get();
        Assert.IsFalse(Setup."Project Operations", 'Closing the guide must not save');
    end;

    [Test]
    procedure Issue113_AC1_Wizard_SkipsFieldServiceStepWhenOff()
    var
        Setup: Record "Projects Setup ori";
        Wizard: TestPage "Projects Setup Wizard ori";
    begin
        Library.Initialize();
        Setup.Get();
        Setup.SetAllDomains(false);
        Setup.Modify();
        Wizard.OpenEdit();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        // [THEN] With field service off the guide goes straight to Finish.
        Assert.IsTrue(Wizard.Finish.Visible(), 'Finish must follow Domains when field service is off');
        Assert.IsFalse(Wizard.RoundingMinutes.Visible(), 'Field service step must be skipped');
        Wizard.Close();
    end;

    [Test]
    procedure Issue113_AC1_Wizard_ListedInAssistedSetup()
    var
        GuidedExperience: Codeunit "Guided Experience";
        Registration: Codeunit "Projects Wizard Mgt ori";
    begin
        Registration.Register();
        Assert.IsTrue(GuidedExperience.Exists("Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"Projects Setup Wizard ori"), 'The guide must be listed in Assisted Setup');
    end;

    [Test]
    procedure Issue113_AC2_HttpStatus_ReadsOwnSetting()
    var
        WizardMgt: Codeunit "Projects Wizard Mgt ori";
        Enabled: Boolean;
        CanChange: Boolean;
    begin
        // [THEN] The guide can read this app's HTTP setting and an administrator can change it.
        Assert.IsTrue(WizardMgt.ReadHttpStatus(Enabled, CanChange), 'An administrator can read the HTTP setting');
        Assert.IsTrue(CanChange, 'An administrator can change the HTTP setting');
    end;

    local procedure AssertDomainRefusal(Domain: Enum "Projects Domain ori"; MessageType: Enum "Message Type ori"; DomainCaption: Text)
    var
        Setup: Record "Projects Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
        Response: JsonObject;
        ResponseText: Text;
    begin
        Library.Initialize();
        Setup.Get();
        Setup.SetDomain(Domain, false);
        Setup.Modify();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Impl := MessageType;
        Assert.IsFalse(Impl.IsEnabled(), 'A type of a disabled domain must be hidden');
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.WriteTo(ResponseText);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'A disabled domain must refuse with PreconditionFailed');
        Assert.IsTrue(ResponseText.Contains('nextStep'), 'The refusal must carry a nextStep');
        Assert.IsTrue(ResponseText.Contains(DomainCaption), 'The refusal must name the domain: ' + ResponseText);
        Setup.Get();
        Setup.SetDomain(Domain, true);
        Setup.Modify();
    end;
}
