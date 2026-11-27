namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #115: every Projects message type carries is-IS search phrases that reach the catalogue description.</summary>
codeunit 97199 "Proj. Is-IS Search Test ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_EveryProjectsType_HasIcelandicKeywordsInDescription()
    var
        Impl: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Keywords: List of [Text];
        Name: Text;
        Keyword: Text;
        EnglishKeywords: Text;
        Description: Text;
        OriginalLanguage: Integer;
        Found: Boolean;
        Count: Integer;
    begin
        // Issue #115 | Time: no date dependency | Risk: catalogue grows in later issues
        OriginalLanguage := GlobalLanguage();
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        foreach Name in Names do
            if (Ordinals.Get(Names.IndexOf(Name)) >= 70013400) and (Ordinals.Get(Names.IndexOf(Name)) <= 70013599) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(Name)));
                Impl := MessageType;
                Discovery := MessageType;
                GlobalLanguage(1033);
                EnglishKeywords := Discovery.GetKeywords();
                GlobalLanguage(1039);
                Assert.AreNotEqual('', Discovery.GetKeywords(), 'Icelandic keywords missing for ' + Name);
                Assert.AreNotEqual(EnglishKeywords, Discovery.GetKeywords(), 'Icelandic keywords copy the English list for ' + Name);
                Description := LowerCase(Impl.GetDescription());
                Assert.IsTrue(StrLen(Description) <= 250, 'Icelandic description exceeds 250 characters for ' + Name);
                Keywords := LowerCase(Discovery.GetKeywords()).Split(',');
                Found := false;
                foreach Keyword in Keywords do
                    if (DelChr(Keyword, '<>', ' ') <> '') and Description.Contains(DelChr(Keyword, '<>', ' ')) then
                        Found := true;
                Assert.IsTrue(Found, 'Icelandic description contains none of the Icelandic keywords for ' + Name);
                Count += 1;
            end;
        GlobalLanguage(OriginalLanguage);
        Assert.IsTrue(Count > 0, 'No Projects message type was checked');
    end;

    [Test]
    procedure Scenario_Amend_SharedEnglishKeywords_KeepTypeSpecificIcelandicPhrases()
    var
        OriginalLanguage: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        AssertKeywords("Message Type ori"::"Projects.Project.Create", 'verkefni, verk, verkhluti, áætlunarlína, stofna, nýtt verkefni, stofna verkefni');
        AssertKeywords("Message Type ori"::"Projects.PlanningLine.Create", 'verkefni, verk, verkhluti, áætlunarlína, stofna, áætlunarlínur verkefna');
        AssertKeywords("Message Type ori"::"Projects.Task.Create", 'verkefni, verk, verkhluti, áætlunarlína, stofna, nýja verkhluta');
        AssertKeywords("Message Type ori"::"Projects.PlanningLine.Update", 'verkefni, verk, verkhluti, áætlunarlína, uppfæra, áætlunarlínur verkefna');
        AssertKeywords("Message Type ori"::"Projects.Task.Update", 'verkefni, verk, verkhluti, áætlunarlína, uppfæra, verkhluta verkefnis');
        AssertKeywords("Message Type ori"::"Projects.Project.Update", 'verkefni, verk, verkhluti, áætlunarlína, uppfæra, verkefnishaus');
        GlobalLanguage(OriginalLanguage);
    end;

    [Test]
    procedure Scenario_Amend_TimeSheetSelection_MatchesCatalogueInBothLanguages()
    var
        OriginalLanguage: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        AssertTimeSheetSelections();
        GlobalLanguage(1039);
        AssertTimeSheetSelections();
        GlobalLanguage(OriginalLanguage);
    end;

    local procedure AssertKeywords(MessageType: Enum "Message Type ori"; Expected: Text)
    var
        Discovery: Interface "Msg Discovery ori";
    begin
        Discovery := MessageType;
        Assert.AreEqual(Expected, Discovery.GetKeywords(), 'Keywords must belong to this message type.');
    end;

    local procedure AssertTimeSheetSelections()
    begin
        AssertSelection("Message Type ori"::"Projects.TimeSheetLine.Set", 'Projects.TimeSheetLine.Set');
        AssertSelection("Message Type ori"::"Projects.TimeSheet.Submit", 'Projects.TimeSheet.Submit');
        AssertSelection("Message Type ori"::"Projects.TimeSheet.Approve", 'Projects.TimeSheet.Approve');
    end;

    local procedure AssertSelection(MessageType: Enum "Message Type ori"; Name: Text)
    var
        Impl: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
    begin
        Impl := MessageType;
        Discovery := MessageType;
        Assert.AreEqual(Name + ': ' + Impl.GetDescription(), Discovery.GetSelectionDescription(), 'Selection and catalogue descriptions must match.');
    end;

}
