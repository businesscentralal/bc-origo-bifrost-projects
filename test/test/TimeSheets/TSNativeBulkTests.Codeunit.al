namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Microsoft.Service.Document;
using Microsoft.Utilities;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.AccessControl;
using System.Security.User;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 67 acceptance tests for native Reopen, Post and Archive names.</summary>
codeunit 97147 "TS Native Bulk Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        GrantTok: Label '%1 %2 %3', Locked = true, Comment = '%1 = object type, %2 = object ID, %3 = granted levels';
        MovedTablesTok: Label '%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11|%12', Locked = true, Comment = '%1..%12 = table IDs';

    // [Test]
    // procedure LegacyArchive_WarnsToUseNativeName()
    // var
        // TempArgument: Record "Message Argument ori" temporary;
        // Request: JsonObject;
        // Response: JsonObject;
    // begin
        // Execute(TempArgument, "Message Type ori"::"Clockify.TimeSheet.Archive", Request);
        // Response := TempArgument.GetResponseJson();
        // Assert.AreEqual('Success', ReadText(Response, 'status'), 'The old archive name should still succeed.');
        // Assert.IsTrue(ReadText(Response, 'warnings').Contains('DeprecatedParameter'), 'The old name should warn DeprecatedParameter.');
        // Assert.IsTrue(ReadText(Response, 'warnings').Contains(GetExpectedNextStep('Use the native name.')), 'The warning next step should name the native name.');
    // end;

    [Test]
    procedure NativeArchive_HasNoLegacyWarning()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Archive", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'The native archive name should succeed.');
        Assert.AreEqual('', ReadText(Response, 'warnings'), 'The native name should not add the legacy warning.');
    end;

    [Test]
    procedure Scenario_AC04_ReopenWrongDate_RefusesWithoutWriting()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #67, AC04 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A boolean where the optional cutoff date belongs.
        Request.Add('endingDateTo', true);
        // [WHEN] The native message is executed.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] The type returns a structured refusal before starting the write runner.
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'endingDateTo', 'Send the key with the documented type.');
    end;

    [Test]
    procedure Scenario_AC04_PostWrongTemplate_RefusesWithoutWriting()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #67, AC04 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A numeric journal template.
        Request.Add('journalTemplate', 42);
        // [WHEN] The native message is executed.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] The numeric value is refused rather than coerced or truncated.
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'journalTemplate', 'Send the key with the documented type.');
    end;

    [Test]
    procedure Scenario_AC04_PostMissingTemplate_IsMissingParameter()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #33 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A batch without a template; Projects has no setup fallback.
        Request.Add('journalBatch', 'DEFAULT');
        // [WHEN] The native message is executed.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] The missing template is named.
        AssertRefusal(TempArgument, 'MissingParameter', 'journalTemplate', 'Send the missing key.');
    end;

    [Test]
    procedure Scenario_AC04_PostMissingBatch_IsMissingParameter()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #33 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A template without a batch.
        Request.Add('journalTemplate', 'JOB');
        // [WHEN] The native message is executed.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] The missing batch is named.
        AssertRefusal(TempArgument, 'MissingParameter', 'journalBatch', 'Send the missing key.');
    end;

    [Test]
    procedure Scenario_AC04_PostContract_RequiresJournalKeysAndNamesFullRole()
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Entry: JsonToken;
        FoundTemplate: Boolean;
        FoundBatch: Boolean;
    begin
        // Story #33 | Time: no date-dependent setup | Risk: None
        // [GIVEN] The published Post contract.
        Contract := "Message Type ori"::"Projects.TimeSheet.Post";
        Assert.IsTrue(Contract.GetParameters(Parameters), 'Post declares parameters.');
        // [THEN] Both journal keys are required.
        foreach Entry in Parameters do begin
            if Entry.AsObject().GetText('name') = 'journalTemplate' then begin
                FoundTemplate := true;
                Assert.IsTrue(Entry.AsObject().GetBoolean('required'), 'journalTemplate is required.');
            end;
            if Entry.AsObject().GetText('name') = 'journalBatch' then begin
                FoundBatch := true;
                Assert.IsTrue(Entry.AsObject().GetBoolean('required'), 'journalBatch is required.');
            end;
        end;
        Assert.IsTrue(FoundTemplate and FoundBatch, 'Both journal keys are declared.');
        // [THEN] The advertised role is the Foundation role the Projects extension grants.
        Contract.GetEffect(Effect);
        Assert.AreEqual('BIFROST Full ori, PROJ TS ADMIN', Effect.GetText('permissionSet'), 'The permission sets name the Foundation role and the Base App data set (#65).');
    end;

    /// <summary>Verifies platform posting confirmation reaches typed validation in the caller language without ledger writes.</summary>
    [Test]
    procedure Scenario_AC04_ConfirmedPost_InvalidTemplate_IsRefused()
    var
        LedgerEntry: Record "Job Ledger Entry";
        Dispatcher: Codeunit "Dispatcher ori";
        ResponseBlob: Codeunit "Temp Blob";
        RequestContent: BigText;
        Request: JsonObject;
        Response: JsonObject;
        RequestText: Text;
        ResponseContentType: Text[100];
        InitialLedgerCount: Integer;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        ResponseStream: InStream;
    begin
        // Story #67, AC04/AC07 | Time: none | Risk: Foundation confirmation must reach handler validation
        // [GIVEN] The platform's confirmed count and a deliberately invalid journal identifier type.
        InitialLedgerCount := LedgerEntry.Count();
        // The count is the real number of postable lines (#54); read it through the gate so the test does not depend on demo data.
        Request.Add('journalTemplate', 42);
        Request.Add('expectedCount', CountViaGate(1000000000, Response));
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        // [WHEN] The public dispatcher validates confirmation in the explicit caller language.
        // Execute uses the company default; this overload preserves the test session LCID.
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Projects.TimeSheet.Post", "Message Version ori"::"1.0", '', 'X67CONFIRM', 'application/json', RequestContent, EmptyTaskId, GlobalLanguage(), MessageId, ResponseBlob, ResponseContentType, ResponseTime, true);
        ResponseBlob.CreateInStream(ResponseStream);
        Response.ReadFrom(ResponseStream);
        // [THEN] The journal type is refused; the confirmed platform key is accepted and nothing is posted.
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'The invalid journal identifier must be refused.');
        Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Confirmation must reach journal validation.');
        Assert.AreEqual('journalTemplate', ReadText(Response, 'parameter'), 'The journal identifier is the invalid key.');
        Assert.AreEqual(GetExpectedNextStep('Send the key with the documented type.'), ReadText(Response, 'nextStep'), 'Keep the exact localized next step.');
        Assert.AreEqual(InitialLedgerCount, LedgerEntry.Count(), 'The refused post must not create ledger entries.');
    end;

    [Test]
    procedure Scenario_AC04_ArchiveUnknownKey_RefusesWithoutWriting()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #67, AC04 | Time: no date-dependent setup | Risk: None
        // [GIVEN] Archive has no supported parameters.
        Request.Add('extra', 'unexpected');
        // [WHEN] An unknown parameter is sent.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Archive", Request);
        // [THEN] Execution stops with the removable key named.
        AssertRefusal(TempArgument, 'UnknownParameter', 'extra', 'Remove the unknown key.');
    end;

    [Test]
    procedure Scenario_AC04_PostUnknownTemplate_ReturnsRecordNotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #67, AC04 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A random template that was not created.
        Request.Add('journalTemplate', CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 10));
        Request.Add('journalBatch', 'MISSING');
        // [WHEN] Posting resolves the journal identifiers.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] No raw Get failure escapes to the caller.
        AssertRefusal(TempArgument, 'RecordNotFound', 'journalTemplate', 'Use an identifier that exists.');
    end;

    [Test]
    procedure Scenario_AC01_ReopenSubmittedLine_ChangesItToOpen()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #67, AC01 | Time: WorkDate minus two weeks isolates the cutoff | Risk: bulk reopen
        // [GIVEN] An owned submitted line before the cutoff.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('endingDateTo', Format(WorkDate() - 8, 0, 9));
        // [WHEN] The native alias runs through its real implementation.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] The standard approval engine reopens the line.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Native reopen should succeed.');
        Assert.IsTrue(Response.Contains('reopenedLines'), 'Keep the existing response count.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Submitted line must be open.');
    end;

    [Test]
    procedure Scenario_AC01_ReopenPostedSubmittedLine_IsSkippedWithoutError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #33, AC04 | Time: WorkDate minus two weeks | Risk: posted lines abort the bulk run
        // [GIVEN] A posted line and an unposted submitted line before the cutoff.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        CreateLine(SheetNo, 20000, 'Submitted');
        Line.Get(SheetNo, 10000);
        Line.Posted := true;
        Line.Modify(false);
        Request.Add('endingDateTo', Format(WorkDate() - 8, 0, 9));
        // [WHEN] Reopening.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] The run succeeds, the posted line is untouched and the other line is open.
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Posted lines must not abort the reopen.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'The posted line is left alone.');
        Line.Get(SheetNo, 20000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'The unposted line is reopened.');
    end;

    [Test]
    procedure Scenario_AC05_ReopenOpenLine_LeavesItOpen()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #67, AC05 | Time: WorkDate minus two weeks | Risk: bulk reopen
        // [GIVEN] A line already in the target status.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('endingDateTo', Format(WorkDate() - 8, 0, 9));
        // [WHEN] Reopening the sheet.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] It remains open and the response retains the count field.
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Already-open line stays open.');
        Assert.IsTrue(TempArgument.GetResponseJson().Contains('reopenedLines'), 'Keep the existing response shape.');
    end;

    [Test]
    procedure Scenario_AC01_ReopenApprovedLine_ChangesItToOpenAndCountsOne()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #47, AC01 | Time: WorkDate minus two weeks isolates the cutoff | Risk: approved lines need two reopen steps
        // [GIVEN] An approved line before the cutoff and no other pending line on sheets ending before it.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Approved');
        Line.Get(SheetNo, 10000);
        // Standard Reopen checks the line approver against the caller (or a time-sheet administrator).
        Line."Approver ID" := CopyStr(UserId(), 1, MaxStrLen(Line."Approver ID"));
        Line.Modify(false);
        IsolateFromOtherPendingLines(SheetNo, WorkDate() - 8);
        Request.Add('endingDateTo', Format(WorkDate() - 8, 0, 9));
        // [WHEN] Reopening.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] The line is Open again and exactly one line was reopened.
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Reopening an approved line should succeed.');
        Assert.AreEqual('1', ReadText(TempArgument.GetResponseJson(), 'reopenedLines'), 'One approved line was reopened.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Approved line must be open.');
    end;

    [Test]
    procedure Scenario_AC02_ReopenOpenLine_StaysOpenAndCountsZero()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #47, AC02 | Time: WorkDate minus two weeks isolates the cutoff | Risk: open lines counted as reopened
        // [GIVEN] An open line before the cutoff and no pending line on other sheets.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Open');
        IsolateFromOtherPendingLines(SheetNo, WorkDate() - 8);
        Request.Add('endingDateTo', Format(WorkDate() - 8, 0, 9));
        // [WHEN] Reopening.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reopen", Request);
        // [THEN] The line stays Open and nothing was counted.
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Reopening an open line should succeed.');
        Assert.AreEqual('0', ReadText(TempArgument.GetResponseJson(), 'reopenedLines'), 'No line was reopened.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Open line stays open.');
    end;

    [Test]
    procedure Scenario_AC01_PostEmptyJournal_ReturnsSuccessCount()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #67, AC01 | Time: WorkDate | Risk: existing bulk posting semantics
        // [GIVEN] An owned journal template and batch.
        CreateNativeJournal(Request);
        // [WHEN] The native alias invokes the existing posting engine.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] Even an empty operation uses the old success shape.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Empty posting should succeed.');
        Assert.IsTrue(Response.Contains('postedLines'), 'Keep postedLines in the response.');
        Assert.IsFalse(Response.Contains('warnings'), 'The native name has no legacy-name warning.');
    end;

    [Test]
    procedure Scenario_AC05_PostUnknownBatch_ReturnsStructuredRefusal()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #67, AC05 | Time: no date-dependent setup | Risk: None
        // [GIVEN] A real template but an absent batch.
        CreateNativeJournal(Request);
        Request.Replace('journalBatch', 'MISSING');
        // [WHEN] The native message resolves the batch.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] The caller receives a corrective next step.
        AssertRefusal(TempArgument, 'RecordNotFound', 'journalBatch', 'Use an identifier that exists.');
    end;

    [Test]
    procedure Scenario_AC01_ArchivePostedSheet_MovesOwnedRecord()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        HeaderArchive: Record "Time Sheet Header Archive";
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #67, AC01 | Time: WorkDate minus two weeks meets archive cutoff | Risk: bulk archive
        // [GIVEN] An owned posted line on an old time sheet.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Approved');
        Line.Get(SheetNo, 10000);
        Line.Posted := true;
        Line.Modify(false);
        // [WHEN] The native alias calls the standard archive engine.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Archive", Request);
        // [THEN] The fixture is archived through the BC codeunit.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Archive should succeed.');
        Assert.IsFalse(Header.Get(SheetNo), 'Active sheet must be removed.');
        Assert.IsTrue(HeaderArchive.Get(SheetNo), 'Archive must contain the owned sheet.');
    end;

    [Test]
    procedure Scenario_AC05_ArchiveOpenSheet_LeavesOwnedRecord()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #67, AC05 | Time: WorkDate minus two weeks | Risk: bulk archive
        // [GIVEN] An old sheet with an open line must not be archived.
        SheetNo := CreateSheet(CreateResource(true), WorkDate() - 14, UserId());
        CreateLine(SheetNo, 10000, 'Open');
        // [WHEN] Archiving eligible sheets.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Archive", Request);
        // [THEN] The open fixture is preserved.
        Assert.IsTrue(Header.Get(SheetNo), 'Open sheet must remain active.');
        Assert.IsTrue(TempArgument.GetResponseJson().Contains('archived'), 'Keep the old count field.');
    end;

    [Test]
    procedure Scenario_AC01_PostApprovedJobDetail_CreatesLedgerEntry()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Batch: Record "Job Journal Batch";
        Job: Record Job;
        JobTask: Record "Job Task";
        LedgerEntry: Record "Job Ledger Entry";
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        LibraryJob: Codeunit "Library - Job";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
        Token: JsonToken;
    begin
        // Story #67, AC01/AC07 | Time: WorkDate for posting | Risk: real BC project posting path
        // [GIVEN] Self-created project, task, resource, journal and approved quantity.
        LibraryJob.CreateJob(Job);
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        LibraryJob.CreateJobTask(Job, JobTask);
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Approved');
        Line.Get(SheetNo, 10000);
        Line.Type := Line.Type::Job;
        Line."Job No." := Job."No.";
        Line."Job Task No." := JobTask."Job Task No.";
        Line.Modify(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := WorkDate();
        Detail.CopyFromTimeSheetLine(Line);
        Detail.Validate(Quantity, 2);
        Detail.Insert(true);
        CreateNativeJournal(Request);
        Request.Get('journalTemplate', Token);
        Batch."Journal Template Name" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Batch."Journal Template Name"));
        Request.Get('journalBatch', Token);
        Batch.Name := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Batch.Name));
        Batch.Get(Batch."Journal Template Name", Batch.Name);
        Series.Init();
        Series.Code := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Series.Code));
        Series."Default Nos." := true;
        Series.Insert(true);
        SeriesLine.Init();
        SeriesLine."Series Code" := Series.Code;
        SeriesLine."Line No." := 10000;
        SeriesLine."Starting No." := 'W467000001';
        SeriesLine."Ending No." := 'W467999999';
        SeriesLine."Increment-by No." := 1;
        SeriesLine.Insert(true);
        Batch.Validate("No. Series", Series.Code);
        Batch.Modify(true);
        // [WHEN] The native name invokes the actual project posting engine.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] A real posted entry and the corresponding time sheet posting exist.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Posting must succeed through the BC engine. ' + ReadText(Response, 'error') + ' ' + ReadText(Response, 'nextStep') + ' ' + GetLastErrorText());
        Response.Get('postedLines', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'One owned detail must actually post.');
        LedgerEntry.SetRange("Job No.", Job."No.");
        Assert.IsTrue(LedgerEntry.FindFirst(), 'A project ledger entry must be posted, not merely counted.');
        Assert.AreEqual(2, LedgerEntry.Quantity, 'Posted resource quantity must match the owned detail.');
        Detail.Get(SheetNo, 10000, WorkDate());
        Assert.IsTrue(Detail.Posted, 'The BC posting path must mark the time sheet detail posted.');
    end;

    /// <summary>#54: Post is irreversible and its help names the count unit and the side-effect-free preview, in English at 1033 and 1039.</summary>
    [Test]
    procedure Scenario_54_PostHelp_NamesCountUnitAndPreview_BothLanguages()
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Entry: JsonToken;
        PreviousLanguage: Integer;
        Language: Integer;
        Changes: Text;
        ParameterText: Text;
    begin
        PreviousLanguage := GlobalLanguage();
        Contract := "Message Type ori"::"Projects.TimeSheet.Post";
        Assert.IsTrue(ConfirmGate.IsConfirmRequired("Message Type ori"::"Projects.TimeSheet.Post"), 'Post stays irreversible.');
        for Language := 1 to 2 do begin
            if Language = 1 then
                GlobalLanguage(1033)
            else
                GlobalLanguage(1039);
            Clear(Effect);
            Clear(Parameters);
            Contract.GetEffect(Effect);
            Changes := Effect.GetText('changes');
            Assert.AreEqual('irreversible', Effect.GetText('effect'), 'Effect.');
            Assert.IsTrue(Changes.Contains('expectedCount counts the project journal lines the post creates'), 'effect.changes names the unit: ' + Changes);
            Assert.IsTrue(Changes.Contains('equals postedLines'), 'effect.changes ties the count to postedLines.');
            Assert.IsTrue(Changes.Contains('send the same request without expectedCount while confirmation is enabled and read expected'), 'effect.changes names the preview.');
            Contract.GetParameters(Parameters);
            ParameterText := '';
            foreach Entry in Parameters do
                if Entry.AsObject().GetText('name') = 'expectedCount' then begin
                    Assert.AreEqual('integer', Entry.AsObject().GetText('type'), 'expectedCount type.');
                    Assert.IsFalse(Entry.AsObject().GetBoolean('required'), 'expectedCount is optional.');
                    ParameterText := Entry.AsObject().GetText('description');
                end;
            Assert.IsTrue(ParameterText.StartsWith('expectedCount counts the project journal lines'), 'expectedCount carries the core#1378 marker and unit: ' + ParameterText);
            Assert.IsTrue(ParameterText.Contains('send the request without expectedCount and read expected'), 'expectedCount names the preview.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>#54: the gate counts the postable detail lines; a wrong count is refused with the real count and nothing posts, the right count passes.</summary>
    [Test]
    procedure Scenario_54_PostGate_CountsPostableLines()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Job: Record Job;
        JobTask: Record "Job Task";
        Line: Record "Time Sheet Line";
        ConfirmGate: Codeunit "Confirm Gate ori";
        LibraryJob: Codeunit "Library - Job";
        Request: JsonObject;
        Response: JsonObject;
        Before: Integer;
        SheetNo: Code[20];
    begin
        // [GIVEN] The count before and one more approved job detail of our own.
        Before := CountViaGate(0, Response);
        LibraryJob.CreateJob(Job);
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        LibraryJob.CreateJobTask(Job, JobTask);
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Approved');
        Line.Get(SheetNo, 10000);
        Line.Type := Line.Type::Job;
        Line."Job No." := Job."No.";
        Line."Job Task No." := JobTask."Job Task No.";
        Line.Modify(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := WorkDate();
        Detail.CopyFromTimeSheetLine(Line);
        Detail.Validate(Quantity, 2);
        Detail.Insert(true);
        // [WHEN] The gate runs with the old count.
        Clear(Response);
        // [THEN] It refuses and names the new count as expected; the preview needs no side effect.
        Assert.AreEqual(Before + 1, CountViaGate(Before, Response), 'The new approved detail adds exactly one line.');
        // [THEN] The matching count passes the gate.
        Request.Add('expectedCount', Before + 1);
        InitArgument(TempArgument, Request);
        Assert.IsTrue(ConfirmGate.Check(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post"), 'The matching count passes.');
        Detail.Get(SheetNo, 10000, WorkDate());
        Assert.IsFalse(Detail.Posted, 'The gate itself posts nothing.');
    end;

    /// <summary>#54: a negative expectedCount is refused as InvalidParameterFormat before any count is used.</summary>
    [Test]
    procedure Scenario_54_PostGate_NegativeCountRefused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        ConfirmGate: Codeunit "Confirm Gate ori";
        Request: JsonObject;
    begin
        Request.Add('expectedCount', -1);
        InitArgument(TempArgument, Request);
        Assert.IsFalse(ConfirmGate.Check(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post"), 'Negative count refused.');
        Assert.AreEqual('InvalidParameterFormat', ReadText(TempArgument.GetResponseJson(), 'code'), 'Code.');
    end;

    /// <summary>#54/#65: under the documented roles BIFROST Full ori and PROJ TS ADMIN (no SUPER) the gate runs the counter and answers ConfirmationMismatch with the real count instead of a raw permission error.</summary>
    [Test]
    procedure Scenario_54_PostGate_RunsUnderBifrostFullRole()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PermissionsMock: Codeunit "Permissions Mock";
        Request: JsonObject;
        Response: JsonObject;
        Passed: Boolean;
        Ran: Boolean;
        Expected: Integer;
        RoleCount: Integer;
    begin
        // [GIVEN] The real count, read with full test permissions, and a request with a count that cannot match.
        Expected := CountViaGate(1000000, Response);
        Request.Add('expectedCount', Expected + 1);
        InitArgument(TempArgument, Request);
        // [WHEN] The gate runs for a caller holding only BIFROST Full ori and PROJ TS ADMIN.
        PermissionsMock.Start();
        PermissionsMock.ClearAssignments();
        PermissionsMock.Assign('BIFROST Full ori');
        PermissionsMock.Assign('PROJ TS ADMIN');
        Ran := TryRunPostGate(TempArgument, Passed);
        PermissionsMock.Stop();
        // [THEN] Restore permissions first; the counter ran and the mismatch names the real count.
        Assert.IsTrue(Ran, 'The gate must run under BIFROST Full ori and PROJ TS ADMIN without a permission error: ' + GetLastErrorText());
        Assert.IsFalse(Passed, 'A wrong count must not pass the gate.');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('ConfirmationMismatch', ReadText(Response, 'code'), 'Code.');
        Evaluate(RoleCount, ReadText(Response, 'expected'));
        Assert.AreEqual(Expected, RoleCount, 'The role-scoped count must equal the full-permission count.');
    end;

    [TryFunction]
    local procedure TryRunPostGate(var TempArgument: Record "Message Argument ori" temporary; var Passed: Boolean)
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
    begin
        Passed := ConfirmGate.Check(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post");
    end;

    /// <summary>Sends a deliberately wrong count and returns the count the gate reports as expected.</summary>
    local procedure CountViaGate(WrongCount: Integer; var Response: JsonObject) Actual: Integer
    var
        TempArgument: Record "Message Argument ori" temporary;
        ConfirmGate: Codeunit "Confirm Gate ori";
        Request: JsonObject;
        Expected: Text;
    begin
        Request.Add('expectedCount', WrongCount);
        InitArgument(TempArgument, Request);
        if ConfirmGate.Check(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post") then begin
            Actual := WrongCount;
            exit;
        end;
        Response := TempArgument.GetResponseJson();
        Expected := ReadText(Response, 'expected');
        Evaluate(Actual, Expected);
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary; Request: JsonObject)
    begin
        TempArgument.DeleteAll();
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.TimeSheet.Post";
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
    end;

    [Test]
    procedure Scenario_AC04_PostOverlongTemplate_IsNotTruncated()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        JournalToken: JsonToken;
    begin
        // Story #67, AC04 | Time: not used | Risk: truncation must not address another journal
        // [GIVEN] A real ten-character template, followed by an extra character.
        CreateNativeJournal(Request);
        Request.Get('journalTemplate', JournalToken);
        Request.Replace('journalTemplate', JournalToken.AsValue().AsText() + 'X');
        // [WHEN] The overlong identifier is submitted.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Post", Request);
        // [THEN] It is refused rather than silently resolving to the existing prefix.
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'journalTemplate', 'Send the key with the documented type.');
    end;

    // [Test]
    // procedure Scenario_AC05_LegacyNames_PreserveNativeResponseFields()
    // var
        // Request: JsonObject;
    // begin
        // Story #67, AC05 | Time: old cutoff isolates reopen | Risk: both names can change records
        // [GIVEN] Valid requests for each old/native pair.
        // Request.Add('endingDateTo', '2020-01-01');
        // [WHEN/THEN] The success fields match, with warnings only on the old name.
        // AssertAliasCountField("Message Type ori"::"Clockify.TimeSheet.Reopen", "Message Type ori"::"Projects.TimeSheet.Reopen", Request, 'reopenedLines');
        // Clear(Request);
        // CreateNativeJournal(Request);
        // AssertAliasCountField("Message Type ori"::"Clockify.TimeSheet.Post", "Message Type ori"::"Projects.TimeSheet.Post", Request, 'postedLines');
        // Clear(Request);
        // AssertAliasCountField("Message Type ori"::"Clockify.TimeSheet.Archive", "Message Type ori"::"Projects.TimeSheet.Archive", Request, 'archived');
    // end;

    // local procedure AssertAliasCountField(LegacyType: Enum "Message Type ori"; NativeType: Enum "Message Type ori"; Request: JsonObject; CountField: Text)
    // var
        // TempArgument: Record "Message Argument ori" temporary;
        // LegacyResponse: JsonObject;
        // NativeResponse: JsonObject;
        // Counter: JsonToken;
    // begin
        // Execute(TempArgument, LegacyType, Request);
        // LegacyResponse := TempArgument.GetResponseJson();
        // Execute(TempArgument, NativeType, Request);
        // NativeResponse := TempArgument.GetResponseJson();
        // Assert.AreEqual('Success', ReadText(LegacyResponse, 'status'), 'Old name must keep working.');
        // Assert.AreEqual('Success', ReadText(NativeResponse, 'status'), 'Native name must work.');
        // Assert.IsTrue(LegacyResponse.Get(CountField, Counter), 'Old response count field.');
        // Assert.IsTrue(Counter.IsValue(), 'Old response count is a value.');
        // Assert.IsTrue(NativeResponse.Get(CountField, Counter), 'Native response count field.');
        // Assert.IsTrue(Counter.IsValue(), 'Native response count is a value.');
        // Assert.IsTrue(LegacyResponse.Contains('warnings'), 'Old name must warn about its replacement.');
        // Assert.IsFalse(NativeResponse.Contains('warnings'), 'Native name needs no deprecation warning.');
        // LegacyResponse.Remove('warnings');
        // Assert.AreEqual(LegacyResponse.Keys().Count(), NativeResponse.Keys().Count(), 'Optional warning is the only extra field.');
    // end;

    [Test]
    procedure Scenario_AC07_GenericStatusWrite_LeavesLineUnchanged()
    var
        Line: Record "Time Sheet Line";
        TempArgument: Record "Message Argument ori" temporary;
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        Fields: JsonObject;
        PrimaryKey: JsonObject;
        RecordData: JsonObject;
        Records: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #67, AC07 | Time: WorkDate | Risk: subscriber must fire through public Data.Records.Set
        // [GIVEN] An owned open line and a generic request to bypass its workflow.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        PrimaryKey.Add('TimeSheetNo_', SheetNo);
        PrimaryKey.Add('LineNo_', 10000);
        Fields.Add('Status', 'Approved');
        RecordData.Add('primaryKey', PrimaryKey);
        RecordData.Add('fields', Fields);
        Records.Add(RecordData);
        Request.Add('tableId', Database::"Time Sheet Line");
        Request.Add('data', Records);
        // [WHEN] Foundation checks the generic write and raises the real subscriber event.
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'W4ISSUE67', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
        // [THEN] The licensed public dispatcher reaches the real write restriction.
        // No Licensed Call flag or consent/trial/licence state is fabricated.
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'Generic status write must be refused.');
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Foundation reports protected fields as PermissionDenied.');
        Assert.AreEqual('tableId', ReadText(Response, 'parameter'), 'The absence table guard refuses the whole write before field validation.');
        Assert.IsTrue(TempArgument.GetDedicatedMessageTypeHintForField(Database::"Time Sheet Line", Line.FieldNo(Status)).Contains('Projects.TimeSheet.Reopen'), 'The status field subscriber must also retain native recovery guidance.');
        Assert.IsTrue(ReadText(Response, 'nextStep').Contains('Projects.TimeSheet.Reopen'), 'The real subscriber must name the dedicated native operation.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Refused write must leave the line open.');
    end;

    [Test]
    procedure Scenario_AC06_ReopenWithoutWritePermission_IsDenied()
    begin
        // Story #67, AC06 | Time: not used | Risk: mock must be stopped before assertions
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Reopen");
    end;

    [Test]
    procedure Scenario_AC06_PostWithoutWritePermission_IsDenied()
    begin
        // Story #67, AC06 | Time: not used | Risk: mock must be stopped before assertions
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Post");
    end;

    [Test]
    procedure Scenario_AC06_ArchiveWithoutWritePermission_IsDenied()
    begin
        // Story #67, AC06 | Time: not used | Risk: mock must be stopped before assertions
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Archive");
    end;

    local procedure AssertNativePermissionRefusal(MessageType: Enum "Message Type ori")
    begin
        AssertNativePermissionRefusal(MessageType, 'All Objects');
    end;

    local procedure AssertNativePermissionRefusal(MessageType: Enum "Message Type ori"; RoleId: Code[20])
    var
        TempArgument: Record "Message Argument ori" temporary;
        PermissionsMock: Codeunit "Permissions Mock";
        MsgInterface: Interface "Msg Interface ori";
        IsEnabled: Boolean;
        Executed: Boolean;
    begin
        // [GIVEN] Object execution permission without the native time-sheet table data grants.
        PermissionsMock.Start();
        PermissionsMock.ClearAssignments();
        PermissionsMock.Assign(RoleId);
        // [WHEN] Discovery and execution check this caller's real effective permissions.
        MsgInterface := MessageType;
        IsEnabled := MsgInterface.IsEnabled();
        Executed := TryExecuteNativePermissionCall(TempArgument, MessageType);
        PermissionsMock.Stop();
        // [THEN] Restore permissions before asserting either outcome.
        Assert.IsFalse(IsEnabled, 'Write types must be disabled for a caller without data permissions.');
        Assert.IsTrue(Executed, 'Permission refusal must not raise a raw runtime exception.');
        AssertRefusal(TempArgument, 'PermissionDenied', '', 'Assign the BIFROST Full ori and PROJ TS ADMIN permission sets.');
    end;

    /// <summary>#65 AC03: BIFROST Full ori alone no longer grants Base App time-sheet data, so the write types are disabled and refused with the hint naming both sets.</summary>
    [Test]
    procedure Scenario_65_ReopenUnderBifrostFullOnly_IsDenied()
    begin
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Reopen", 'BIFROST Full ori');
    end;

    /// <summary>#65 AC03: Archive under BIFROST Full ori alone is refused with the hint naming both sets.</summary>
    [Test]
    procedure Scenario_65_ArchiveUnderBifrostFullOnly_IsDenied()
    begin
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Archive", 'BIFROST Full ori');
    end;

    /// <summary>#65 AC03: Post under BIFROST Full ori alone is refused with the hint naming both sets.</summary>
    [Test]
    procedure Scenario_65_PostUnderBifrostFullOnly_IsDenied()
    begin
        AssertNativePermissionRefusal("Message Type ori"::"Projects.TimeSheet.Post", 'BIFROST Full ori');
    end;

    /// <summary>#65 AC03: BIFROST Full ori together with PROJ TS ADMIN enables Reopen and Archive again.</summary>
    [Test]
    procedure Scenario_65_FullAndAdmin_EnablesReopenAndArchive()
    var
        PermissionsMock: Codeunit "Permissions Mock";
        ReopenType: Interface "Msg Interface ori";
        ArchiveType: Interface "Msg Interface ori";
        ReopenEnabled: Boolean;
        ArchiveEnabled: Boolean;
    begin
        // [GIVEN] A caller holding only BIFROST Full ori and PROJ TS ADMIN.
        ReopenType := "Message Type ori"::"Projects.TimeSheet.Reopen";
        ArchiveType := "Message Type ori"::"Projects.TimeSheet.Archive";
        PermissionsMock.Start();
        PermissionsMock.ClearAssignments();
        PermissionsMock.Assign('BIFROST Full ori');
        PermissionsMock.Assign('PROJ TS ADMIN');
        // [WHEN] Discovery checks the caller's effective permissions.
        ReopenEnabled := ReopenType.IsEnabled();
        ArchiveEnabled := ArchiveType.IsEnabled();
        PermissionsMock.Stop();
        // [THEN] Restore permissions first; both types are enabled.
        Assert.IsTrue(ReopenEnabled, 'Reopen must be enabled under BIFROST Full ori and PROJ TS ADMIN.');
        Assert.IsTrue(ArchiveEnabled, 'Archive must be enabled under BIFROST Full ori and PROJ TS ADMIN.');
    end;

    /// <summary>#65 AC02: PROJ TS ADMIN is assignable and holds exactly the 30 grants the Full extension had, including the two #50 read grants, at the same levels.</summary>
    [Test]
    procedure Scenario_65_AdminSet_HoldsMovedGrantsAtSameLevels()
    var
        MetadataPermissionSet: Record "Metadata Permission Set";
        MetadataPermission: Record "Metadata Permission";
        Expected: List of [Text];
        Actual: Text;
    begin
        // [GIVEN] The grants Projects TimeSheet Full ori had before #65.
        AddExpectedGrants(Expected);
        // [WHEN] The platform metadata of the new set is read.
        MetadataPermissionSet.SetRange("App ID", ProjectsAppId());
        MetadataPermissionSet.SetRange("Role ID", 'PROJ TS ADMIN');
        Assert.IsTrue(MetadataPermissionSet.FindFirst(), 'PROJ TS ADMIN must exist in the Projects app.');
        Assert.IsTrue(MetadataPermissionSet.Assignable, 'PROJ TS ADMIN must be assignable.');
        MetadataPermission.SetRange("App ID", ProjectsAppId());
        MetadataPermission.SetRange("Role ID", 'PROJ TS ADMIN');
        // [THEN] Every grant is one of the moved grants at the same level, and none is missing.
        Assert.AreEqual(Expected.Count(), MetadataPermission.Count(), 'PROJ TS ADMIN holds exactly the moved grants.');
        MetadataPermission.FindSet();
        repeat
            Actual := FormatGrant(MetadataPermission);
            Assert.IsTrue(Expected.Contains(Actual), 'Unexpected or widened grant: ' + Actual);
        until MetadataPermission.Next() = 0;
    end;

    /// <summary>#65 AC01: the effective BIFROST Full ori role no longer holds the moved Base App time-sheet, absence and project journal grants; PROJ TS ADMIN holds them.</summary>
    [Test]
    procedure Scenario_65_BifrostFull_HoldsNoMovedBaseAppTableData()
    var
        ExpandedPermission: Record "Expanded Permission";
        MovedTables: Text;
    begin
        // [GIVEN] The Base App tables whose grants moved to PROJ TS ADMIN and that Foundation does not grant itself.
        MovedTables := StrSubstNo(MovedTablesTok, Database::"Job Journal Line", Database::"Time Sheet Header", Database::"Time Sheet Line",
            Database::"Time Sheet Detail", Database::"Time Sheet Comment Line", Database::"Time Sheet Header Archive", Database::"Time Sheet Line Archive",
            Database::"Time Sheet Detail Archive", Database::"Time Sheet Cmt. Line Archive", Database::"Time Sheet Posting Entry",
            Database::"Employee Absence", Database::"Cause of Absence");
        ExpandedPermission.SetRange("Object Type", ExpandedPermission."Object Type"::"Table Data");
        ExpandedPermission.SetFilter("Object ID", MovedTables);
        // [WHEN] The effective grants of BIFROST Full ori (with every extension merged) are read.
        ExpandedPermission.SetRange("Role ID", 'BIFROST Full ori');
        // [THEN] None remains in the extended Foundation role.
        Assert.RecordIsEmpty(ExpandedPermission);
        // [THEN] PROJ TS ADMIN grants all twelve.
        ExpandedPermission.SetRange("Role ID", 'PROJ TS ADMIN');
        Assert.RecordCount(ExpandedPermission, 12);
    end;

    local procedure ProjectsAppId(): Guid
    begin
        exit('c847bab7-2525-4ff5-93c4-15512b3be1e5');
    end;

    local procedure FormatGrant(MetadataPermission: Record "Metadata Permission"): Text
    var
        ObjectType: Integer;
        Levels: Text;
    begin
        ObjectType := MetadataPermission."Object Type";
        if MetadataPermission."Read Permission" = MetadataPermission."Read Permission"::Yes then
            Levels += 'R';
        if MetadataPermission."Insert Permission" = MetadataPermission."Insert Permission"::Yes then
            Levels += 'I';
        if MetadataPermission."Modify Permission" = MetadataPermission."Modify Permission"::Yes then
            Levels += 'M';
        if MetadataPermission."Delete Permission" = MetadataPermission."Delete Permission"::Yes then
            Levels += 'D';
        if MetadataPermission."Execute Permission" = MetadataPermission."Execute Permission"::Yes then
            Levels += 'X';
        exit(StrSubstNo(GrantTok, ObjectType, MetadataPermission."Object ID", Levels));
    end;

    local procedure AddGrant(var Expected: List of [Text]; ObjectType: Integer; ObjectId: Integer; Levels: Text)
    begin
        Expected.Add(StrSubstNo(GrantTok, ObjectType, ObjectId, Levels));
    end;

    local procedure AddExpectedGrants(var Expected: List of [Text])
    var
        MetadataPermission: Record "Metadata Permission";
        ReportType: Integer;
        TableData: Integer;
    begin
        TableData := MetadataPermission."Object Type"::"Table Data";
        ReportType := MetadataPermission."Object Type"::Report;
        AddGrant(Expected, TableData, Database::"Resources Setup", 'R');
        AddGrant(Expected, TableData, Database::"Job Task", 'R');
        AddGrant(Expected, TableData, Database::"Job Planning Line", 'R');
        AddGrant(Expected, TableData, Database::"Time Sheet Header", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Line", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Detail", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Comment Line", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Posting Entry", 'RI');
        AddGrant(Expected, TableData, Database::"Employee Absence", 'RI');
        AddGrant(Expected, TableData, Database::"Cause of Absence", 'R');
        AddGrant(Expected, TableData, Database::"Human Resource Unit of Measure", 'R');
        AddGrant(Expected, TableData, Database::"Human Resources Setup", 'R');
        AddGrant(Expected, TableData, Database::Employee, 'R');
        AddGrant(Expected, TableData, Database::Resource, 'R');
        AddGrant(Expected, TableData, Database::"User Setup", 'R');
        AddGrant(Expected, ReportType, Report::"Create Time Sheets", 'X');
        AddGrant(Expected, TableData, Database::"Resource Group", 'R');
        AddGrant(Expected, TableData, Database::"No. Series", 'R');
        AddGrant(Expected, TableData, Database::"No. Series Line", 'RIM');
        AddGrant(Expected, TableData, Database::"Accounting Period", 'R');
        AddGrant(Expected, TableData, Database::Job, 'R');
        AddGrant(Expected, TableData, Database::"Time Sheet Header Archive", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Line Archive", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Detail Archive", 'RIMD');
        AddGrant(Expected, TableData, Database::"Time Sheet Cmt. Line Archive", 'RIMD');
        AddGrant(Expected, TableData, Database::"Job Journal Template", 'R');
        AddGrant(Expected, TableData, Database::"Job Journal Batch", 'R');
        AddGrant(Expected, TableData, Database::"Job Journal Line", 'RIMD');
        AddGrant(Expected, TableData, Database::"Service Header", 'R');
        AddGrant(Expected, TableData, Database::"Work Type", 'R');
    end;

    [TryFunction]
    local procedure TryExecuteNativePermissionCall(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori")
    var
        Request: JsonObject;
    begin
        Execute(TempArgument, MessageType, Request);
    end;

    /// <summary>Creates fresh owned MCP and UI fixtures without deleting or reusing earlier verification data.</summary>
    [Test]
    procedure McpFixtureSeed_FreshOwnedKeys_CreatesVerificationData()
    var
        Header: Record "Time Sheet Header";
        Job: Record Job;
        JobTask: Record "Job Task";
        JournalTemplateRecord: Record "Job Journal Template";
        Batch: Record "Job Journal Batch";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        UserSetup: Record "User Setup";
        LibraryJob: Codeunit "Library - Job";
        FixturePrefix: Code[10];
        ResourceNo: Code[20];
        StartingDate: Date;
    begin
        // Fixture utility for issue #67 MCP/UI, not a substitute for message acceptance.
        // Time: two weeks before WorkDate, so posting is current and archive is eligible.
        // Runs in the full isolated suite too. After that suite passes, an explicit focused
        // setup run on the owned container retains only these self-created fixture records.
        // Each invocation owns fresh keys, including retained MCP setup runs. Never delete
        // or reuse an earlier run's fixture: it may already have been posted or archived.
        FixturePrefix := CopyStr('X67' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(FixturePrefix));
        Assert.IsFalse(Header.Get(FixturePrefix + 'REOPEN'), 'Existing fixture: inspect before recovery.');
        Assert.IsFalse(Header.Get(FixturePrefix + 'POST'), 'Existing fixture: inspect before recovery.');
        Assert.IsFalse(Header.Get(FixturePrefix + 'EMPTY'), 'Existing fixture: inspect before recovery.');
        StartingDate := CalcDate('<-CW>', WorkDate() - 14);
        ResourceNo := CreateResource(true);
        UserSetup.Get(UserId());
        UserSetup."Time Sheet Admin." := true;
        UserSetup.Modify(true);
        SeedMcpHeader(FixturePrefix + 'REOPEN', ResourceNo, StartingDate);
        SeedMcpLine(FixturePrefix + 'REOPEN', '', '', 1);
        SeedMcpHeader(FixturePrefix + 'EMPTY', ResourceNo, StartingDate - 7);
        LibraryJob.CreateJob(Job);
        Job.Rename(FixturePrefix + 'JOB');
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        LibraryJob.CreateJobTask(Job, JobTask);
        JobTask.Rename(Job."No.", 'OWN67');
        SeedMcpHeader(FixturePrefix + 'POST', CreateResource(true), StartingDate);
        SeedMcpLine(FixturePrefix + 'POST', Job."No.", JobTask."Job Task No.", 2);
        Series.Init();
        Series.Code := FixturePrefix;
        Series."Default Nos." := true;
        Series.Insert(true);
        SeriesLine.Init();
        SeriesLine."Series Code" := Series.Code;
        SeriesLine."Line No." := 10000;
        SeriesLine."Starting No." := FixturePrefix + '000001';
        SeriesLine."Ending No." := FixturePrefix + '999999';
        SeriesLine."Increment-by No." := 1;
        SeriesLine.Insert(true);
        JournalTemplateRecord.Init();
        JournalTemplateRecord.Name := FixturePrefix;
        JournalTemplateRecord.Insert(true);
        Batch.Init();
        Batch."Journal Template Name" := JournalTemplateRecord.Name;
        Batch.Name := 'OWN67';
        Batch.Validate("No. Series", Series.Code);
        Batch.Insert(true);
        Header.Get(FixturePrefix + 'REOPEN');
        Assert.AreEqual(ResourceNo, Header."Resource No.", 'The resource must be self-created for this fixture.');
        Header.Get(FixturePrefix + 'POST');
        Assert.AreEqual(StartingDate, Header."Starting Date", 'Owned project sheet date.');
        // No Foundation consent, EULA, trial, licence or Licensed Call state is written.
    end;

    /// <summary>Verifies repeated fixture setup retains both new record sets and all earlier owned fixtures.</summary>
    [Test]
    procedure Scenario_AC12_RepeatedFixtureSeed_PreservesEarlierRecords()
    var
        Header: Record "Time Sheet Header";
        Series: Record "No. Series";
        InitialHeaderCount: Integer;
        InitialSeriesCount: Integer;
    begin
        // Story #67, AC12 | Time: fixture dates follow WorkDate | Risk: earlier MCP setup may remain
        // [GIVEN] Any earlier owned fixtures remain in this company.
        Header.SetFilter("No.", 'X67*');
        InitialHeaderCount := Header.Count();
        Series.SetFilter(Code, 'X67*');
        InitialSeriesCount := Series.Count();
        // [WHEN] Two setup runs retain their data in the same transaction.
        McpFixtureSeed_FreshOwnedKeys_CreatesVerificationData();
        McpFixtureSeed_FreshOwnedKeys_CreatesVerificationData();
        // [THEN] Both own complete, distinct records; neither overwrites or removes earlier data.
        Assert.AreEqual(InitialHeaderCount + 6, Header.Count(), 'Both setup runs must retain their three time sheets.');
        Assert.AreEqual(InitialSeriesCount + 2, Series.Count(), 'Both setup runs must retain their own number series.');
    end;

    local procedure SeedMcpHeader(SheetNo: Code[20]; ResourceNo: Code[20]; StartingDate: Date)
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := SheetNo;
        Header."Starting Date" := StartingDate;
        Header."Ending Date" := StartingDate + 6;
        Header.Validate("Resource No.", ResourceNo);
        Header.Description := 'Owned issue67 ' + SheetNo;
        Header.Insert(true);
    end;

    local procedure SeedMcpLine(SheetNo: Code[20]; JobNo: Code[20]; TaskNo: Code[20]; Quantity: Decimal)
    var
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        Header.Get(SheetNo);
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        if JobNo = '' then
            Line.Validate(Type, Line.Type::Resource)
        else begin
            Line.Validate(Type, Line.Type::Job);
            Line.Validate("Job No.", JobNo);
            Line.Validate("Job Task No.", TaskNo);
        end;
        Line.Description := 'Owned native67 line';
        Line.Insert(true);
        Detail.Init();
        Detail.Date := Header."Starting Date";
        Detail.CopyFromTimeSheetLine(Line);
        Detail.Validate(Quantity, Quantity);
        Detail.Insert(true);
    end;

    local procedure CreateNativeJournal(var Request: JsonObject)
    var
        Batch: Record "Job Journal Batch";
        JournalTemplateRecord: Record "Job Journal Template";
    begin
        JournalTemplateRecord.Init();
        JournalTemplateRecord.Name := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(JournalTemplateRecord.Name));
        JournalTemplateRecord.Insert(true);
        Batch.Init();
        Batch."Journal Template Name" := JournalTemplateRecord.Name;
        Batch.Name := 'NATIVE67';
        Batch.Insert(true);
        Request.Add('journalTemplate', JournalTemplateRecord.Name);
        Request.Add('journalBatch', Batch.Name);
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
        Assert.AreEqual(GetExpectedNextStep(ExpectedNext), ReadText(Response, 'nextStep'), 'Refusal next step.');
    end;

    local procedure GetExpectedNextStep(EnglishText: Text): Text
    begin
        if GlobalLanguage() <> 1039 then
            exit(EnglishText);
        case EnglishText of
            'Use the native name.':
                exit('Notaðu innlenda heitið.');
            'Send the key with the documented type.':
                exit('Sendu lykilinn með skráðu tagi.');
            'Send the missing key.':
                exit('Sendu lykilinn sem vantar.');
            'Remove the unknown key.':
                exit('Fjarlægðu óþekkta lykilinn.');
            'Use an identifier that exists.':
                exit('Notaðu auðkenni sem er til.');
            'Assign the BIFROST Full ori and PROJ TS ADMIN permission sets.':
                exit('Úthlutaðu heimildasamstæðunum BIFROST Full ori og PROJ TS ADMIN.');
        end;
        Error('Missing Icelandic test expectation for %1.', EnglishText);
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

    local procedure IsolateFromOtherPendingLines(OwnSheetNo: Code[20]; EndingDateTo: Date)
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        // Reopen scans every sheet ending on or before the cutoff, so lines that already exist in the
        // database (demo data on a CI container) would change the count or fail the standard checks.
        // The test runner rolls this back.
        Header.SetFilter("Ending Date", '<=%1', EndingDateTo);
        Header.SetFilter("No.", '<>%1', OwnSheetNo);
        if Header.FindSet() then
            repeat
                Line.SetRange("Time Sheet No.", Header."No.");
                Line.SetFilter(Status, '%1|%2', Line.Status::Submitted, Line.Status::Approved);
                Line.ModifyAll(Status, Line.Status::Open, false);
            until Header.Next() = 0;
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
}
