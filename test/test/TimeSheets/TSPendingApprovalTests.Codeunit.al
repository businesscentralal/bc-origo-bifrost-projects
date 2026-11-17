namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Acceptance tests for caller isolation, read-only projection, filters and refusals.</summary>
codeunit 97149 "TS Pending Approval Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        IsInitialized: Boolean;

    /// <summary>Verifies Scenario AC01 SubmittedForCaller ReturnsDailyHoursOnly.</summary>
    [Test]
    procedure Scenario_AC01_SubmittedForCaller_ReturnsDailyHoursOnly()
    var
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        // [GIVEN] Our submitted project/absence lines plus open and foreign lines.
        Initialize();
        Request.Add('resourceNo', 'TS62-REGINN');
        // [WHEN] The authenticated manager queries pending lines.
        Response := Execute(Request);
        Lines := Response.GetArray('lines');
        // [THEN] Only the two submitted lines, with daily and contextual fields, are returned.
        Assert.AreEqual(2, Lines.Count(), 'Caller sees exactly two submitted lines.');
        Lines.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual('TS62-A', Row.GetText('timeSheetNo'), 'Owned sheet.');
        Assert.AreEqual('TS62-PROJECT', Row.GetText('projectNo'), 'Project preserved.');
        Assert.AreEqual('TS62-TASK', Row.GetText('taskNo'), 'Task preserved.');
        Assert.AreEqual(7, Row.GetDecimal('totalHours'), '3 + 4 hours.');
        Assert.AreEqual(2, Row.GetArray('days').Count(), 'Both daily details.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'All matching lines returned.');
        Lines.Get(1, Token);
        Assert.AreEqual('TS62', Token.AsObject().GetText('causeOfAbsenceCode'), 'Absence context.');
        AssertUnchanged();
    end;

    /// <summary>Verifies Scenario AC01 DateAndTypeFilters RestrictHours.</summary>
    [Test]
    procedure Scenario_AC01_DateAndTypeFilters_RestrictHours()
    var
        Request: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
    begin
        Initialize();
        Request.Add('resourceNo', 'TS62-REGINN');
        Request.Add('from', '2026-11-03');
        Request.Add('to', '2026-11-03');
        Request.Add('type', 'Job');
        Lines := Execute(Request).GetArray('lines');
        Assert.AreEqual(1, Lines.Count(), 'Only project line.');
        Lines.Get(0, Token);
        Assert.AreEqual(4, Token.AsObject().GetDecimal('totalHours'), 'Only the selected day.');
        Assert.AreEqual(1, Token.AsObject().GetArray('days').Count(), 'One day.');
        AssertUnchanged();
    end;

    /// <summary>Verifies Scenario AC01 Paging PreservesStableOrder.</summary>
    [Test]
    procedure Scenario_AC01_Paging_PreservesStableOrder()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Initialize();
        Request.Add('resourceNo', 'TS62-REGINN');
        Request.Add('take', 1);
        Response := Execute(Request);
        Assert.IsTrue(Response.GetBoolean('hasMore'), 'Second submitted line exists.');
        Response.GetArray('lines').Get(0, Token);
        Assert.AreEqual(10000, Token.AsObject().GetInteger('lineNo'), 'First line.');
        Request.Add('skip', 1);
        Response := Execute(Request);
        Response.GetArray('lines').Get(0, Token);
        Assert.AreEqual(30000, Token.AsObject().GetInteger('lineNo'), 'Next submitted line; open line omitted.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'Last page.');
    end;

    /// <summary>Verifies Scenario AC01 ResourceSystemId ResolvesSameResource.</summary>
    [Test]
    procedure Scenario_AC01_ResourceSystemId_ResolvesSameResource()
    var
        Resource: Record Resource;
        Request: JsonObject;
    begin
        Initialize();
        Resource.Get('TS62-REGINN');
        Request.Add('resourceId', Resource.SystemId);
        Assert.AreEqual(2, Execute(Request).GetArray('lines').Count(), 'SystemId resolves.');
    end;

    /// <summary>Verifies Scenario AC04 ConflictingResources Refuses.</summary>
    [Test]
    procedure Scenario_AC04_ConflictingResources_Refuses()
    var
        Resource: Record Resource;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize();
        Resource.Get('TS62-OTHER');
        Request.Add('resourceNo', 'TS62-REGINN');
        Request.Add('resourceId', Resource.SystemId);
        Response := Execute(Request);
        Assert.AreEqual('ConflictingIdentifiers', Response.GetText('code'), 'Conflicting resources.');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Corrective next step.');
        AssertUnchanged();
    end;

    /// <summary>Verifies Scenario AC05 NoApprovals ReturnsEmptySuccess.</summary>
    [Test]
    procedure Scenario_AC05_NoApprovals_ReturnsEmptySuccess()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize();
        Request.Add('resourceNo', 'TS62-OTHER');
        Response := Execute(Request);
        Assert.AreEqual('Success', Response.GetText('status'), 'Empty is success.');
        Assert.AreEqual(0, Response.GetArray('lines').Count(), 'Foreign manager lines never leak.');
    end;

    /// <summary>Verifies Scenario AC05 AfterLastPage ReturnsEmptySuccess.</summary>
    [Test]
    procedure Scenario_AC05_AfterLastPage_ReturnsEmptySuccess()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize();
        Request.Add('resourceNo', 'TS62-REGINN');
        Request.Add('skip', 2147483647);
        Response := Execute(Request);
        Assert.AreEqual(0, Response.GetArray('lines').Count(), 'Past end.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'No more lines.');
    end;

    /// <summary>Verifies Scenario AC03 ReversedDates RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC03_ReversedDates_RefusesWithoutWrites()
    begin
        AssertRefusal('{"from":"2026-11-04","to":"2026-11-02"}', 'InvalidParameter', 'Use from <= to.');
    end;

    /// <summary>Verifies Scenario AC04 MissingTo RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_MissingTo_RefusesWithoutWrites()
    begin
        AssertRefusal('{"from":"2026-11-02"}', 'MissingParameter', '');
    end;

    /// <summary>Verifies Scenario AC04 MissingFrom RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_MissingFrom_RefusesWithoutWrites()
    begin
        AssertRefusal('{"to":"2026-11-02"}', 'MissingParameter', '');
    end;

    /// <summary>Verifies Scenario AC04 WrongDateType RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_WrongDateType_RefusesWithoutWrites()
    begin
        AssertRefusal('{"from":12,"to":"2026-11-02"}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 BadDate RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_BadDate_RefusesWithoutWrites()
    begin
        AssertRefusal('{"from":"2026-02-30","to":"2026-11-02"}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 UnknownKey RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_UnknownKey_RefusesWithoutWrites()
    begin
        AssertRefusal('{"approver":"FOREIGN"}', 'UnknownParameter', '');
    end;

    /// <summary>Verifies Scenario AC04 UnknownResource RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_UnknownResource_RefusesWithoutWrites()
    begin
        AssertRefusal('{"resourceNo":"TS62-MISSING"}', 'RecordNotFound', '');
    end;

    /// <summary>Verifies Scenario AC04 BadResourceId RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_BadResourceId_RefusesWithoutWrites()
    begin
        AssertRefusal('{"resourceId":"invalid"}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 BooleanTake RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_BooleanTake_RefusesWithoutWrites()
    begin
        AssertRefusal('{"take":true}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 TextSkip RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_TextSkip_RefusesWithoutWrites()
    begin
        AssertRefusal('{"skip":"1"}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 NegativeSkip RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_NegativeSkip_RefusesWithoutWrites()
    begin
        AssertRefusal('{"skip":-1}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 FractionalTake RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_FractionalTake_RefusesWithoutWrites()
    begin
        AssertRefusal('{"take":1.5}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 ExcessiveTake RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_ExcessiveTake_RefusesWithoutWrites()
    begin
        AssertRefusal('{"take":1001}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 ZeroTake RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_ZeroTake_RefusesWithoutWrites()
    begin
        AssertRefusal('{"take":0}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 NullType RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_NullType_RefusesWithoutWrites()
    begin
        AssertRefusal('{"type":null}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC04 UnknownType RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_UnknownType_RefusesWithoutWrites()
    begin
        AssertRefusal('{"type":"Not a type"}', 'InvalidParameterFormat', '');
    end;

    /// <summary>Verifies Scenario AC07 AC09 AC10 Contract DiscoverableAndLocalized.</summary>
    [Test]
    procedure Scenario_AC07_AC09_AC10_Contract_DiscoverableAndLocalized()
    var
        Impl: Codeunit "TS Pending Approval ori";
        Contract: Codeunit "Msg Contract Mgt ori";
        Content: JsonObject;
        DescriptionEn: Text;
        EnglishContract: JsonObject;
        IcelandicContract: JsonObject;
        Request: JsonObject;
        Refusal: JsonObject;
        Language: Integer;
    begin
        // [GIVEN] The registered three-part type.
        Assert.AreEqual(3, 'Projects.PendingApproval.Get'.Split('.').Count(), 'Three parts.');
        Assert.IsTrue(Contract.GetContract("Message Type ori"::"Projects.PendingApproval.Get", Content), 'Discoverable contract.');
        Assert.AreEqual(7, Content.GetArray('parameters').Count(), 'Seven declared keys.');
        Language := GlobalLanguage();
        GlobalLanguage(1033);
        DescriptionEn := Impl.GetDescription();
        Assert.IsTrue(Contract.GetContract("Message Type ori"::"Projects.PendingApproval.Get", EnglishContract), 'English contract.');
        GlobalLanguage(1039);
        Assert.IsTrue(DescriptionEn <> Impl.GetDescription(), 'Localized description.');
        // [THEN] Gunnar option B keeps chapters English and catalogue/refusals Icelandic.
        Assert.IsTrue(Contract.GetContract("Message Type ori"::"Projects.PendingApproval.Get", IcelandicContract), 'Contract in Icelandic session.');
        Assert.AreEqual(1039, GlobalLanguage(), 'Contract must restore caller language.');
        Assert.AreEqual(EnglishContract.GetText('overview'), IcelandicContract.GetText('overview'), 'Overview stays English.');
        Assert.AreEqual(Format(EnglishContract.GetArray('parameters')), Format(IcelandicContract.GetArray('parameters')), 'Parameter chapter stays English.');
        Assert.AreEqual(Format(EnglishContract.GetArray('errors')), Format(IcelandicContract.GetArray('errors')), 'Refusal documentation stays English.');
        Request.Add('from', '2026-11-04');
        Request.Add('to', '2026-11-03');
        Refusal := Execute(Request);
        Assert.AreEqual('InvalidParameter', Refusal.GetText('code'), 'Stable refusal code in Icelandic session.');
        Assert.AreEqual('Notaðu from <= to.', Refusal.GetText('nextStep'), 'Actual refusal next step is Icelandic.');
        GlobalLanguage(Language);
    end;

    local procedure Initialize()
    var
        Fixture: Codeunit "TS Pending Fixture ori";
    begin
        if IsInitialized then
            exit;
        // Runs without test isolation keep committed data: remove only the fixed TS62 keys of an earlier run before seeding.
        Fixture.Cleanup();
        Fixture.Seed();
        IsInitialized := true;
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "TS Pending Approval ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Type" := "Message Type ori"::"Projects.PendingApproval.Get";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        Impl.ExecuteBifrostTask(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure AssertRefusal(RequestText: Text; ExpectedCode: Text; NextStep: Text)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] Native fixtures plus an invalid request.
        Initialize();
        Request.ReadFrom(RequestText);
        // [WHEN] The implementation validates the request.
        Response := Execute(Request);
        // [THEN] A typed, actionable refusal occurs and all fixtures remain unchanged.
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), 'Stable refusal code.');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Next step provided.');
        if NextStep <> '' then
            Assert.AreEqual(NextStep, Response.GetText('nextStep'), 'Exact next step.');
        AssertUnchanged();
    end;

    local procedure AssertUnchanged()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
    begin
        Header.SetFilter("No.", 'TS62-A|TS62-B');
        Line.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Detail.SetFilter("Time Sheet No.", 'TS62-A|TS62-B');
        Assert.AreEqual(2, Header.Count(), 'Header count unchanged.');
        Assert.AreEqual(4, Line.Count(), 'Line count unchanged.');
        Assert.AreEqual(8, Detail.Count(), 'Detail count unchanged.');
        Line.Get('TS62-A', 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Pending status unchanged.');
    end;
}
