namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.WIP;
using Microsoft.Sales.History;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue 75 reversal, atomic refusal, confirmation and bilingual contract regression tests.</summary>
codeunit 97114 "Projects WIP Reverse Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>Reverses real native WIP postings and preserves every calculated record.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC01_AC02_PostedWIP_ReversesAndPreservesCalculation()
    var
        Entry: Record "Job WIP G/L Entry";
        GL: Record "G/L Entry";
        Request: JsonObject;
        Before: JsonObject;
        Response: JsonObject;
        Snapshot: Text;
        AfterSnapshot: Text;
        AccountNo: Code[20];
    begin
        // Story #75, AC01/AC02 | Time: fixed 2026-10-16 | Risk: native WIP posting only
        Request := PostedRequest();
        Before := ReadWIP(Request);
        Snapshot := CalculationSnapshot(Request);
        Assert.IsTrue(Before.GetArray('entries').Count() > 0, 'Unposted calculated WIP must exist before testing preservation');
        Request.Add('expectedCount', CandidateCount(Request));
        Request.Replace('documentNo', 'X75-REVERSE');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(Before.GetArray('glEntries').Count(), Response.GetArray('reversedEntries').Count(), 'Every posted candidate is returned');
        Assert.AreEqual('Projects.WIP.Calculate', Response.GetText('nextStep'), 'Recalculate next');
        Entry.SetRange("Job No.", Request.GetText('projectNo'));
        Entry.SetRange(Reversed, false);
        Assert.AreEqual(0, Entry.Count(), 'All posted WIP is reversed');
        GL.SetRange("Document No.", 'X75-REVERSE');
        Assert.IsTrue(GL.Count() > 0, 'Actual correcting general ledger entries exist');
        AccountNo := CopyStr(Request.GetText('projectNo'), 1, 20);
        AssertZeroBalance(AccountNo);
        AssertZeroBalance(CopyStr('Y' + AccountNo, 1, 20));
        AfterSnapshot := CalculationSnapshot(Request);
        Assert.AreEqual(Snapshot, AfterSnapshot, 'Every calculated WIP field and row remains unchanged');
        Assert.AreEqual(Format(Before.GetArray('entries')), Format(Response.GetObject('wip').GetArray('entries')), 'WIP response uses the Get shape');
        Library.RemoveOwnedWIPDimensions();
    end;

    /// <summary>Rejects a repeat reversal without posting again.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC03_AlreadyReversed_PreconditionFailed()
    var
        Request: JsonObject;
    begin
        // Story #75, AC03 | Time: fixed 2026-10-16 | Risk: None
        Request := PostedRequest();
        Request.Add('expectedCount', CandidateCount(Request));
        Library.AssertStatus(Execute(Request), 'Success');
        AssertUnchangedRefusal(Request, 'PreconditionFailed');
    end;

    /// <summary>Rejects an earlier reversal date with the native reason and rolls back all writes.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC03_EarlierDate_NativeReasonAndNoWrites()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #75, AC03 | Time: one day before native posting | Risk: rollback boundary
        Request := PostedRequest();
        Request.Add('expectedCount', CandidateCount(Request));
        Request.Replace('postingDate', '2026-10-15');
        Response := AssertUnchangedRefusal(Request, 'PreconditionFailed');
        Assert.IsTrue(Response.GetText('error').Contains(Request.GetText('projectNo')), 'Native date refusal identifies the project');
        Assert.AreEqual('Projects.WIP.Get', Response.GetText('nextStep'), 'Read WIP before retry');
    end;

    /// <summary>Refuses a project with no posted WIP.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC03_NoPostedWIP_PreconditionFailed()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #75, AC03 | Time: fixed 2026-10-16 | Risk: None
        Request := NewRequest();
        Response := AssertUnchangedRefusal(Request, 'PreconditionFailed');
        Assert.AreEqual('Projects.WIP.Get', Response.GetText('nextStep'), 'Inspect WIP next');
    end;

    /// <summary>Refuses the native completed-WIP no-op instead of claiming reversal.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC03_CompletedWIP_PreconditionFailed()
    var
        Entry: Record "Job WIP G/L Entry";
        Request: JsonObject;
    begin
        // Story #75, AC03 | Time: fixed 2026-10-16 | Risk: native silent no-op
        Request := PostedRequest();
        Entry.SetRange("Job No.", Request.GetText('projectNo'));
        Entry.FindFirst();
        Entry."Job Complete" := true;
        Entry.Modify();
        Request.Add('expectedCount', CandidateCount(Request));
        AssertUnchangedRefusal(Request, 'PreconditionFailed');
    end;

    /// <summary>Unknown project is a typed refusal before confirmation.</summary>
    [Test]
    procedure Scenario_AC04_UnknownProject_RecordNotFound()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request.Add('projectNo', 'X75-NOT-FOUND');
        Request.Add('postingDate', '2026-10-16');
        Request.Add('documentNo', 'X75');
        AssertUnchangedRefusal(Request, 'RecordNotFound');
    end;

    /// <summary>Refuses MissingPostingDate before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_MissingPostingDate_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Remove('postingDate');
        AssertUnchangedRefusal(Request, 'MissingParameter');
    end;

    /// <summary>Refuses InvalidPostingDate before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_InvalidPostingDate_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Replace('postingDate', 'not-a-date');
        AssertUnchangedRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Refuses UnknownKey before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_UnknownKey_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Add('recalculate', true);
        AssertUnchangedRefusal(Request, 'UnknownParameter');
    end;

    /// <summary>Refuses EmptyDocumentNo before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_EmptyDocumentNo_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Replace('documentNo', '');
        AssertUnchangedRefusal(Request, 'MissingParameter');
    end;

    /// <summary>Refuses LongDocumentNo before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_LongDocumentNo_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Replace('documentNo', PadStr('X', 21, 'X'));
        AssertUnchangedRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Refuses FractionalCount before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_FractionalCount_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Add('expectedCount', 1.5);
        AssertUnchangedRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Refuses NegativeCount before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_NegativeCount_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Add('expectedCount', -1);
        AssertUnchangedRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Refuses StringCount before any financial change.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC04_StringCount_Refused()
    var
        Request: JsonObject;
    begin
        // Story #75, AC04 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Add('expectedCount', '1');
        AssertUnchangedRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Returns the posted-entry count without any write.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC05_MissingCount_ConfirmationRequired()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #75, AC05 | Time: fixed date | Risk: Foundation confirmation enabled by default
        Request := PostedRequest();
        Response := AssertUnchangedRefusal(Request, 'ConfirmationRequired');
        Assert.AreEqual(Format(CandidateCount(Request), 0, 9), Response.GetText('expected'), 'Preview counts posted entries, not projects');
    end;

    /// <summary>Rejects a stale count without reversing anything.</summary>
    [Test]
    [HandlerFunctions('DeclineDimensionUpdate')]
    procedure Scenario_AC05_WrongCount_ConfirmationMismatch()
    var
        Request: JsonObject;
    begin
        // Story #75, AC05 | Time: fixed date | Risk: None
        Request := PostedRequest();
        Request.Add('expectedCount', CandidateCount(Request) + 1);
        AssertUnchangedRefusal(Request, 'ConfirmationMismatch');
    end;

    /// <summary>Read role plus native write permissions cannot pass the posting gate.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC06_ReadRole_PermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. WIP Reverse Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #75, AC06 | Time: no dates | Risk: no permission elevation
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('Proj Gate Test ori');
        Lower.AddPermissionSet('All Objects');
        Assert.IsFalse(Impl.IsEnabled(), 'Read role never advertises reversal');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Refusal precedes licence checks');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Permission refusal gives actionable guidance');
    end;

    /// <summary>No native permissions refuses before accessing project data.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC06_NoNativePermission_PermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. WIP Reverse Impl ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #75, AC06 | Time: no dates | Risk: no native grants in product role
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Assert.IsFalse(Impl.IsEnabled(), 'Missing native permissions hide reversal');
        TempArgument.Insert(true);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Missing native permissions refuse');
        Assert.IsTrue(Response.GetText('nextStep').Contains('BIFROST Full ori'), 'Native permission refusal gives actionable guidance');
    end;

    /// <summary>English chapters stay identical while discovery changes with session language.</summary>
    [Test]
    procedure Scenario_AC07_Bilingual_EnglishHelpLocalizedDiscovery()
    var
        Impl: Codeunit "Proj. WIP Reverse Impl ori";
        EnglishOverview: Text;
        IcelandicOverview: Text;
        EnglishDescription: Text;
        OldLanguage: Integer;
    begin
        // Story #75, AC07 | Time: none | Risk: session language restored
        OldLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Impl.GetOverview(EnglishOverview);
        EnglishDescription := Impl.GetDescription();
        GlobalLanguage(1039);
        Impl.GetOverview(IcelandicOverview);
        Assert.AreEqual(EnglishOverview, IcelandicOverview, 'Help chapters remain English');
        Assert.AreNotEqual(EnglishDescription, Impl.GetDescription(), 'Discovery is Icelandic');
        GlobalLanguage(OldLanguage);
    end;

    /// <summary>Preserves the owned dimension fixture without updating unrelated records.</summary>
    [ConfirmHandler]
    procedure DeclineDimensionUpdate(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := false;
    end;

    local procedure NewRequest(): JsonObject
    var
        Fixture: Codeunit "Proj. WIP Reverse Fixture ori";
    begin
        exit(Fixture.Seed(true));
    end;

    local procedure PostedRequest() Request: JsonObject
    begin
        Request := NewRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request), 'Success');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Post", Request), 'Success');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request), 'Success');
        Assert.IsTrue(CandidateCount(Request) > 1, 'Fixture distinguishes entry count from project count');
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    begin
        exit(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Reverse", Request));
    end;

    local procedure ReadWIP(Request: JsonObject): JsonObject
    var
        ReadRequest: JsonObject;
    begin
        ReadRequest.Add('projectNo', Request.GetText('projectNo'));
        exit(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Get", ReadRequest));
    end;

    local procedure CandidateCount(Request: JsonObject): Integer
    var
        Entry: Record "Job WIP G/L Entry";
    begin
        Entry.SetRange("Job No.", Request.GetText('projectNo'));
        Entry.SetRange(Reverse, true);
        Entry.SetRange(Reversed, false);
        exit(Entry.Count());
    end;

    local procedure AssertUnchangedRefusal(Request: JsonObject; CodeText: Text) Response: JsonObject
    var
        GL: Record "G/L Entry";
        Before: JsonObject;
        GLCount: Integer;
    begin
        Before := ReadWIP(Request);
        GLCount := GL.Count();
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(CodeText, Response.GetText('code'), Format(Response));
        Assert.AreEqual(GLCount, GL.Count(), 'No general ledger entry is posted');
        Assert.AreEqual(Format(Before), Format(ReadWIP(Request)), 'WIP state is unchanged');
    end;

    local procedure AssertZeroBalance(AccountNo: Code[20])
    var
        GL: Record "G/L Entry";
    begin
        GL.SetRange("G/L Account No.", AccountNo);
        GL.CalcSums(Amount);
        Assert.AreEqual(0, GL.Amount, 'Owned WIP account returns to zero: ' + AccountNo);
    end;

    local procedure CalculationSnapshot(Request: JsonObject) Result: Text
    var
        Entry: Record "Job WIP Entry";
        Ref: RecordRef;
        Field: FieldRef;
        FieldIndex: Integer;
    begin
        Entry.SetRange("Job No.", Request.GetText('projectNo'));
        if Entry.FindSet() then
            repeat
                Ref.GetTable(Entry);
                for FieldIndex := 1 to Ref.FieldCount() do begin
                    Field := Ref.FieldIndex(FieldIndex);
                    if Field.Class = Field.Class::Normal then
                        Result += Format(Field.Value, 0, 9) + '|';
                end;
                Ref.Close();
            until Entry.Next() = 0;
    end;
}
