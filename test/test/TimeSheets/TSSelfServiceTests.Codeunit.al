namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>
/// projects#38 PR (a): own-only and approver-only time-sheet message types.
/// The session user is the caller. Other employees and approvers are simulated by the user IDs
/// stored on the sheets (XEMPA38, XEMPB38, XAPPR38), which is exactly what the checks compare.
/// </summary>
codeunit 97160 "TS Self Service Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        OtherEmployeeTok: Label 'XEMPA38', Locked = true;
        SecondEmployeeTok: Label 'XEMPB38', Locked = true;
        OtherApproverTok: Label 'XAPPR38', Locked = true;

    [Test]
    procedure AC01_AllSevenTypes_HaveContracts_1033_1039()
    begin
        // [SCENARIO] Each new type publishes a contract with parameters in both languages.
        AssertContract("Message Type ori"::"Projects.MyTimeSheet.Get");
        AssertContract("Message Type ori"::"Projects.MyTimeSheet.Submit");
        AssertContract("Message Type ori"::"Projects.TimeSheetApproval.Get");
        AssertContract("Message Type ori"::"Projects.TimeSheetApproval.Approve");
        AssertContract("Message Type ori"::"Projects.TimeSheetApproval.Reject");
        AssertContract("Message Type ori"::"Projects.MyTimeSheetLine.Set");
        AssertContract("Message Type ori"::"Projects.MyTimeSheet.Create");
    end;

    [Test]
    procedure AC02_MyGet_ListsOnlyOwnSheets()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ResponseText: Text;
        StartDate: Date;
        OwnNo: Code[20];
        ForeignNo: Code[20];
    begin
        // [GIVEN] One own sheet and one sheet of another employee in the same week
        StartDate := UniqueWeek();
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), StartDate, UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Open');
        ForeignNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), StartDate, OtherEmployeeTok, UserId());
        CreateLine(ForeignNo, 10000, 'Open');
        // [WHEN] The caller reads own sheets for that week
        Request.Add('from', Format(StartDate, 0, 9));
        Request.Add('to', Format(StartDate + 6, 0, 9));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        // [THEN] Only the own sheet is returned
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'MyTimeSheet.Get should succeed.');
        ResponseText := ReadText(TempArgument.GetResponseJson(), 'timeSheets');
        Assert.IsTrue(ResponseText.Contains(OwnNo), 'The own sheet must be listed.');
        Assert.IsFalse(ResponseText.Contains(ForeignNo), 'Another employee''s sheet must not be listed.');
    end;

    [Test]
    procedure AC02_MyGet_ForeignSheet_Refused_NoData_1033()
    begin
        MyGetForeignSheetRefused(1033);
    end;

    [Test]
    procedure AC02_MyGet_ForeignSheet_Refused_NoData_1039()
    begin
        MyGetForeignSheetRefused(1039);
    end;

    [Test]
    procedure AC02_MyGet_StatusFilter_ReturnsMatchingLinesOnly()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ResponseText: Text;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Open');
        CreateLine(OwnNo, 20000, 'Rejected');
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('status', 'Rejected');
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        ResponseText := ReadText(TempArgument.GetResponseJson(), 'timeSheets');
        Assert.IsTrue(ResponseText.Contains('"lineNo":20000'), 'The rejected line must be returned.');
        Assert.IsFalse(ResponseText.Contains('"lineNo":10000'), 'The open line must be filtered out.');
    end;

    [Test]
    procedure AC02_MyGet_InvalidInput_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateResource(UserId(), OtherApproverTok);
        Request.Add('userId', 'SOMEONE');
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        AssertCode(TempArgument, 'UnknownParameter', 'userId');

        Clear(Request);
        Request.Add('from', '2026-11-16');
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        AssertCode(TempArgument, 'MissingParameter', 'from,to');

        Clear(Request);
        Request.Add('take', 0);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        AssertCode(TempArgument, 'InvalidParameterFormat', 'take');

        Clear(Request);
        Request.Add('status', 'Posted');
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        AssertCode(TempArgument, 'InvalidParameterFormat', 'status');
    end;

    [Test]
    procedure AC02_Unmapped_Caller_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // [GIVEN] The caller owns and approves no resource and no sheet
        RemoveCallerMapping();
        // [WHEN/THEN] Every self-service and approval read is refused with no data
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        AssertCode(TempArgument, 'PermissionDenied', '');
        Assert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'timeSheets'), 'No data for an unmapped caller.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Get", Request);
        AssertCode(TempArgument, 'PermissionDenied', '');
        Assert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'timeSheets'), 'No queue for an unmapped caller.');
    end;

    [Test]
    procedure AC02_MySubmit_ForeignSheet_Refused_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        ForeignNo: Code[20];
    begin
        CreateResource(UserId(), OtherApproverTok);
        ForeignNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        CreateLine(ForeignNo, 10000, 'Open');
        Request.Add('timeSheetNo', ForeignNo);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Submit", Request);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Line.Get(ForeignNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'A refused submit must leave the line open.');
    end;

    [Test]
    procedure AC03_MySubmit_OwnSheet_Submits()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Open');
        Request.Add('timeSheetNo', OwnNo);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Submit", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Own submit should succeed.');
        Line.Get(OwnNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'The own open line should be submitted.');
    end;

    [Test]
    procedure AC02_ApprovalGet_ListsOnlyCallersQueue()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ResponseText: Text;
        StartDate: Date;
        QueueNo: Code[20];
        OtherQueueNo: Code[20];
        OwnNo: Code[20];
    begin
        // [GIVEN] Two employees and one approver: a sheet in the caller's queue, a sheet for another approver, and the caller's own sheet
        StartDate := UniqueWeek();
        QueueNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), StartDate, OtherEmployeeTok, UserId());
        CreateLine(QueueNo, 10000, 'Submitted');
        CreateLine(QueueNo, 20000, 'Open');
        OtherQueueNo := CreateSheet(CreateResource(SecondEmployeeTok, OtherApproverTok), StartDate, SecondEmployeeTok, OtherApproverTok);
        CreateLine(OtherQueueNo, 10000, 'Submitted');
        OwnNo := CreateSheet(CreateResource(UserId(), UserId()), StartDate, UserId(), UserId());
        CreateLine(OwnNo, 10000, 'Submitted');
        Request.Add('from', Format(StartDate, 0, 9));
        Request.Add('to', Format(StartDate + 6, 0, 9));
        // [WHEN]
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Get", Request);
        // [THEN] Only the sheet waiting for the caller is listed, with its submitted line only
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Approval.Get should succeed.');
        ResponseText := ReadText(TempArgument.GetResponseJson(), 'timeSheets');
        Assert.IsTrue(ResponseText.Contains(QueueNo), 'The queued sheet must be listed.');
        Assert.IsFalse(ResponseText.Contains(OtherQueueNo), 'Another approver''s sheet must not be listed.');
        Assert.IsFalse(ResponseText.Contains(OwnNo), 'The caller''s own sheet is never in the approval queue.');
        Assert.IsFalse(ResponseText.Contains('"lineNo":20000'), 'Open lines are not in the queue.');
    end;

    [Test]
    procedure AC02_ApprovalGet_ForeignSheet_Refused_1033()
    begin
        ApprovalGetForeignRefused(1033);
    end;

    [Test]
    procedure AC02_ApprovalGet_ForeignSheet_Refused_1039()
    begin
        ApprovalGetForeignRefused(1039);
    end;

    [Test]
    procedure AC02_Approve_OwnSheet_Refused_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        OwnNo: Code[20];
    begin
        // [GIVEN] The caller is both owner and approver
        OwnNo := CreateSheet(CreateResource(UserId(), UserId()), UniqueWeek(), UserId(), UserId());
        CreateLine(OwnNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', OwnNo);
        // [WHEN/THEN] Self-approval is refused and nothing changes
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Approve", Request);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Assert.AreEqual('Ask another approver to decide on your own time sheet.', ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'Self-approval next step.');
        Line.Get(OwnNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'A refused self-approval must leave the line submitted.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Reject", Request);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Line.Get(OwnNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'A refused self-rejection must leave the line submitted.');
    end;

    [Test]
    procedure AC02_Approve_OtherApproversSheet_Refused_1033()
    begin
        ApproveForeignRefused(1033);
    end;

    [Test]
    procedure AC02_Approve_OtherApproversSheet_Refused_1039()
    begin
        ApproveForeignRefused(1039);
    end;

    [Test]
    procedure AC04_Approve_PerLine_ThenWholeSheet()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        LineNos: JsonArray;
        QueueNo: Code[20];
    begin
        QueueNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        CreateLine(QueueNo, 10000, 'Submitted');
        CreateLine(QueueNo, 20000, 'Submitted');
        // [WHEN] One line is approved
        LineNos.Add(10000);
        Request.Add('timeSheetNo', QueueNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Per-line approval should succeed.');
        Line.Get(QueueNo, 10000);
        Assert.AreEqual(Line.Status::Approved, Line.Status, 'The selected line is approved.');
        Line.Get(QueueNo, 20000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'The other line stays submitted.');
        // [WHEN] The whole sheet is approved
        Clear(Request);
        Request.Add('timeSheetNo', QueueNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Whole-sheet approval should succeed.');
        Line.Get(QueueNo, 20000);
        Assert.AreEqual(Line.Status::Approved, Line.Status, 'The remaining line is approved.');
    end;

    [Test]
    procedure AC04_Reject_ReasonReachesEmployeeGet()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // [GIVEN] A sheet of another employee in the caller's queue
        SheetNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        // [WHEN] The approver rejects with a reason
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('comment', 'Split the task, please.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Reject", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Reject should succeed.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Rejected, Line.Status, 'The line is rejected.');
        // [THEN] The employee's own read shows the reason. The session cannot change user, so the
        // sheet is handed to the caller as owner (and another approver) to read it through the owner path.
        Header.Get(SheetNo);
        Header."Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Owner User ID"));
        Header."Approver User ID" := OtherApproverTok;
        Header.Modify(false);
        Clear(Request);
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        Assert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'timeSheets').Contains('Split the task, please.'), 'The rejection reason must reach the employee''s Get.');
        Assert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'timeSheets').Contains('"status":"Rejected"'), 'The line status must be Rejected.');
    end;

    [Test]
    procedure AC04_Reject_OpenLine_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        LineNos: JsonArray;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        CreateLine(SheetNo, 10000, 'Open');
        LineNos.Add(10000);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Reject", Request);
        AssertCode(TempArgument, 'InvalidLine', 'lineNos');
    end;

    [Test]
    procedure AC03_LineSet_AddLineWithHours()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        OwnNo: Code[20];
    begin
        // [GIVEN] An own sheet without lines
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        Header.Get(OwnNo);
        // [WHEN] The owner adds a resource line with two days
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(NewEntry('Resource', 'Workshop', Header."Starting Date", 4, Header."Starting Date" + 1, 3)));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        // [THEN] The line and its hours exist and the answer reports them
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'LineSet should succeed: ' + FullResponse(TempArgument));
        Assert.IsTrue(ReadText(TempArgument.GetResponseJson(), 'lines').Contains('"created":true'), 'The new line is reported as created.');
        Line.SetRange("Time Sheet No.", OwnNo);
        Assert.AreEqual(1, Line.Count(), 'One line is added.');
        Line.FindFirst();
        Assert.AreEqual('Workshop', Line.Description, 'Description is stored.');
        Detail.SetRange("Time Sheet No.", OwnNo);
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        Detail.CalcSums(Quantity);
        Assert.AreEqual(7, Detail.Quantity, 'Daily hours are stored.');
    end;

    [Test]
    procedure AC03_LineSet_EditOpenLine_ChangesHours()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Entry: JsonObject;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Open');
        Header.Get(OwnNo);
        Entry := NewEntry('', '', Header."Starting Date", 5, 0D, 0);
        Entry.Add('lineNo', 10000);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(Entry));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Editing an open line should succeed: ' + FullResponse(TempArgument));
        Detail.Get(OwnNo, 10000, Header."Starting Date");
        Assert.AreEqual(5, Detail.Quantity, 'The day is changed from 8 to 5 hours.');
    end;

    [Test]
    procedure AC03_LineSet_SubmittedLine_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Entry: JsonObject;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Submitted');
        Header.Get(OwnNo);
        Entry := NewEntry('', '', Header."Starting Date", 1, 0D, 0);
        Entry.Add('lineNo', 10000);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(Entry));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        AssertCode(TempArgument, 'InvalidLine', 'lines.lineNo');
        Detail.Get(OwnNo, 10000, Header."Starting Date");
        Assert.AreEqual(8, Detail.Quantity, 'A submitted line keeps its hours.');
    end;

    [Test]
    procedure AC03_LineSet_RejectedLine_EditReopens()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Entry: JsonObject;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        CreateLine(OwnNo, 10000, 'Rejected');
        Header.Get(OwnNo);
        Entry := NewEntry('', '', Header."Starting Date", 6, 0D, 0);
        Entry.Add('lineNo', 10000);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(Entry));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Editing a rejected line should succeed: ' + FullResponse(TempArgument));
        Line.Get(OwnNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'An edited rejected line is open again for a new submit.');
    end;

    [Test]
    procedure AC02_LineSet_ForeignSheet_Refused_1033()
    begin
        LineSetForeignRefused(1033);
    end;

    [Test]
    procedure AC02_LineSet_ForeignSheet_Refused_1039()
    begin
        LineSetForeignRefused(1039);
    end;

    [Test]
    procedure AC03_LineSet_InvalidInput_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Entry: JsonObject;
        OwnNo: Code[20];
    begin
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        Header.Get(OwnNo);
        // Unknown key on an entry
        Entry := NewEntry('Resource', 'X', Header."Starting Date", 1, 0D, 0);
        Entry.Add('status', 'Approved');
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(Entry));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        AssertCode(TempArgument, 'UnknownParameter', 'lines.status');
        // Day outside the sheet period
        Clear(Request);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(NewEntry('Resource', 'X', Header."Ending Date" + 1, 1, 0D, 0)));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        AssertCode(TempArgument, 'InvalidParameter', 'lines.days');
        // New line without a type
        Clear(Request);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(NewEntry('', 'X', Header."Starting Date", 1, 0D, 0)));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        AssertCode(TempArgument, 'MissingParameter', 'lines.type');
        // New Job line without a project
        Clear(Request);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', OneEntry(NewEntry('Job', 'X', Header."Starting Date", 1, 0D, 0)));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        AssertCode(TempArgument, 'MissingParameter', 'lines.projectNo');
    end;

    [Test]
    procedure AC03_LineSet_NativeError_RollsBackWholeCall()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Entries: JsonArray;
        BadEntry: JsonObject;
        OwnNo: Code[20];
    begin
        // [GIVEN] One valid entry and one entry on a project that does not exist
        OwnNo := CreateSheet(CreateResource(UserId(), OtherApproverTok), UniqueWeek(), UserId(), OtherApproverTok);
        Header.Get(OwnNo);
        Entries.Add(NewEntry('Resource', 'Valid', Header."Starting Date", 2, 0D, 0));
        BadEntry := NewEntry('Job', 'Bad', Header."Starting Date", 2, 0D, 0);
        BadEntry.Add('projectNo', 'XNOPROJ38');
        BadEntry.Add('taskNo', 'XNOTASK38');
        Entries.Add(BadEntry);
        Request.Add('timeSheetNo', OwnNo);
        Request.Add('lines', Entries);
        // [WHEN]
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        // [THEN] The call is refused and the valid entry is rolled back too
        AssertCode(TempArgument, 'BusinessCentralError', 'lines');
        Line.SetRange("Time Sheet No.", OwnNo);
        Assert.IsTrue(Line.IsEmpty(), 'No line may remain after a failed call.');
    end;

    local procedure LineSetForeignRefused(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        ForeignNo: Code[20];
        PreviousLanguage: Integer;
    begin
        CreateResource(UserId(), OtherApproverTok);
        ForeignNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        Header.Get(ForeignNo);
        Request.Add('timeSheetNo', ForeignNo);
        Request.Add('lines', OneEntry(NewEntry('Resource', 'Intrusion', Header."Starting Date", 8, 0D, 0)));
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheetLine.Set", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Assert.AreNotEqual('', ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'The refusal names a next step.');
        Line.SetRange("Time Sheet No.", ForeignNo);
        Assert.IsTrue(Line.IsEmpty(), 'No line may be added to another employee''s sheet.');
    end;

    local procedure NewEntry(LineType: Text; Description: Text; Day1: Date; Hours1: Decimal; Day2: Date; Hours2: Decimal) Entry: JsonObject
    var
        Days: JsonArray;
        Day: JsonObject;
    begin
        if LineType <> '' then
            Entry.Add('type', LineType);
        if Description <> '' then
            Entry.Add('description', Description);
        Day.Add('date', Format(Day1, 0, 9));
        Day.Add('hours', Hours1);
        Days.Add(Day);
        if Day2 <> 0D then begin
            Clear(Day);
            Day.Add('date', Format(Day2, 0, 9));
            Day.Add('hours', Hours2);
            Days.Add(Day);
        end;
        Entry.Add('days', Days);
    end;

    local procedure OneEntry(Entry: JsonObject) Entries: JsonArray
    begin
        Entries.Add(Entry);
    end;

    [Test]
    procedure AC01_MyCreate_CreatesOwnSheet_ThenNoOp()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        StartDate: Date;
        ResourceNo: Code[20];
    begin
        // [GIVEN] The caller owns one time sheet resource; the caller is not a time sheet administrator
        IsolateOwnResources();
        ResourceNo := CreateResource(UserId(), OtherApproverTok);
        StartDate := FirstWeekdayWeek();
        // [WHEN] The caller creates the own sheet
        Request.Add('startingDate', Format(StartDate, 0, 9));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        // [THEN] One native sheet exists for the own resource and the caller owns it
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Own create should succeed: ' + FullResponse(TempArgument));
        Assert.AreEqual('true', ReadText(TempArgument.GetResponseJson(), 'created'), 'A new sheet is created.');
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetRange("Starting Date", StartDate);
        Assert.AreEqual(1, Header.Count(), 'Exactly one sheet is created.');
        Header.FindFirst();
        Assert.AreEqual(CopyStr(UpperCase(UserId()), 1, 50), Header."Owner User ID", 'The caller owns the new sheet.');
        // [WHEN] The same call is sent again [THEN] it is a typed no-op
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'A retry should succeed.');
        Assert.AreEqual('false', ReadText(TempArgument.GetResponseJson(), 'created'), 'A retry creates nothing.');
        Assert.AreEqual(1, Header.Count(), 'Still exactly one sheet.');
    end;

    [Test]
    procedure AC02_MyCreate_ForeignResource_Refused_1033_1039()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        ForeignResourceNo: Code[20];
        StartDate: Date;
        PreviousLanguage: Integer;
    begin
        CreateResource(UserId(), OtherApproverTok);
        ForeignResourceNo := CreateResource(OtherEmployeeTok, UserId());
        StartDate := FirstWeekdayWeek();
        Request.Add('startingDate', Format(StartDate, 0, 9));
        Request.Add('resourceNo', ForeignResourceNo);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'resourceNo');
        GlobalLanguage(1039);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'resourceNo');
        Header.SetRange("Resource No.", ForeignResourceNo);
        Assert.IsTrue(Header.IsEmpty(), 'No sheet may be created for another employee''s resource.');
    end;

    [Test]
    procedure AC01_MyCreate_InvalidInput_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        IsolateOwnResources();
        CreateResource(UserId(), OtherApproverTok);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        AssertCode(TempArgument, 'MissingParameter', 'startingDate');
        Request.Add('startingDate', Format(FirstWeekdayWeek() + 1, 0, 9));
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        AssertCode(TempArgument, 'InvalidParameter', 'startingDate');
        Clear(Request);
        Request.Add('startingDate', Format(FirstWeekdayWeek(), 0, 9));
        Request.Add('userId', 'SOMEONE');
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Create", Request);
        AssertCode(TempArgument, 'UnknownParameter', 'userId');
    end;

    local procedure MyGetForeignSheetRefused(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ForeignNo: Code[20];
        PreviousLanguage: Integer;
    begin
        CreateResource(UserId(), OtherApproverTok);
        ForeignNo := CreateSheet(CreateResource(OtherEmployeeTok, UserId()), UniqueWeek(), OtherEmployeeTok, UserId());
        CreateLine(ForeignNo, 10000, 'Open');
        Request.Add('timeSheetNo', ForeignNo);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Execute(TempArgument, "Message Type ori"::"Projects.MyTimeSheet.Get", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Assert.AreNotEqual('', ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'The refusal names a next step.');
        Assert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'timeSheets'), 'A refused read returns no data.');
        Assert.IsFalse(FullResponse(TempArgument).Contains('"lineNo"'), 'No line data may leak.');
    end;

    local procedure ApprovalGetForeignRefused(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
        PreviousLanguage: Integer;
    begin
        CreateResource(OtherEmployeeTok, UserId());
        SheetNo := CreateSheet(CreateResource(SecondEmployeeTok, OtherApproverTok), UniqueWeek(), SecondEmployeeTok, OtherApproverTok);
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Get", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Assert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'timeSheets'), 'A refused read returns no data.');
        Assert.IsFalse(FullResponse(TempArgument).Contains(SecondEmployeeTok), 'No owner data may leak.');
    end;

    local procedure ApproveForeignRefused(LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
        PreviousLanguage: Integer;
    begin
        CreateResource(OtherEmployeeTok, UserId());
        SheetNo := CreateSheet(CreateResource(SecondEmployeeTok, OtherApproverTok), UniqueWeek(), SecondEmployeeTok, OtherApproverTok);
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheetApproval.Approve", Request);
        GlobalLanguage(PreviousLanguage);
        AssertCode(TempArgument, 'PermissionDenied', 'timeSheetNo');
        Assert.AreEqual('', ReadText(TempArgument.GetResponseJson(), 'lines'), 'A refused approval returns no line data.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'A refused approval must leave the line submitted.');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
        LanguageId: Integer;
        LanguageIds: List of [Integer];
        PreviousLanguage: Integer;
        HasContract: Boolean;
    begin
        PreviousLanguage := GlobalLanguage();
        LanguageIds.Add(1033);
        LanguageIds.Add(1039);
        foreach LanguageId in LanguageIds do begin
            Clear(Contract);
            GlobalLanguage(LanguageId);
            HasContract := ContractMgt.GetContract(MessageType, Contract);
            GlobalLanguage(PreviousLanguage);
            Assert.IsTrue(HasContract, 'The type must have a contract in ' + Format(LanguageId) + '.');
            Assert.IsTrue(Contract.Get('parameters', Token), 'The contract lists parameters.');
            Assert.IsTrue(Token.AsArray().Count() > 0, 'The parameter list is not empty.');
        end;
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

    local procedure AssertCode(var TempArgument: Record "Message Argument ori" temporary; ExpectedCode: Text; ExpectedParameter: Text)
    var
        Response: JsonObject;
    begin
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'The call should be refused: ' + FullResponse(TempArgument));
        Assert.AreEqual(ExpectedCode, ReadText(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(ExpectedParameter, ReadText(Response, 'parameter'), 'Refusal parameter.');
    end;

    local procedure FullResponse(var TempArgument: Record "Message Argument ori" temporary) Result: Text
    begin
        TempArgument.GetResponseJson().WriteTo(Result);
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

    local procedure UniqueWeek(): Date
    begin
        // A far-future Monday-based week nobody else uses, so list assertions are not disturbed by demo data.
        exit(DMY2Date(5, 1, 2099) + 7 * Random(2000));
    end;

    local procedure FirstWeekdayWeek(): Date
    var
        ResourcesSetup: Record "Resources Setup";
        Day: Date;
    begin
        EnsureTimeSheetNos(ResourcesSetup);
        Day := UniqueWeek();
        while Date2DWY(Day, 1) <> ResourcesSetup."Time Sheet First Weekday" + 1 do
            Day += 1;
        exit(Day);
    end;

    local procedure EnsureTimeSheetNos(var ResourcesSetup: Record "Resources Setup")
    var
        LibraryUtility: Codeunit "Library - Utility";
    begin
        if not ResourcesSetup.Get() then begin
            ResourcesSetup.Init();
            ResourcesSetup.Insert();
        end;
        if ResourcesSetup."Time Sheet Nos." = '' then begin
            ResourcesSetup."Time Sheet Nos." := LibraryUtility.GetGlobalNoSeriesCode();
            ResourcesSetup.Modify();
        end;
    end;

    local procedure IsolateOwnResources()
    var
        Resource: Record Resource;
    begin
        // The caller may own demo or earlier fixture resources; keep exactly the one the test creates.
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", OtherEmployeeTok, false);
    end;

    local procedure RemoveCallerMapping()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Caller: Code[50];
    begin
        Caller := CopyStr(UpperCase(UserId()), 1, MaxStrLen(Caller));
        Resource.SetRange("Time Sheet Owner User ID", Caller);
        Resource.ModifyAll("Time Sheet Owner User ID", '', false);
        Resource.Reset();
        Resource.SetRange("Time Sheet Approver User ID", Caller);
        Resource.ModifyAll("Time Sheet Approver User ID", '', false);
        Header.SetRange("Owner User ID", Caller);
        Header.ModifyAll("Owner User ID", OtherEmployeeTok, false);
        Header.Reset();
        Header.SetRange("Approver User ID", Caller);
        Header.ModifyAll("Approver User ID", OtherApproverTok, false);
    end;

    local procedure CreateResource(Owner: Text; Approver: Text): Code[20]
    var
        Resource: Record Resource;
        UnitOfMeasure: Record "Unit of Measure";
        LibraryResource: Codeunit "Library - Resource";
    begin
        EnsureUserSetup();
        LibraryResource.CreateResourceNew(Resource);
        Resource.Rename(CopyStr('X38' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Resource."No.")));
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
        Resource.Validate("Use Time Sheet", true);
        // Direct assignment: the simulated users do not exist as BC users.
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(Owner), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := CopyStr(UpperCase(Approver), 1, MaxStrLen(Resource."Time Sheet Approver User ID"));
        Resource.Modify(true);
        exit(Resource."No.");
    end;

    local procedure EnsureUserSetup()
    var
        UserSetup: Record "User Setup";
    begin
        // Native approval lets time-sheet administrators bypass the approver check; keep the caller a non-admin.
        if not UserSetup.Get(UserId()) then begin
            UserSetup.Init();
            UserSetup.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID")));
            UserSetup.Insert(true);
        end;
        UserSetup.Validate("Time Sheet Admin.", false);
        UserSetup.Modify(true);
    end;

    local procedure CreateSheet(ResourceNo: Code[20]; StartingDate: Date; Owner: Text; Approver: Text): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := CopyStr('X38' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := StartingDate;
        Header."Ending Date" := StartingDate + 6;
        Header."Owner User ID" := CopyStr(UpperCase(Owner), 1, MaxStrLen(Header."Owner User ID"));
        Header."Approver User ID" := CopyStr(UpperCase(Approver), 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert(false);
        exit(Header."No.");
    end;

    local procedure CreateLine(SheetNo: Code[20]; LineNo: Integer; StatusName: Text)
    var
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
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
            'Rejected':
                Line.Status := Line.Status::Rejected;
            else
                Line.Status := Line.Status::Open;
        end;
        Line."Approver ID" := Header."Approver User ID";
        Line.Insert(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := LineNo;
        Detail.Date := Header."Starting Date";
        Detail.Quantity := 8;
        Detail.Status := Line.Status;
        Detail.Insert(false);
    end;
}
