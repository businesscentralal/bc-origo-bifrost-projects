namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Issue 61: public message implementation, native report, refusal and atomicity regression tests.</summary>
codeunit 97144 "TS Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Defaults create one sheet with native owner and approver fields.</summary>
    [Test]
    procedure Scenario_AC01_Defaults_CreateNativeHeader()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC01 | Time: fixed Monday 2030-01-07 | Risk: native report setup.
        Initialize();
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        Response := Execute(Request, true);
        AssertSuccess(Response, 1, 0);
        Header.SetRange("Resource No.", ResourceNo);
        Header.FindFirst();
        Assert.AreEqual(20300107D, Header."Starting Date", 'Start date.');
        Assert.AreEqual(20300113D, Header."Ending Date", 'End date.');
        Assert.AreEqual(UserId(), Header."Owner User ID", 'Native owner validation.');
        Assert.AreEqual(UserId(), Header."Approver User ID", 'Native approver validation.');
    end;

    /// <summary>Each chosen resource and period is represented once.</summary>
    [Test]
    procedure Scenario_AC01_ResourceList_CreatesEveryPeriod()
    var
        Request: JsonObject;
        Resources: JsonArray;
    begin
        // Story #61 AC01 | Time: fixed Monday | Risk: None.
        Initialize();
        Resources.Add(CreateResource(true));
        Resources.Add(CreateResource(true));
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNos', Resources);
        Request.Add('numberOfPeriods', 2);
        AssertSuccess(Execute(Request, true), 4, 0);
    end;

    /// <summary>A resource group selects only its own members.</summary>
    [Test]
    procedure Scenario_AC01_ResourceGroup_ExcludesOtherResources()
    var
        Resource: Record Resource;
        ResourceGroup: Record "Resource Group";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        OtherResource: Code[20];
    begin
        // Story #61 AC01 | Time: fixed Monday | Risk: None.
        Initialize();
        ResourceGroup."No." := NewCode();
        ResourceGroup.Insert(true);
        Resource.Get(CreateResource(true));
        Resource.Validate("Resource Group No.", ResourceGroup."No.");
        Resource.Modify(true);
        OtherResource := CreateResource(true);
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceGroup', ResourceGroup."No.");
        AssertSuccess(Execute(Request, true), 1, 0);
        Header.SetRange("Resource No.", OtherResource);
        Assert.IsTrue(Header.IsEmpty(), 'Unselected resource must remain untouched.');
    end;

    /// <summary>Planning creation uses native project and task validation.</summary>
    [Test]
    procedure Scenario_AC01_PlanningOption_CreatesJobLine()
    var
        Job: Record Job;
        JobTask: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        LibraryJob: Codeunit "Library - Job";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC01 | Time: planning within fixed week | Risk: native planning integration.
        Initialize();
        ResourceNo := CreateResource(true);
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryTimeSheet.CreateJobPlanningLine(PlanningLine, Job."No.", JobTask."Job Task No.", ResourceNo, 20300108D);
        Request := RequestFor(ResourceNo);
        Request.Add('createLinesFromPlanning', true);
        AssertSuccess(Execute(Request, true), 1, 0);
        Header.SetRange("Resource No.", ResourceNo);
        Header.FindFirst();
        Line.SetRange("Time Sheet No.", Header."No.");
        Line.FindFirst();
        Assert.AreEqual(Line.Type::Job, Line.Type, 'Native line type.');
        Assert.AreEqual(Job."No.", Line."Job No.", 'Native job.');
        Assert.AreEqual(JobTask."Job Task No.", Line."Job Task No.", 'Native job task.');
    end;

    /// <summary>The configured weekday is named and no sheet is inserted.</summary>
    [Test]
    procedure Scenario_AC02_WrongWeekday_WritesNothing()
    var
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC02 | Time: Tuesday instead of Monday | Risk: None.
        Initialize();
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        Request.Replace('startingDate', '2030-01-08');
        AssertRefusal(Execute(Request, true), 'PreconditionFailed', 'Use the first weekday named in the refusal.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>A missing member invalidates the entire list, even after a valid member.</summary>
    [Test]
    procedure Scenario_AC03_MixedMissingResource_WritesNothing()
    var
        Request: JsonObject;
        Resources: JsonArray;
        ResourceNo: Code[20];
    begin
        // Story #61 AC03 | Time: fixed Monday | Risk: historical filter silently omitted missing members.
        Initialize();
        ResourceNo := CreateResource(true);
        Resources.Add(ResourceNo);
        Resources.Add('X-MISSING-61');
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNos', Resources);
        AssertRefusal(Execute(Request, true), 'RecordNotFound', 'Turn on Use Time Sheet on the resource.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>A resource not enabled for time sheets cannot be selected.</summary>
    [Test]
    procedure Scenario_AC03_DisabledResource_WritesNothing()
    var
        ResourceNo: Code[20];
    begin
        // Story #61 AC03 | Time: fixed Monday | Risk: None.
        Initialize();
        ResourceNo := CreateResource(false);
        AssertRefusal(Execute(RequestFor(ResourceNo), true), 'RecordNotFound', 'Turn on Use Time Sheet on the resource.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>Filter metacharacters are literal identifiers and cannot widen the selection.</summary>
    [Test]
    procedure Scenario_AC03_WildcardIdentifier_DoesNotSelectAll()
    var
        ResourceNo: Code[20];
    begin
        // Story #61 AC03 | Time: fixed Monday | Risk: historical SetFilter injection.
        Initialize();
        ResourceNo := CreateResource(true);
        AssertRefusal(Execute(RequestFor('*'), true), 'RecordNotFound', 'Turn on Use Time Sheet on the resource.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>The upper boundary succeeds; one above refuses.</summary>
    [Test]
    procedure Scenario_AC04_PeriodBounds_52Succeeds53Refuses()
    var
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC04 | Time: 52 weeks starting 2030-01-07 | Risk: boundary arithmetic.
        Initialize();
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        Request.Add('numberOfPeriods', 53);
        AssertRefusal(Execute(Request, true), 'LimitExceeded', 'Split the call.');
        AssertNoSheet(ResourceNo);
        Request.Replace('numberOfPeriods', 52);
        AssertSuccess(Execute(Request, true), 52, 0);
    end;

    /// <summary>Numbers outside Integer do not overflow before the upper limit refusal.</summary>
    [Test]
    procedure Scenario_AC04_HugePeriodCount_ReturnsLimit()
    var
        Request: JsonObject;
    begin
        // Story #61 AC04 | Time: fixed Monday | Risk: integer conversion overflow.
        Initialize();
        Request.ReadFrom('{"startingDate":"2030-01-07","resourceNo":"X","numberOfPeriods":2147483648}');
        AssertRefusal(Execute(Request, true), 'LimitExceeded', 'Split the call.');
    end;

    /// <summary>Common refusal contract includes actionable next steps.</summary>
    [Test]
    procedure Scenario_AC05_CommonInputs_ReturnStructuredRefusals()
    var
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC05 | Time: fixed Monday | Risk: None.
        Initialize();
        AssertRefusal(Execute(Request, true), 'MissingParameter', 'Send the missing key.');
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        Request.Replace('startingDate', 123);
        AssertRefusal(Execute(Request, true), 'InvalidParameterFormat', 'Send the key with the documented type.');
        Request := RequestFor(ResourceNo);
        Request.Add('unknown', true);
        AssertRefusal(Execute(Request, true), 'UnknownParameter', 'Remove the unknown key.');
        Request := RequestFor(ResourceNo);
        Request.Add('resourceGroup', 'XGROUP');
        AssertRefusal(Execute(Request, true), 'ConflictingIdentifiers', 'Send only one of resourceNo, resourceNos or resourceGroup.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>Optional fields reject coercion, fractional periods and empty identifiers.</summary>
    [Test]
    procedure Scenario_AC05_OptionalTypes_RejectCoercion()
    var
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC05 | Time: fixed Monday | Risk: JSON coercion.
        Initialize();
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        Request.Add('createLinesFromPlanning', 'true');
        AssertRefusal(Execute(Request, true), 'InvalidParameterFormat', 'Send the key with the documented type.');
        Request := RequestFor(ResourceNo);
        Request.Add('numberOfPeriods', 1.5);
        AssertRefusal(Execute(Request, true), 'InvalidParameterFormat', 'Send the key with the documented type.');
        Request.Replace('numberOfPeriods', 0);
        AssertRefusal(Execute(Request, true), 'InvalidParameter', 'Send a number from 1 to 52.');
        Request := RequestFor('');
        AssertRefusal(Execute(Request, true), 'InvalidParameterFormat', 'Send the key with the documented type.');
        AssertNoSheet(ResourceNo);
    end;

    /// <summary>Second call returns the existing sheet unchanged under skipped.</summary>
    [Test]
    procedure Scenario_AC06_ExistingPeriod_IsSkipped()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #61 AC06 | Time: fixed Monday | Risk: duplicate creation.
        Initialize();
        ResourceNo := CreateResource(true);
        Request := RequestFor(ResourceNo);
        AssertSuccess(Execute(Request, true), 1, 0);
        Header.SetRange("Resource No.", ResourceNo);
        Header.FindFirst();
        Header.Description := 'X-keep existing description';
        Header.Modify();
        AssertSuccess(Execute(Request, true), 0, 1);
        Header.FindFirst();
        Assert.AreEqual('X-keep existing description', Header.Description, 'Existing sheets stay unchanged.');
        Assert.AreEqual(1, Header.Count(), 'Only one sheet.');
    end;

    /// <summary>Repeated resources in one list are deduplicated.</summary>
    [Test]
    procedure Scenario_AC06_DuplicateResource_IsCreatedOnce()
    var
        Request: JsonObject;
        Resources: JsonArray;
        ResourceNo: Code[20];
    begin
        // Story #61 AC06 | Time: fixed Monday | Risk: duplicate identifiers.
        Initialize();
        ResourceNo := CreateResource(true);
        Resources.Add(ResourceNo);
        Resources.Add(ResourceNo);
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNos', Resources);
        AssertSuccess(Execute(Request, true), 1, 0);
    end;

    /// <summary>Foundation events restrict generic writes while preserving reads.</summary>
    [Test]
    procedure Scenario_AC08_GenericHeaderWrite_IsRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // Story #61 AC08 | Time: independent | Risk: subscriber wiring.
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Header", false), 'Generic header write must be restricted.');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Time Sheet Header"), 'Header read remains available.');
        Assert.AreEqual('Projects.TimeSheet.Create', TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Header"), 'Dedicated type hint.');
    end;

    /// <summary>Native report errors roll the complete multi-resource batch back and return clean JSON.</summary>
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC09_SecondResourceFails_RollsBackBatch()
    var
        Resource: Record Resource;
        Request: JsonObject;
        Resources: JsonArray;
        FirstResource: Code[20];
        SecondResource: Code[20];
    begin
        // Story #61 AC09 | Time: fixed Monday | Risk: partial report writes and transaction boundary.
        Initialize();
        FirstResource := CreateResource(true);
        SecondResource := CreateResource(true);
        Resource.Get(SecondResource);
        Resource."Time Sheet Approver User ID" := '';
        Resource.Modify();
        Resources.Add(FirstResource);
        Resources.Add(SecondResource);
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNos', Resources);
        Commit();
        AssertRefusal(Execute(Request, false), 'BusinessCentralError', 'Check the resource owners, approvers, numbering and open accounting periods, then retry.');
        AssertNoSheet(FirstResource);
        AssertNoSheet(SecondResource);
        Resource.Get(FirstResource);
        Resource.Delete(true);
        Resource.Get(SecondResource);
        Resource.Delete(true);
    end;

    /// <summary>Both locales produce different translated purpose and refusal text.</summary>
    [Test]
    procedure Scenario_AC10_Contract_HasIcelandicText()
    var
        Contract: Codeunit "TS Create Contract ori";
        English: Text;
        Icelandic: Text;
        PreviousLanguage: Integer;
    begin
        // Story #61 AC10 | Time: independent | Risk: contract literals bypass translations.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Contract.GetOverview(English);
        GlobalLanguage(1039);
        Clear(Contract);
        Contract.GetOverview(Icelandic);
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Icelandic contract must translate the overview.');
        Assert.IsTrue(Icelandic.Contains('tímaskýrslur'), 'Icelandic purpose.');
    end;

    /// <summary>The create response describes success in the selected language (#106).</summary>
    [Test]
    procedure Scenario_106_ResponseStatus_IsTranslated()
    var
        Contract: Codeunit "TS Create Contract ori";
        Response: JsonObject;
        Field: JsonToken;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.IsTrue(Contract.GetResponse(Response), 'English response chapter.');
        Response.GetArray('fields').Get(0, Field);
        Assert.AreEqual('Success.', Field.AsObject().GetText('description'), 'English status description.');
        Clear(Response);
        GlobalLanguage(1039);
        Assert.IsTrue(Contract.GetResponse(Response), 'Icelandic response chapter.');
        Response.GetArray('fields').Get(0, Field);
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Tókst.', Field.AsObject().GetText('description'), 'Icelandic status description.');
    end;

    local procedure Initialize()
    var
        ResourcesSetup: Record "Resources Setup";
        UserSetup: Record "User Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        AccountingPeriod: Record "Accounting Period";
    begin
        if not ResourcesSetup.Get() then begin
            ResourcesSetup.Init();
            ResourcesSetup.Insert();
        end;
        ResourcesSetup."Time Sheet First Weekday" := ResourcesSetup."Time Sheet First Weekday"::Monday;
        NoSeries.Code := NewCode();
        NoSeries."Default Nos." := true;
        NoSeries.Insert();
        NoSeriesLine."Series Code" := NoSeries.Code;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine."Starting No." := CopyStr(NoSeries.Code, 1, 12) + '000001';
        NoSeriesLine."Increment-by No." := 1;
        NoSeriesLine.Open := true;
        NoSeriesLine.Insert();
        ResourcesSetup."Time Sheet Nos." := NoSeries.Code;
        ResourcesSetup.Modify();
        if not UserSetup.Get(UserId()) then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert();
        end;
        UserSetup."Time Sheet Admin." := true;
        UserSetup.Modify();
        if not AccountingPeriod.Get(20300101D) then begin
            AccountingPeriod.Init();
            AccountingPeriod."Starting Date" := 20300101D;
            AccountingPeriod.Insert();
        end;
        AccountingPeriod.Closed := false;
        AccountingPeriod.Modify();
    end;

    local procedure CreateResource(UsesSheets: Boolean): Code[20]
    var
        Resource: Record Resource;
    begin
        Resource.Init();
        Resource."No." := NewCode();
        Resource.Name := Resource."No.";
        Resource.Type := Resource.Type::Person;
        Resource."Use Time Sheet" := UsesSheets;
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Insert(true);
        exit(Resource."No.");
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X61' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure RequestFor(ResourceNo: Code[20]) Request: JsonObject
    begin
        Request.Add('startingDate', '2030-01-07');
        Request.Add('resourceNo', ResourceNo);
    end;

    local procedure Execute(Request: JsonObject; OmitCommit: Boolean): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Implementation: Interface "Msg Interface ori";
    begin
        // This is an API feature: exercise its registered interface, not an internal manager.
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.TimeSheet.Create";
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument."Omit Commit" := OmitCommit;
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        Implementation := TempArgument.GetMessageTypeInterface();
        Implementation.ExecuteBifrostTask(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure AssertSuccess(Response: JsonObject; Created: Integer; Skipped: Integer)
    var
        Token: JsonToken;
    begin
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), Format(Response));
        Response.Get('created', Token);
        Assert.AreEqual(Created, Token.AsArray().Count(), 'Created count.');
        Response.Get('skipped', Token);
        Assert.AreEqual(Skipped, Token.AsArray().Count(), 'Skipped count.');
    end;

    local procedure AssertRefusal(Response: JsonObject; ErrorCode: Text; NextStep: Text)
    var
        Token: JsonToken;
    begin
        Response.Get('status', Token);
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Refusal status.');
        Response.Get('code', Token);
        Assert.AreEqual(ErrorCode, Token.AsValue().AsText(), 'Refusal code.');
        Response.Get('nextStep', Token);
        Assert.AreEqual(NextStep, Token.AsValue().AsText(), 'Refusal next step.');
    end;

    local procedure AssertNoSheet(ResourceNo: Code[20])
    var
        Header: Record "Time Sheet Header";
    begin
        Header.SetRange("Resource No.", ResourceNo);
        Assert.IsTrue(Header.IsEmpty(), 'Refusal must not leave sheets.');
    end;
}
