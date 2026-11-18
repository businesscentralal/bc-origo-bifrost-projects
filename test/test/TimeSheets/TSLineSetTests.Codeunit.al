namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.Period;
using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Behavior tests for Projects.TimeSheetLine.Set (projects#50).</summary>
codeunit 97163 "TS Line Set Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LineSetTok: Label 'Projects.TimeSheetLine.Set', Locked = true;

    /// <summary>AC01: a new project line and its daily hours are inserted through validation.</summary>
    [Test]
    procedure Scenario_AC01_NewProjectLine_InsertsHours()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Job: Record Job;
        JobTask: Record "Job Task";
        Line: Record "Time Sheet Line";
        LineJson: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // [GIVEN] An open time sheet and an open project with a posting task.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        CreateProject(Job, JobTask);
        // [WHEN] A project line with hours on two days is sent.
        LineJson.Add('type', 'project');
        LineJson.Add('projectNo', Job."No.");
        LineJson.Add('projectTaskNo', JobTask."Job Task No.");
        LineJson.Add('description', 'Design work');
        AddHour(LineJson, WorkDate(), 8);
        AddHour(LineJson, WorkDate() + 1, 6);
        Execute(TempArgument, Request, SheetNo, LineJson);
        // [THEN] One Open project line with 14 hours is stored and returned.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'The call should succeed: ' + ReadText(Response, 'message'));
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(1, Line.Count(), 'Exactly one line is added.');
        Line.FindFirst();
        Assert.AreEqual(Line.Type::Job, Line.Type, 'Line type.');
        Assert.AreEqual(Job."No.", Line."Job No.", 'Project.');
        Assert.AreEqual(JobTask."Job Task No.", Line."Job Task No.", 'Project task.');
        Assert.AreEqual('Design work', Line.Description, 'A sent description replaces the task description.');
        Assert.AreEqual(Line.Status::Open, Line.Status, 'A new line is Open.');
        Line.CalcFields("Total Quantity");
        Assert.AreEqual(14, Line."Total Quantity", 'Total hours.');
        Detail.Get(SheetNo, Line."Line No.", WorkDate());
        Assert.AreEqual(Job."No.", Detail."Job No.", 'The detail carries the project for posting.');
        Assert.AreEqual(8, Detail.Quantity, 'Hours on the first day.');
        Assert.AreEqual('14', ReadPath(Response, 'lines[0].totalQuantity'), 'Response total.');
        Assert.AreEqual('true', ReadPath(Response, 'lines[0].created'), 'Response marks the line as created.');
        Assert.AreEqual('project', ReadPath(Response, 'lines[0].type'), 'Response type token.');
    end;

    /// <summary>AC01: an existing Open line changes its description and hours; zero keeps the day.</summary>
    [Test]
    procedure Scenario_AC01_ExistingLine_UpdatesHours()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        LineJson: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
        LineNo: Integer;
    begin
        // [GIVEN] A resource line with 8 hours on day 1 and 2 hours on day 2.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        LineNo := AddResourceLine(SheetNo, 8, 2);
        // [WHEN] Day 1 becomes 4, day 2 becomes 0 and day 3 gets 3 hours.
        LineJson.Add('lineNo', LineNo);
        LineJson.Add('description', 'Updated');
        AddHour(LineJson, WorkDate(), 4);
        AddHour(LineJson, WorkDate() + 1, 0);
        AddHour(LineJson, WorkDate() + 2, 3);
        Execute(TempArgument, Request, SheetNo, LineJson);
        // [THEN] The same line holds 7 hours; the zero day keeps its row.
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'The update should succeed: ' + ReadText(Response, 'message'));
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(1, Line.Count(), 'No line is added on update.');
        Line.Get(SheetNo, LineNo);
        Assert.AreEqual('Updated', Line.Description, 'Description changes.');
        Line.CalcFields("Total Quantity");
        Assert.AreEqual(7, Line."Total Quantity", 'Total after the update.');
        Assert.IsTrue(Detail.Get(SheetNo, LineNo, WorkDate() + 1), 'A day set to zero keeps its row.');
        Assert.AreEqual(0, Detail.Quantity, 'The zero day holds zero hours.');
        Assert.AreEqual('false', ReadPath(Response, 'lines[0].created'), 'Response marks the line as changed.');
    end;

    /// <summary>AC02: a submitted line is refused with PreconditionFailed and a reopen next step.</summary>
    [Test]
    procedure Scenario_AC02_SubmittedLine_Refused()
    begin
        AssertLockedLineRefused(false);
    end;

    /// <summary>AC02: an approved line is refused with PreconditionFailed and a reopen next step.</summary>
    [Test]
    procedure Scenario_AC02_ApprovedLine_Refused()
    begin
        AssertLockedLineRefused(true);
    end;

    /// <summary>AC03: generic writes stay blocked and the hint names the new type.</summary>
    [Test]
    procedure Scenario_AC03_GenericWrites_NameLineSet()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Line", false), 'Generic line writes are blocked.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Detail", false), 'Generic detail writes are blocked.');
        Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Line"), LineSetTok) > 0, 'The line hint names Projects.TimeSheetLine.Set.');
        Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Detail"), LineSetTok) > 0, 'The detail hint names Projects.TimeSheetLine.Set.');
    end;

    /// <summary>AC04 invalid input: an unknown key inside a line is refused by its path.</summary>
    [Test]
    procedure Scenario_AC04_UnknownNestedKey_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        LineJson: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineJson.Add('type', 'resource');
        LineJson.Add('itemNo', 'X');
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'UnknownParameter', 'lines[0].itemNo', 'Remove the unknown key.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'A refused call writes nothing.');
    end;

    /// <summary>AC04 invalid input: a new line needs a type, and the type must be supported.</summary>
    [Test]
    procedure Scenario_AC04_MissingOrUnknownType_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LineJson: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineJson.Add('description', 'No type');
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'MissingParameter', 'lines[0].type', 'Send the missing key.');
        Clear(Request);
        LineJson.Add('type', 'item');
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'InvalidParameter', 'lines[0].type', 'Use project, resource, absence or service.');
    end;

    /// <summary>AC04 invalid input: a project key on a resource line and hours outside the sheet are refused.</summary>
    [Test]
    procedure Scenario_AC04_KeyForTypeAndOutsideDate_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LineJson: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineJson.Add('type', 'resource');
        LineJson.Add('projectNo', 'P1');
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'InvalidParameter', 'lines[0].projectNo', 'Send only the keys that belong to the line type.');
        Clear(Request);
        Clear(LineJson);
        LineJson.Add('type', 'resource');
        AddHour(LineJson, WorkDate() + 7, 2);
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'InvalidLine', 'lines[0].hours', 'Send each date once, keep every date inside the time sheet period and use zero or more hours.');
    end;

    /// <summary>AC04 edge case: a Business Central refusal on the second line rolls back the first.</summary>
    [Test]
    procedure Scenario_AC04_SecondLineFails_WholeCallRollsBack()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Job: Record Job;
        JobTask: Record "Job Task";
        Line: Record "Time Sheet Line";
        Lines: JsonArray;
        First: JsonObject;
        Second: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // [GIVEN] A valid resource line and a project line on a project that is blocked for all.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        CreateProject(Job, JobTask);
        Job.Blocked := Job.Blocked::All;
        Job.Modify(false);
        First.Add('type', 'resource');
        AddHour(First, WorkDate(), 2);
        Second.Add('type', 'project');
        Second.Add('projectNo', Job."No.");
        Second.Add('projectTaskNo', JobTask."Job Task No.");
        Lines.Add(First);
        Lines.Add(Second);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lines', Lines);
        // [WHEN] Both lines are sent in one call.
        ExecuteRequest(TempArgument, Request);
        // [THEN] The call is refused and neither line is stored.
        AssertRefusal(TempArgument, 'BusinessCentralError', 'lines', 'Fix the line and send the call again.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'No partial write may survive the refusal.');
    end;

    /// <summary>AC04 edge case: the same lineNo twice and a type change are refused.</summary>
    [Test]
    procedure Scenario_AC04_DuplicateLineNoAndTypeChange_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Lines: JsonArray;
        LineJson: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
        LineNo: Integer;
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        LineNo := AddResourceLine(SheetNo, 1, 1);
        LineJson.Add('lineNo', LineNo);
        Lines.Add(LineJson);
        Lines.Add(LineJson);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lines', Lines);
        ExecuteRequest(TempArgument, Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'lines[1].lineNo', 'Send each lineNo once.');
        Clear(Request);
        Clear(LineJson);
        LineJson.Add('lineNo', LineNo);
        LineJson.Add('type', 'absence');
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'lines[0].type', 'Keep the line type, or add a new line with the other type.');
    end;

    /// <summary>AC01 absence: a new absence line needs a resource linked to an employee.</summary>
    [Test]
    procedure Scenario_AC01_AbsenceLine_NeedsEmployee_ThenInserts()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        LineJson: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        CauseCode: Code[10];
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        CauseCode := CreateCause();
        LineJson.Add('type', 'absence');
        LineJson.Add('causeOfAbsenceCode', CauseCode);
        AddHour(LineJson, WorkDate(), 8);
        Execute(TempArgument, Request, SheetNo, LineJson);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'lines[0].type', 'Link the resource to an employee in BC.');
        LinkEmployee(ResourceNo);
        Clear(Request);
        Execute(TempArgument, Request, SheetNo, LineJson);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Absence line should be added: ' + ReadText(Response, 'message'));
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Absence);
        Line.SetRange("Cause of Absence Code", CauseCode);
        Assert.IsFalse(Line.IsEmpty(), 'The absence line is stored with its cause.');
    end;

    /// <summary>AC04/AC05: help is localized at 1039, chapters stay English and the name has three parts.</summary>
    [Test]
    procedure Scenario_AC04_AC05_HelpAndName()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Types: JsonArray;
        Response: JsonObject;
        EnglishRow: JsonObject;
        IcelandicRow: JsonObject;
        Token: JsonToken;
    begin
        Assert.AreEqual(3, LineSetTok.Split('.').Count(), 'AC05: the name has exactly three parts.');
        Assert.IsTrue("Message Type ori".Names().Contains(LineSetTok), 'The type is registered.');
        Types.Add(LineSetTok);
        Request.Add('messageTypes', Types);
        Request.Add('detail', 'full');
        Request.Add('lcid', 1033);
        ExecuteType(TempArgument, "Message Type ori"::"Help.Implementation.Get", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'English help must succeed.');
        Response.SelectToken('result[0]', Token);
        EnglishRow := Token.AsObject();
        Request.Replace('lcid', 1039);
        ExecuteType(TempArgument, "Message Type ori"::"Help.Implementation.Get", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Icelandic help must succeed.');
        Response.SelectToken('result[0]', Token);
        IcelandicRow := Token.AsObject();
        Assert.AreEqual('Adds or changes time sheet lines and hours per day.', ReadText(EnglishRow, 'description'), 'English catalogue.');
        Assert.AreEqual('Bætir við eða breytir línum tímaskýrslu og klukkustundum eftir dögum.', ReadText(IcelandicRow, 'description'), 'Icelandic catalogue.');
        Assert.IsTrue(ReadText(EnglishRow, 'errors').Contains('PreconditionFailed'), 'Help documents PreconditionFailed.');
        Assert.AreEqual(ReadText(EnglishRow, 'parameters'), ReadText(IcelandicRow, 'parameters'), 'Help chapters remain English at both LCIDs.');
    end;

    local procedure AssertLockedLineRefused(Approve: Boolean)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        ApprovalMgt: Codeunit "Time Sheet Approval Management";
        LineJson: JsonObject;
        Request: JsonObject;
        SheetNo: Code[20];
        LineNo: Integer;
    begin
        // [GIVEN] A resource line with 5 hours that is submitted (and approved).
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        LineNo := AddResourceLine(SheetNo, 5, 0);
        Line.Get(SheetNo, LineNo);
        ApprovalMgt.Submit(Line);
        if Approve then begin
            Line.Get(SheetNo, LineNo);
            ApprovalMgt.Approve(Line);
        end;
        // [WHEN] Its hours are changed.
        LineJson.Add('lineNo', LineNo);
        AddHour(LineJson, WorkDate(), 1);
        Execute(TempArgument, Request, SheetNo, LineJson);
        // [THEN] PreconditionFailed with the reopen next step; the hours stay.
        AssertRefusal(TempArgument, 'PreconditionFailed', 'lines[0].lineNo', 'Reopen the line with Projects.TimeSheet.Reopen, then send the change again.');
        Line.Get(SheetNo, LineNo);
        Line.CalcFields("Total Quantity");
        Assert.AreEqual(5, Line."Total Quantity", 'A refused change keeps the hours.');
    end;

    local procedure AddResourceLine(SheetNo: Code[20]; Day1: Decimal; Day2: Decimal): Integer
    var
        TempArgument: Record "Message Argument ori" temporary;
        LineJson: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        LineNo: Integer;
    begin
        LineJson.Add('type', 'resource');
        LineJson.Add('description', 'Fixture');
        AddHour(LineJson, WorkDate(), Day1);
        if Day2 <> 0 then
            AddHour(LineJson, WorkDate() + 1, Day2);
        Execute(TempArgument, Request, SheetNo, LineJson);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Fixture line should be added: ' + ReadText(Response, 'message'));
        Evaluate(LineNo, ReadPath(Response, 'lines[0].lineNo'));
        exit(LineNo);
    end;

    local procedure CreateProject(var Job: Record Job; var JobTask: Record "Job Task")
    var
        LibraryJob: Codeunit "Library - Job";
    begin
        LibraryJob.CreateJob(Job);
        Job.Status := Job.Status::Open;
        Job.Modify(false);
        LibraryJob.CreateJobTask(Job, JobTask);
    end;

    local procedure Execute(var TempArgument: Record "Message Argument ori" temporary; var Request: JsonObject; SheetNo: Code[20]; LineJson: JsonObject)
    var
        Lines: JsonArray;
    begin
        Lines.Add(LineJson);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lines', Lines);
        ExecuteRequest(TempArgument, Request);
    end;

    local procedure ExecuteRequest(var TempArgument: Record "Message Argument ori" temporary; Request: JsonObject)
    begin
        ExecuteType(TempArgument, "Message Type ori"::"Projects.TimeSheetLine.Set", Request);
    end;

    local procedure ReadPath(Response: JsonObject; Path: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.SelectToken(Path, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ExecuteType(var TempArgument: Record "Message Argument ori" temporary; MessageType: Enum "Message Type ori"; RequestJson: JsonObject)
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
        if Resource."Base Unit of Measure" <> 'HOUR' then begin
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

    local procedure AddHour(var Request: JsonObject; HourDate: Date; Quantity: Decimal)
    var
        Hour: JsonObject;
        Hours: JsonArray;
        HoursToken: JsonToken;
    begin
        Hour.Add('date', Format(HourDate, 0, 9));
        Hour.Add('quantity', Quantity);
        if Request.Get('hours', HoursToken) then
            HoursToken.AsArray().Add(Hour)
        else begin
            Hours.Add(Hour);
            Request.Add('hours', Hours);
        end;
    end;

    local procedure CreateCause(): Code[10]
    var
        Cause: Record "Cause of Absence";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
    begin
        LibraryTimeSheet.CreateCauseOfAbsence(Cause);
        exit(Cause.Code);
    end;

    local procedure LinkEmployee(ResourceNo: Code[20])
    var
        Employee: Record Employee;
    begin
        Employee.Init();
        Employee."No." := CopyStr('E' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Employee."No."));
        Employee."Resource No." := ResourceNo;
        Employee.Insert(false);
    end;

    local procedure EnsureHrSetup()
    var
        HumanResourcesSetup: Record "Human Resources Setup";
        HumanResourceUnitOfMeasure: Record "Human Resource Unit of Measure";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
    begin
        if not HumanResourcesSetup.Get() then begin
            HumanResourcesSetup.Init();
            HumanResourcesSetup.Insert();
        end;
        if not HumanResourceUnitOfMeasure.Get('HOUR') then begin
            HumanResourceUnitOfMeasure.Init();
            HumanResourceUnitOfMeasure.Code := 'HOUR';
            HumanResourceUnitOfMeasure."Qty. per Unit of Measure" := 1;
            HumanResourceUnitOfMeasure.Insert(true);
        end;
        if HumanResourcesSetup."Base Unit of Measure" <> '' then
            exit;
        LibraryTimeSheet.CreateHRUnitOfMeasure(HumanResourceUnitOfMeasure, 1);
        HumanResourcesSetup."Base Unit of Measure" := HumanResourceUnitOfMeasure.Code;
        HumanResourcesSetup.Modify();
    end;

    local procedure EnsureAccountingPeriod(ForDate: Date)
    var
        AccountingPeriod: Record "Accounting Period";
    begin
        AccountingPeriod.SetFilter("Starting Date", '<=%1', ForDate);
        if not AccountingPeriod.IsEmpty() then
            exit;
        AccountingPeriod.Init();
        AccountingPeriod."Starting Date" := CalcDate('<-CY>', ForDate);
        AccountingPeriod."New Fiscal Year" := true;
        AccountingPeriod.Name := CopyStr(Format(AccountingPeriod."Starting Date", 0, '<Year4>'), 1, MaxStrLen(AccountingPeriod.Name));
        AccountingPeriod.Insert(false);
    end;

}
