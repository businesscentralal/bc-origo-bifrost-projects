namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Issue64 owner, input, copy/planning, permissions and atomicity regressions.</summary>
codeunit 97146 "TS Fill Sheet Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Checks every public CopyFromPrevious help chapter in language 1033 for internal transaction details.</summary>
    [Test]
    procedure CopyHelp1033_HidesInternalParameters()
    begin
        // [GIVEN] The localized public contract for the fill operation.
        // [WHEN] Every chapter and parameter is inspected.
        // [THEN] Internal transaction flags are absent.
        AssertPublicFillContract("Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", 1033);
    end;

    /// <summary>Checks every public CopyFromPrevious help chapter in language 1039 for internal transaction details.</summary>
    [Test]
    procedure CopyHelp1039_HidesInternalParameters()
    begin
        // [GIVEN] The localized public contract for the fill operation.
        // [WHEN] Every chapter and parameter is inspected.
        // [THEN] Internal transaction flags are absent.
        AssertPublicFillContract("Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", 1039);
    end;

    /// <summary>Checks every public CreateFromPlanning help chapter in language 1033 for internal transaction details.</summary>
    [Test]
    procedure PlanningHelp1033_HidesInternalParameters()
    begin
        // [GIVEN] The localized public contract for the fill operation.
        // [WHEN] Every chapter and parameter is inspected.
        // [THEN] Internal transaction flags are absent.
        AssertPublicFillContract("Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", 1033);
    end;

    /// <summary>Checks every public CreateFromPlanning help chapter in language 1039 for internal transaction details.</summary>
    [Test]
    procedure PlanningHelp1039_HidesInternalParameters()
    begin
        // [GIVEN] The localized public contract for the fill operation.
        // [WHEN] Every chapter and parameter is inspected.
        // [THEN] Internal transaction flags are absent.
        AssertPublicFillContract("Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", 1039);
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_MissingKey_IsMissingParameter()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_NotOwner_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), 'OTHER');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'PermissionDenied', 'timeSheetNo', 'Ask the owner.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'A refused copy must not add lines.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_NoPreviousSheet_IsPreconditionFailed()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'timeSheetNo', 'Add lines by hand.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'A missing previous sheet must not add lines.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_EmptyPrevious_ReturnsZero()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        CurrentNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        ResourceNo := CreateResource(true);
        CreateSheet(ResourceNo, WorkDate() - 14, UserId());
        CurrentNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        Request.Add('timeSheetNo', CurrentNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'An empty previous sheet should succeed.');
        Assert.AreEqual('0', ReadText(Response, 'copied'), 'Nothing to copy should answer zero lines.');
        Line.SetRange("Time Sheet No.", CurrentNo);
        Assert.IsTrue(Line.IsEmpty(), 'An empty previous sheet must not add lines.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_PreviousLine_IsCopied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        PreviousNo: Code[20];
        CurrentNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        ResourceNo := CreateResource(true);
        PreviousNo := CreateSheet(ResourceNo, WorkDate() - 14, UserId());
        CreateLine(PreviousNo, 10000, 'Open');
        Line.Get(PreviousNo, 10000);
        Line.Description := 'W17 copy source';
        Line.Modify(false);
        CurrentNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        Request.Add('timeSheetNo', CurrentNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Copy should succeed.');
        Assert.AreNotEqual('0', ReadText(Response, 'copied'), 'The copied count should be above zero.');
        Line.SetRange("Time Sheet No.", CurrentNo);
        Assert.IsFalse(Line.IsEmpty(), 'The previous line should be copied onto the current sheet.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC02_Planning_NotOwner_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), 'OTHER');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'PermissionDenied', 'timeSheetNo', 'Ask the owner.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'A refused planning call must not add lines.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC02_Planning_NoLines_ReturnsZero()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'No planning lines should still succeed.');
        Assert.AreEqual('0', ReadText(Response, 'created'), 'No planning lines should create zero lines.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'Nothing should be written.');
    end;


    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC02_Planning_JobLine_IsCreated()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Job: Record Job;
        JobTask: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        Line: Record "Time Sheet Line";
        LibraryJob: Codeunit "Library - Job";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
    begin
        // Story #64, AC01/AC02/AC03/AC04/AC06 | Time: WorkDate defines fixture weeks | Risk: None
        ResourceNo := CreateResource(true);
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        LibraryTimeSheet.CreateJobPlanningLine(PlanningLine, Job."No.", JobTask."Job Task No.", ResourceNo, WorkDate());
        PlanningLine.Validate("Line Type", PlanningLine."Line Type"::"Both Budget and Billable");
        PlanningLine.Modify(true);
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Create from planning should succeed.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Job);
        Line.SetRange("Job No.", Job."No.");
        Assert.IsFalse(Line.IsEmpty(), 'The planning line should become a time sheet line.');
    end;


    local procedure Execute(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
    var
        MsgInterface: Interface "Msg Interface ori";
    begin
        TempArgument.DeleteAll();
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument."Type" := MessageType;
        TempArgument."Version" := TempArgument."Version"::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(RequestJson);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        Commit(); // Fixtures must be visible to the isolated native transaction.
        MsgInterface.ExecuteBifrostTask(TempArgument);
    end;


    local procedure AssertRefusal(var TempArgument: Record "Message Argument ori" temporary; ExpectedCode: Text; ExpectedParameter: Text; ExpectedNext: Text)
    var
        Response: JsonObject;
    begin
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'The call should be refused.');
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(ExpectedParameter, ReadText(Response, 'parameter'), 'Refusal parameter.');
        Assert.AreEqual(ExpectedNext, ReadText(Response, 'nextStep'), 'Refusal next step.');
    end;


    local procedure ReadText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
        Nested: Text;
    begin
        if not Response.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        Token.WriteTo(Nested);
        exit(Nested);
    end;


    local procedure CreateResource(UseTimeSheet: Boolean): Code[20]
    var
        Resource: Record Resource;
        UnitOfMeasure: Record "Unit of Measure";
        LibraryResource: Codeunit "Library - Resource";
    begin
        EnsureUserSetup();
        LibraryResource.CreateResourceNew(Resource);
        if Resource.Type <> Resource.Type::Person then
            Resource.Validate(Type, Resource.Type::Person);
        if Resource."Base Unit of Measure" = '' then begin
            if not UnitOfMeasure.Get('HOUR') then begin
                UnitOfMeasure.Init();
                UnitOfMeasure.Code := 'HOUR';
                UnitOfMeasure.Description := 'Hour';
                UnitOfMeasure.Insert(true);
            end;
            Resource.Validate("Base Unit of Measure", UnitOfMeasure.Code);
        end;
        Resource.Validate("Use Time Sheet", UseTimeSheet);
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Modify(true);
        exit(Resource."No.");
    end;


    local procedure EnsureUserSetup()
    var
        UserSetup: Record "User Setup";
    begin
        // Standard approve and reject read User Setup for the caller before they compare the line approver.
        if UserSetup.Get(UserId()) then
            exit;
        UserSetup.Init();
        UserSetup.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID")));
        UserSetup.Insert(true);
    end;


    local procedure CreateSheet(ResourceNo: Code[20]; StartingDate: Date; Owner: Text): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := CopyStr('W17' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := StartingDate;
        Header."Ending Date" := StartingDate + 6;
        Header."Owner User ID" := CopyStr(Owner, 1, MaxStrLen(Header."Owner User ID"));
        Header."Approver User ID" := CopyStr(Owner, 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert(false);
        exit(Header."No.");
    end;


    local procedure CreateLine(SheetNo: Code[20]; LineNo: Integer; StatusName: Text)
    var
        Line: Record "Time Sheet Line";
        Header: Record "Time Sheet Header";
    begin
        Header.Get(SheetNo);
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := LineNo;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        case StatusName of
            'Submitted':
                Line.Status := Line.Status::Submitted;
            'Approved':
                Line.Status := Line.Status::Approved;
            else
                Line.Status := Line.Status::Open;
        end;
        Line.Insert(false);
    end;




    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC01_Copy_EmptyHoursAndChronologicalSource()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        CurrentNo: Code[20];
        OldestNo: Code[20];
        PreviousNo: Code[20];
    begin
        // Story #64, AC01/AC06 | Time: WorkDate defines relative weeks | Risk: native copy normally copies hours
        // [GIVEN] The lexically last sheet is older than the immediately preceding sheet.
        ResourceNo := CreateResource(true);
        OldestNo := CreateSheet(ResourceNo, WorkDate() - 21, UserId());
        Header.Get(OldestNo);
        Header.Rename(CopyStr('Z' + OldestNo, 1, 20));
        PreviousNo := CreateSheet(ResourceNo, WorkDate() - 7, UserId());
        Header.Get(PreviousNo);
        Header.Rename(CopyStr('A' + PreviousNo, 1, 20));
        PreviousNo := Header."No.";
        CreateLine(PreviousNo, 10000, 'Open');
        Detail.Init();
        Detail."Time Sheet No." := PreviousNo;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := WorkDate() - 7;
        Detail.Quantity := 8;
        Detail.Insert(false);
        CurrentNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        CreateLine(CurrentNo, 10000, 'Open');
        // [WHEN] Copy selects the immediately preceding sheet, not the oldest empty one.
        Request.Add('timeSheetNo', CurrentNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        Response := TempArgument.GetResponseJson();
        // [THEN] Only the new line is reported; existing line and source hours are preserved.
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Copy should succeed.');
        Assert.AreEqual('1', ReadText(Response, 'copied'), 'Exactly one new line.');
        Assert.AreEqual(1, Response.GetArray('lines').Count(), 'Response excludes the existing line.');
        Line.Get(CurrentNo, 20000);
        Detail.SetRange("Time Sheet No.", CurrentNo);
        Assert.IsTrue(Detail.IsEmpty(), 'Copied lines must have no daily hours.');
        Detail.Reset();
        Detail.Get(PreviousNo, 10000, WorkDate() - 7);
        Assert.AreEqual(8, Detail.Quantity, 'Source hours are untouched.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC08_Copy_LateValidationFailureRollsBackAllLines()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Context: Codeunit "TS Fill Context ori";
        Request: JsonObject;
        ResourceNo: Code[20];
        PreviousNo: Code[20];
        CurrentNo: Code[20];
    begin
        // Story #64, AC08 | Time: WorkDate defines relative weeks | Risk: failure after first native insert
        // [GIVEN] A valid first line followed by an invalid project line.
        ResourceNo := CreateResource(true);
        PreviousNo := CreateSheet(ResourceNo, WorkDate() - 7, UserId());
        CreateLine(PreviousNo, 10000, 'Open');
        CreateLine(PreviousNo, 20000, 'Open');
        Line.Get(PreviousNo, 20000);
        Line.Type := Line.Type::Job;
        Line."Job No." := 'NO-SUCH-64';
        Line.Modify(false);
        CurrentNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        Request.Add('timeSheetNo', CurrentNo);
        // [WHEN] The second native copy fails validation.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        // [THEN] The response is clean and the first insert was also rolled back.
        AssertRefusal(TempArgument, 'BusinessCentralError', '', 'Check the time sheet and source lines in Business Central, then retry.');
        Line.SetRange("Time Sheet No.", CurrentNo);
        Assert.IsTrue(Line.IsEmpty(), 'A late failure must roll back every added line.');
        Assert.IsFalse(Context.IsCopyDestination(CurrentNo), 'Failure must clear session copy state.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC02_Planning_PeriodResourceAndDuplicateFiltering()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Job: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Detail: Record "Time Sheet Detail";
        LibraryJob: Codeunit "Library - Job";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        OtherResource: Code[20];
        SheetNo: Code[20];
    begin
        // Story #64, AC02/AC06 | Time: WorkDate through WorkDate+6 inclusive | Risk: None
        // [GIVEN] In-period, out-of-period and other-resource planning lines.
        ResourceNo := CreateResource(true);
        OtherResource := CreateResource(true);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, Task);
        LibraryTimeSheet.CreateJobPlanningLine(Planning, Job."No.", Task."Job Task No.", ResourceNo, WorkDate());
        LibraryJob.CreateJobTask(Job, Task);
        LibraryTimeSheet.CreateJobPlanningLine(Planning, Job."No.", Task."Job Task No.", ResourceNo, WorkDate() + 7);
        LibraryJob.CreateJobTask(Job, Task);
        LibraryTimeSheet.CreateJobPlanningLine(Planning, Job."No.", Task."Job Task No.", OtherResource, WorkDate());
        Request.Add('timeSheetNo', SheetNo);
        // [WHEN] The same request runs twice.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Planning should succeed.');
        Assert.AreEqual('1', ReadText(Response, 'created'), 'Only the matching resource and period is included.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        Response := TempArgument.GetResponseJson();
        // [THEN] Native duplicate detection creates nothing a second time; hours are empty.
        Assert.AreEqual('0', ReadText(Response, 'created'), 'Existing project/task must not be duplicated.');
        Assert.AreEqual(0, Response.GetArray('lines').Count(), 'No existing lines in response.');
        Detail.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Detail.IsEmpty(), 'Planning must leave daily hours empty.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC07_ReadRole_CannotEnableOrExecuteEitherWrite()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Impl: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Types: List of [Enum "Message Type ori"];
        Request: JsonObject;
    begin
        // Story #64, AC07 | Time: none | Risk: ensure Read extension grants no write access
        // [GIVEN] Only the Foundation Read role, including the feature's read extension.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Types.Add("Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious");
        Types.Add("Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning");
        foreach MessageType in Types do begin
            Impl := MessageType;
            // [WHEN/THEN] Discovery and direct execution both refuse the write.
            Assert.IsFalse(Impl.IsEnabled(), 'Read role must not enable a write.');
            Execute(TempArgument, MessageType, Request);
            AssertRefusal(TempArgument, 'PermissionDenied', '', 'Assign the BIFROST Full ori and PROJ TS ADMIN permission sets.');
        end;
    end;

    /// <summary>#65: the Icelandic refusal for both fill types names BIFROST Full ori and PROJ TS ADMIN.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_65_ReadRole_RefusalHintIsIcelandic()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        MessageType: Enum "Message Type ori";
        Types: List of [Enum "Message Type ori"];
        Request: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] Only the Foundation Read role and an Icelandic session.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Types.Add("Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious");
        Types.Add("Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        foreach MessageType in Types do begin
            // [WHEN] The write is executed directly.
            Execute(TempArgument, MessageType, Request);
            // [THEN] The localized next step names both permission sets.
            AssertRefusal(TempArgument, 'PermissionDenied', '', 'Úthlutaðu heimildasamstæðunum BIFROST Full ori og PROJ TS ADMIN.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC08_OmitCommit_RefusesBeforeNativeWrites()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Impl: Interface "Msg Interface ori";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #64, AC08 | Time: WorkDate | Risk: caller transaction must never be committed
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning";
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument."Omit Commit" := true;
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        Commit();
        Impl := TempArgument.Type;
        Impl.ExecuteBifrostTask(TempArgument);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'omitCommit', 'Run this action outside an uncommitted batch.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'Refusal must not write lines.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC08_GenericInsert_IsRestrictedIncludingForce()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Ref: RecordRef;
    begin
        // Story #64, AC08 | Time: none | Risk: public Foundation restriction event contract
        Ref.GetTable(Line);
        Assert.IsTrue(TempArgument.IsTableInsertRestrictedForDataRecords(Database::"Time Sheet Line", Ref, false, false), 'Generic line insertion must be restricted.');
        Assert.IsTrue(TempArgument.IsTableInsertRestrictedForDataRecords(Database::"Time Sheet Line", Ref, true, true), 'Force must not bypass feature restriction.');
        Assert.IsTrue(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Line").Contains('Projects.TimeSheetLine.CopyFromPrevious'), 'Hint must name the dedicated type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Missing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_WrongType()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":7}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Null()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":null}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Object()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":{}}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Unknown()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64","unknown":true}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'UnknownParameter', 'unknown', 'Remove the unknown key.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_NotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'timeSheetNo', 'Use an identifier that exists.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Conflicting()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64","timeSheetId":"00000000-0000-0000-0000-000000000000"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'timeSheetNo', 'Send only one identifier for the time sheet.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_InvalidId()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetId":"not-a-guid"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetId', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Copy_Overlong()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"123456789012345678901"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Missing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_WrongType()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":7}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Null()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":null}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Object()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":{}}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Unknown()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64","unknown":true}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'UnknownParameter', 'unknown', 'Remove the unknown key.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_NotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'timeSheetNo', 'Use an identifier that exists.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Conflicting()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"NO-SUCH-64","timeSheetId":"00000000-0000-0000-0000-000000000000"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'timeSheetNo', 'Send only one identifier for the time sheet.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_InvalidId()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetId":"not-a-guid"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetId', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies the issue64 acceptance scenario named by this test.</summary>
    [Test]
    procedure Scenario_AC05_Planning_Overlong()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #64, AC05 | Time: none | Risk: None
        // [GIVEN/WHEN] Invalid request; [THEN] actionable structured refusal.
        Request.ReadFrom('{"timeSheetNo":"123456789012345678901"}');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;
    /// <summary>Creates isolated, uniquely named fixtures for shipping MCP/UI verification in an owned test company.</summary>
    /// <param name="OwnerUserId">The authenticated verification user's existing BC user name.</param>
    procedure SeedMcpFixtures(OwnerUserId: Text)
    var
        Header: Record "Time Sheet Header";
        Resource: Record Resource;
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        Detail: Record "Time Sheet Detail";
        LibraryResource: Codeunit "Library - Resource";
        LibraryJob: Codeunit "Library - Job";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        PreviousNo: Code[20];
    begin
        if CompanyName() <> 'CRONUS LONI64 Verification' then
            Error('Run the fixture only in the worker-owned CRONUS LONI64 Verification company.');
        if Header.Get('LONI64-COPY') or Resource.Get('LONI64-RES') then
            Error('Fixture already exists. Inspect it instead of replaying setup.');
        LibraryResource.CreateResourceNew(Resource);
        Resource.Rename('LONI64-RES');
        Resource."Time Sheet Owner User ID" := CopyStr(OwnerUserId, 1, 50);
        Resource."Time Sheet Approver User ID" := CopyStr(OwnerUserId, 1, 50);
        Resource.Validate("Use Time Sheet", true);
        Resource.Modify(true);
        PreviousNo := CreateNamedSheet('LONI64-PREV', Resource."No.", DMY2Date(26, 10, 2026), OwnerUserId);
        CreateLine(PreviousNo, 10000, 'Open');
        Detail.Init();
        Detail."Time Sheet No." := PreviousNo;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := DMY2Date(26, 10, 2026);
        Detail.Quantity := 8;
        Detail.Insert(false);
        CreateNamedSheet('LONI64-COPY', Resource."No.", DMY2Date(2, 11, 2026), OwnerUserId);
        CreateNamedSheet('LONI64-PLAN', Resource."No.", DMY2Date(9, 11, 2026), OwnerUserId);
        CreateNamedSheet('LONI64-OTHER', Resource."No.", DMY2Date(16, 11, 2026), 'LONI64-NOT-OWNER');
        LibraryJob.CreateJob(Job);
        Job.Rename('LONI64-JOB');
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryTimeSheet.CreateJobPlanningLine(Planning, Job."No.", JobTask."Job Task No.", Resource."No.", DMY2Date(9, 11, 2026));
        LibraryResource.CreateResourceNew(Resource);
        Resource.Rename('LONI64-EMPTY');
        Resource."Time Sheet Owner User ID" := CopyStr(OwnerUserId, 1, 50);
        Resource."Time Sheet Approver User ID" := CopyStr(OwnerUserId, 1, 50);
        Resource.Validate("Use Time Sheet", true);
        Resource.Modify(true);
        CreateNamedSheet('LONI64-NOPREV', Resource."No.", DMY2Date(2, 11, 2026), OwnerUserId);
        CreateNamedSheet('LONI64-ZERO', Resource."No.", DMY2Date(9, 11, 2026), OwnerUserId);
    end;

    local procedure CreateNamedSheet(NewNo: Code[20]; ResourceNo: Code[20]; StartingDate: Date; OwnerUserId: Text): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Get(CreateSheet(ResourceNo, StartingDate, OwnerUserId));
        Header.Rename(NewNo);
        exit(Header."No.");
    end;
    local procedure AssertPublicFillContract(MessageType: Enum "Message Type ori"; LanguageId: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        ParametersToken: JsonToken;
        ParameterToken: JsonToken;
        NameToken: JsonToken;
        InternalToken: JsonToken;
        ContractText: Text;
        PreviousLanguage: Integer;
        HasContract: Boolean;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        HasContract := ContractMgt.GetContract(MessageType, Contract);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(HasContract, 'The fill type must have a public contract.');
        Contract.WriteTo(ContractText);
        Assert.IsFalse(LowerCase(ContractText).Contains('omitcommit'), 'No chapter may expose omitCommit.');
        Assert.IsTrue(Contract.Get('parameters', ParametersToken), 'The public parameters must be present.');
        Assert.IsTrue(ParametersToken.AsArray().Count() > 0, 'The parameter check must not be empty.');
        foreach ParameterToken in ParametersToken.AsArray() do begin
            Assert.IsTrue(ParameterToken.AsObject().Get('name', NameToken), 'Each parameter has a public name.');
            Assert.IsFalse(LowerCase(NameToken.AsValue().AsText()).Contains('omitcommit'), 'omitCommit is internal.');
            if ParameterToken.AsObject().Get('internalOnly', InternalToken) then
                Assert.IsFalse(InternalToken.AsValue().AsBoolean(), 'No public parameter may be internal-only.');
        end;
    end;

}
