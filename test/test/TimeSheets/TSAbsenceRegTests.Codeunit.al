namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Behavior tests for Projects.Absence.Register.</summary>
codeunit 97142 "TS Absence Reg Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Absence_MissingCause_IsMissingParameter()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'causeOfAbsenceCode', 'Send the missing key.');
    end;

    [Test]
    procedure Absence_UnknownCause_IsRecordNotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', 'NO-SUCH');
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'causeOfAbsenceCode', 'Use a code from Causes of Absence.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'An unknown cause must not add a line.');
    end;

    [Test]
    procedure Absence_NoEmployee_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
        HourDate: Date;
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        HourDate := DateInSheet(WorkDate(), false);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CreateCause());
        AddHour(Request, HourDate, 4);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'resourceNo', 'Link the resource to an employee in BC.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'A resource without an employee must not get an absence line.');
    end;

    [Test]
    procedure Absence_Weekday_RegistersLine()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        CauseCode: Code[10];
        HourDate: Date;
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), false);
        CauseCode := CreateCause();
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CauseCode);
        AddHour(Request, HourDate, 4);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Absence registration should succeed.');
        Assert.AreEqual('', ReadText(Response, 'warnings'), 'A working day should not warn.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Absence);
        Line.SetRange("Cause of Absence Code", CauseCode);
        Assert.IsTrue(Line.FindFirst(), 'The absence line should be stored.');
        Detail.SetRange("Time Sheet No.", SheetNo);
        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
        Detail.SetRange(Date, HourDate);
        Assert.IsTrue(Detail.FindFirst(), 'The hour should be stored on the absence line.');
        Assert.AreEqual(4, Detail.Quantity, 'The stored quantity should match the request.');
        Assert.AreEqual(Line.Type, Detail.Type, 'The detail must preserve the absence type for posting.');
        Assert.AreEqual(CauseCode, Detail."Cause of Absence Code", 'Posting must receive the cause of absence.');
    end;

    [Test]
    procedure Absence_Weekend_WarnsAndWrites()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        HourDate: Date;
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), true);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CreateCause());
        AddHour(Request, HourDate, 3);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Weekend hours should still be accepted.');
        Assert.IsTrue(ReadText(Response, 'warnings').Contains('InvalidParameter'), 'Weekend hours should warn.');
        Assert.IsTrue(ReadText(Response, 'warnings').Contains('Confirm the date or move the hours to a working day.'), 'The warning should name the next step.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Absence);
        Assert.IsFalse(Line.IsEmpty(), 'The weekend warning must still store the absence line.');
    end;


    [Test]
    procedure Absence_UnknownKey_IsRefused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', CreateSheet(CreateResource(true), WorkDate(), UserId()));
        Request.Add('causeOfAbsenceCode', CreateCause());
        Request.Add('bogus', 1);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Assert.AreEqual('UnknownParameter', ReadText(TempArgument.GetResponseJson(), 'code'), 'An unknown key must be refused.');
    end;

    [Test]
    procedure Absence_WrongCauseType_IsInvalidParameterFormat()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', CreateSheet(CreateResource(true), WorkDate(), UserId()));
        Request.Add('causeOfAbsenceCode', 5);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'causeOfAbsenceCode', 'Send the key with the documented type.');
    end;

    [Test]
    procedure Absence_SheetAndResource_IsConflictingIdentifiers()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ResourceNo: Code[20];
    begin
        ResourceNo := CreateResource(true);
        Request.Add('timeSheetNo', CreateSheet(ResourceNo, WorkDate(), UserId()));
        Request.Add('resourceNo', ResourceNo);
        Request.Add('causeOfAbsenceCode', CreateCause());
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(TempArgument.GetResponseJson(), 'code'), 'Two identifiers for one sheet must be refused.');
    end;

    [Test]
    procedure Absence_UnknownSheet_IsRecordNotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', 'NO-SUCH-TS');
        Request.Add('causeOfAbsenceCode', CreateCause());
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Assert.AreEqual('RecordNotFound', ReadText(TempArgument.GetResponseJson(), 'code'), 'An unknown sheet must be refused.');
    end;

    [Test]
    procedure Absence_ResourceAndDate_ResolvesSheet()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        HourDate: Date;
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), false);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('date', Format(HourDate, 0, 9));
        Request.Add('quantity', 3);
        Request.Add('causeOfAbsenceCode', CreateCause());
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Resource and date should find the sheet.');
        Assert.AreEqual(SheetNo, ReadText(Response, 'timeSheetNo'), 'The sheet should be the one covering the date.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Absence);
        Assert.IsFalse(Line.IsEmpty(), 'The absence line should be stored.');
    end;

    [Test]
    procedure Absence_TimeSheetAndDateAndQuantity_Registers()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        HourDate: Date;
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), false);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('date', Format(HourDate, 0, 9));
        Request.Add('quantity', 3);
        Request.Add('causeOfAbsenceCode', CreateCause());
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Time sheet number and date should register one quantity.');
    end;

    /// <summary>BC posts the registered details into Employee Absence with the requested cause.</summary>
    [Test]
    procedure Scenario_AC01_RegisteredAbsence_PostsWithCause()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Employee: Record Employee;
        EmployeeAbsence: Record "Employee Absence";
        ApprovalMgt: Codeunit "Time Sheet Approval Management";
        Request: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        CauseCode: Code[10];
        HourDate: Date;
    begin
        // [GIVEN] A time sheet belonging to an employee-linked resource.
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), false);
        CauseCode := CreateCause();
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CauseCode);
        AddHour(Request, HourDate, 4);
        // [WHEN] Registration succeeds and standard BC posts the line.
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Registration must succeed.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.FindFirst();
        ApprovalMgt.PostAbsence(Line);
        // [THEN] The employee absence carries the requested cause and hours.
        Employee.SetRange("Resource No.", ResourceNo);
        Employee.FindFirst();
        EmployeeAbsence.SetRange("Employee No.", Employee."No.");
        EmployeeAbsence.SetRange("Cause of Absence Code", CauseCode);
        EmployeeAbsence.SetRange("From Date", HourDate);
        Assert.IsTrue(EmployeeAbsence.FindFirst(), 'Standard posting must create the employee absence.');
        Assert.AreEqual(4, EmployeeAbsence.Quantity, 'Posted absence quantity.');
    end;

    /// <summary>Generic writes cannot bypass time-sheet validation; reads stay available.</summary>
    [Test]
    procedure Scenario_AC07_GenericTimeSheetWrites_Restricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
        TableNo: Integer;
        TableNumbers: List of [Integer];
    begin
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Header", false), 'Header writes must use dedicated messages.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Line", false), 'Line writes must use dedicated messages.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Time Sheet Detail", false), 'Detail writes must use dedicated messages.');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Time Sheet Line"), 'Line reads remain available.');
        TableNumbers.Add(Database::"Time Sheet Line");
        TableNumbers.Add(Database::"Time Sheet Detail");
        foreach TableNo in TableNumbers do begin
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.TimeSheetLine.CopyFromPrevious') > 0, 'The shared table hint must name Projects.TimeSheetLine.CopyFromPrevious.');
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.TimeSheetLine.CreateFromPlanning') > 0, 'The shared table hint must name Projects.TimeSheetLine.CreateFromPlanning.');
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.Absence.Register') > 0, 'The shared table hint must name Projects.Absence.Register.');
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.TimeSheet.Reopen') > 0, 'The shared table hint must name Projects.TimeSheet.Reopen.');
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.TimeSheet.Post') > 0, 'The shared table hint must name Projects.TimeSheet.Post.');
            Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(TableNo), 'Projects.TimeSheet.Archive') > 0, 'The shared table hint must name Projects.TimeSheet.Archive.');
        end;
        Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Line"), 'Projects.TimeSheet.Submit') > 0, 'The hint must name Projects.TimeSheet.Submit.');
        Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Line"), 'Projects.TimeSheet.Approve') > 0, 'The hint must name Projects.TimeSheet.Approve.');
        Assert.IsTrue(StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Time Sheet Line"), 'Projects.TimeSheet.Reject') > 0, 'The hint must name Projects.TimeSheet.Reject.');
    end;

    /// <summary>An out-of-period date is refused with the hours parameter and no write.</summary>
    [Test]
    procedure Scenario_AC07_OutsideSheetDates_RollsBack()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CreateCause());
        AddHour(Request, WorkDate() + 7, 4);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'hours', 'Send each date once and keep every date inside the time sheet period.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'No partial line may survive the refusal.');
    end;

    /// <summary>Repeated dates are refused before writing any absence records.</summary>
    [Test]
    procedure Scenario_AC07_DuplicateHourDates_RollsBack()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        HourDate: Date;
    begin
        EnsureHrSetup();
        ResourceNo := CreateResource(true);
        LinkEmployee(ResourceNo);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        EnsureAccountingPeriod(WorkDate());
        HourDate := DateInSheet(WorkDate(), false);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('causeOfAbsenceCode', CreateCause());
        AddHour(Request, HourDate, 4);
        AddHour(Request, HourDate, 2);
        Execute(TempArgument, "Message Type ori"::"Projects.Absence.Register", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'hours', 'Send each date once and keep every date inside the time sheet period.');
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'Duplicate hour dates must not leave a partial line.');
    end;

    /// <summary>The public help contract keeps chapters English and localizes its catalogue.</summary>
    [Test]
    procedure Scenario_AC08_IcelandicCatalogue_EnglishChapters()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Types: JsonArray;
        Response: JsonObject;
        EnglishRow: JsonObject;
        IcelandicRow: JsonObject;
        Token: JsonToken;
        EnglishParameters: Text;
        IcelandicParameters: Text;
    begin
        // Story #65, AC08 | Time: no dates | Risk: Foundation help-language contract
        // [GIVEN] Public help for the absence type in English and Icelandic.
        Types.Add('Projects.Absence.Register');
        Request.Add('messageTypes', Types);
        Request.Add('detail', 'full');
        Request.Add('lcid', 1033);
        Execute(TempArgument, "Message Type ori"::"Help.Implementation.Get", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'English help must succeed.');
        Response.SelectToken('result[0]', Token);
        EnglishRow := Token.AsObject();
        // [WHEN] The caller requests Icelandic help.
        Request.Replace('lcid', 1039);
        Execute(TempArgument, "Message Type ori"::"Help.Implementation.Get", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Icelandic help must succeed.');
        Response.SelectToken('result[0]', Token);
        IcelandicRow := Token.AsObject();
        // [THEN] Catalogue text translates; the complete parameter chapter stays English.
        Assert.AreEqual('Registers an absence line on a time sheet.', ReadText(EnglishRow, 'description'), 'English catalogue.');
        Assert.AreEqual('Skráir fjarvistarlínu á tímaskýrslu.', ReadText(IcelandicRow, 'description'), 'Icelandic catalogue.');
        EnglishParameters := ReadText(EnglishRow, 'parameters');
        IcelandicParameters := ReadText(IcelandicRow, 'parameters');
        Assert.IsTrue(EnglishParameters.Contains('causeOfAbsenceCode'), 'Help must include absence parameters.');
        Assert.AreEqual(EnglishParameters, IcelandicParameters, 'Help chapters remain English at both LCIDs.');
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

    local procedure DateInSheet(StartingDate: Date; WantWeekend: Boolean): Date
    var
        Candidate: Date;
        Offset: Integer;
    begin
        for Offset := 0 to 6 do begin
            Candidate := StartingDate + Offset;
            if WantWeekend = (Date2DWY(Candidate, 1) >= 6) then
                exit(Candidate);
        end;
        exit(StartingDate);
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
