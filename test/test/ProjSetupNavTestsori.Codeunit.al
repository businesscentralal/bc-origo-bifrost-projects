namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Tests the Projects setup entry on the Bifröst page (#117).</summary>
codeunit 97193 "Proj. Setup Nav. Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Opens existing setup through the English action without changing settings.</summary>
    [Test]
    procedure EnglishActionOpensExistingSetup()
    begin
        VerifyExistingSetup(1033);
    end;

    /// <summary>Opens existing setup through the Icelandic action without changing settings.</summary>
    [Test]
    procedure IcelandicActionOpensExistingSetup()
    begin
        VerifyExistingSetup(1039);
    end;

    /// <summary>Uses the normal setup page initialization when setup is missing.</summary>
    [Test]
    procedure MissingSetupIsCreatedBySetupPage()
    var
        Setup: Record "Projects Setup ori";
        BifrostPage: TestPage "Bifrost ori";
        SetupPage: TestPage "Projects Setup ori";
    begin
        // [GIVEN] The company has no Projects setup yet.
        Setup.DeleteAll();
        BifrostPage.OpenView();
        SetupPage.Trap();
        // [WHEN] The Related action is invoked.
        BifrostPage.ProjectsSetup.Invoke();
        // [THEN] The normal setup page opens and initializes its singleton.
        Assert.IsTrue(SetupPage.Enabled.Visible(), 'The Projects setup page must open');
        Assert.IsTrue(Setup.Get(), 'The setup page must initialize missing setup');
        Assert.RecordCount(Setup, 1);
        SetupPage.Close();
        BifrostPage.Close();
    end;

    local procedure VerifyExistingSetup(LanguageId: Integer)
    var
        Setup: Record "Projects Setup ori";
        BifrostPage: TestPage "Bifrost ori";
        SetupPage: TestPage "Projects Setup ori";
        SavedLanguage: Integer;
    begin
        // [GIVEN] Existing disabled setup and the requested user language.
        Setup.InsertIfNotExists();
        Setup.Enabled := false;
        Setup.Modify();
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BifrostPage.OpenView();
        Assert.IsTrue(BifrostPage.ProjectsSetup.Visible(), 'The setup entry must be visible');
        SetupPage.Trap();
        // [WHEN] The action is invoked from the read-only Bifröst page.
        BifrostPage.ProjectsSetup.Invoke();
        // [THEN] The existing setup opens without changing the company switch.
        SetupPage.Enabled.AssertEquals(false);
        SetupPage.Close();
        BifrostPage.Close();
        Setup.Get();
        Assert.IsFalse(Setup.Enabled, 'Opening setup must preserve existing settings');
        GlobalLanguage(SavedLanguage);
    end;
}
