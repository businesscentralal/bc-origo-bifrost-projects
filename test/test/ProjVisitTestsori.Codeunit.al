namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.Period;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Utilities;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Behavior tests for Projects.Visit.Start, Stop and Complete (projects#83).</summary>
codeunit 97186 "Proj. Visit Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        OtherOwnerTok: Label 'X83OTHER', Locked = true;

    [Test]
    procedure Scenario_AC01_TravelThenWork_WritesHours()
    var
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        TravelType: Code[10];
        Day: Date;
    begin
        // [GIVEN] A planned task, a travel work type and an open week for the caller.
        Day := Today();
        TravelType := CopyStr(Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false), 1, MaxStrLen(TravelType));
        // [WHEN] Travel starts at 08:00, work starts at 08:30 with autoStop, and work stops at 11:00.
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'travel', Clock(Day, 080000T), false, ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), 'Travel start.');
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 083000T), true, ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Assert.AreEqual(0.5, DecimalOf(Child(Response, 'stopped'), 'hours'), 'Travel hours.');
        Visit.Get(NumberOf(Child(Response, 'stopped'), 'visitId'));
        Assert.AreEqual(Visit.Status::Stopped, Visit.Status, 'Travel visit is stopped.');
        Assert.AreEqual(0.5, Visit."Hours Written", 'Stored travel hours.');
        Response := Run("Message Type ori"::"Projects.Visit.Stop", StopJson(NumberOf(Response, 'visitId'), Clock(Day, 110000T)));
        Assert.AreEqual('Success', TextOf(Response, 'status'), 'Work stop.');
        Assert.AreEqual(2.5, DecimalOf(Response, 'hours'), 'Work hours.');
        // [THEN] The hours sit on two open job lines for that day and nothing is submitted.
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange("Work Type Code", TravelType);
        if not Line.FindFirst() then begin
            Line.SetRange("Work Type Code");
            Line.Get(Visit."Time Sheet No.", Visit."Time Sheet Line No.");
            Assert.AreEqual(TravelType, Line."Work Type Code", 'Travel work type');
        end;
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Travel line stays open.');
        Detail.Get(SheetNo, Line."Line No.", Day);
        Assert.AreEqual(0.5, Detail.Quantity, 'Travel quantity.');
        Line.SetRange("Work Type Code", '');
        Assert.IsTrue(Line.FindFirst(), 'Work line.');
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Work line stays open.');
        Detail.Get(SheetNo, Line."Line No.", Day);
        Assert.AreEqual(2.5, Detail.Quantity, 'Work quantity.');
    end;

    [Test]
    procedure Scenario_AC02_CompleteMileage_StaysOpen()
    var
        Usage: Record "TS Usage Line ori";
        Line: Record "Time Sheet Line";
        Response: JsonObject;
        ResourceNo: Code[20];
        MileageNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
        VisitId: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false);
        MileageNo := MileageResource();
        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 090000T));
        Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 100000T)));
        Response := Run("Message Type ori"::"Projects.Visit.Complete", CompleteJson(VisitId, ProjectNo, TaskNo, 42, 'Done', ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.Get(NumberOf(Response, 'usageEntryNo'));
        Assert.AreEqual(Usage.Status::Open, Usage.Status, 'Usage stays open.');
        Assert.AreEqual(42, Usage.Quantity, 'Kilometres.');
        Assert.AreEqual(MileageNo, Usage."No.", 'Mileage resource.');
        Assert.AreEqual('', Usage."Journal Template Name", 'Nothing is transferred.');
        Line.Get(SheetNo, Usage."Time Sheet Line No.");
        Assert.AreEqual(Line.Status::Open, Line.Status, 'The sheet line is not submitted.');
        Assert.AreEqual('', Line."Work Type Code", 'Mileage uses the work line.');
    end;

    [Test]
    procedure Scenario_AC03_SameClientRequestId_WritesNothingNew()
    var
        Visit: Record "Proj. Field Visit ori";
        First: JsonObject;
        Second: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false);
        First := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 080000T), false, 'same-83'));
        Second := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 090000T), false, 'same-83'));
        Assert.AreEqual(TextOf(First, 'visitId'), TextOf(Second, 'visitId'), 'The first result is returned.');
        Visit.SetRange("Resource No.", ResourceNo);
        Assert.AreEqual(1, Visit.Count(), 'A repeat writes nothing new.');
    end;

    [Test]
    procedure Scenario_AC04_PlannedCreatesLine_UnplannedRefused()
    var
        Line: Record "Time Sheet Line";
        Setup: Record "Projects Setup ori";
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
        VisitId: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, false, 1, false);
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'PreconditionFailed', 'taskNo', 'Allow Unplanned Tasks');
        Setup.Get();
        Setup."Allow Unplanned Tasks" := true;
        Setup.Modify(true);
        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 080000T));
        Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 090000T)));
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange("Job No.", ProjectNo);
        Line.SetRange("Job Task No.", TaskNo);
        Assert.IsFalse(Line.IsEmpty(), 'A planned-or-allowed stop creates the job line.');
    end;

    [Test]
    procedure Scenario_AC04_PlannedCaller_MissingLineIsCreated()
    var
        Line: Record "Time Sheet Line";
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
        VisitId: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false);
        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 080000T));
        Line.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Line.IsEmpty(), 'Start does not invent a line before hours exist.');
        Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 090000T)));
        Assert.IsFalse(Line.IsEmpty(), 'Stop creates the missing job line.');
    end;

    [Test]
    procedure Scenario_AC05_Refusals_ChangeNothing()
    var
        Visit: Record "Proj. Field Visit ori";
        Job: Record Job;
        JobTask: Record "Job Task";
        LibraryJob: Codeunit "Library - Job";
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        OtherTask: Code[20];
        Day: Date;
        VisitId: Integer;
        Before: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false);
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson('', TaskNo, 'work', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'MissingParameter', 'projectNo', 'missing key');
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'fly', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'InvalidParameterFormat', 'kind', 'documented type');
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', 'yesterday', false, ''));
        AssertRefusal(Response, 'InvalidParameterFormat', 'at', 'documented type');
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, 'MISSING', 'work', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'RecordNotFound', 'taskNo', 'exists');
        Response := Run("Message Type ori"::"Projects.Visit.Start", UnknownStart(ProjectNo, TaskNo));
        AssertRefusal(Response, 'UnknownParameter', 'extra', 'unknown key');
        Response := Run("Message Type ori"::"Projects.Visit.Stop", StopJson(0, Clock(Day, 090000T)));
        AssertRefusal(Response, 'RecordNotFound', 'visitId', 'exists');
        Visit.SetRange("Resource No.", ResourceNo);
        Assert.AreEqual(0, Visit.Count(), 'Refusals write no visit.');

        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 100000T));
        Before := Visit.Count();
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 110000T), false, ''));
        AssertRefusal(Response, 'PreconditionFailed', 'autoStop', 'Projects.Visit.Stop');
        Response := Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 090000T)));
        AssertRefusal(Response, 'PreconditionFailed', 'at', 'after the start');
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day - 3, 080000T), false, ''));
        AssertRefusal(Response, 'PreconditionFailed', 'at', 'client time tolerance');
        Job.Get(ProjectNo);
        LibraryJob.CreateJobTask(Job, JobTask);
        OtherTask := JobTask."Job Task No.";
        Response := Run("Message Type ori"::"Projects.Visit.Complete", CompleteJson(VisitId, ProjectNo, OtherTask, 0, '', ''));
        AssertRefusal(Response, 'ConflictingIdentifiers', 'visitId', 'omit the project');
        Response := Run("Message Type ori"::"Projects.Visit.Complete", CompleteJson(VisitId, ProjectNo, TaskNo, -5, '', ''));
        AssertRefusal(Response, 'InvalidParameterFormat', 'mileageKm', 'documented type');
        Visit.Get(VisitId);
        Assert.AreEqual(Visit.Status::Running, Visit.Status, 'A refused complete leaves the visit running.');
        Assert.AreEqual(Before, Visit.Count(), 'A refused call adds no visit.');
    end;

    [Test]
    procedure Scenario_AC05_NoSheet_LockedLine_AndOtherVisit()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
        ForeignId: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 1, false);
        Header.Get(SheetNo);
        Header.Delete(true);
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'PreconditionFailed', '', 'Projects.MyTimeSheet.Create');
        SheetNo := InsertSheet(ResourceNo, Day);
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Day;
        Line.Type := Line.Type::Job;
        Line."Job No." := ProjectNo;
        Line."Job Task No." := TaskNo;
        Line.Status := Line.Status::Submitted;
        Line.Insert(false);
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, 'work', Clock(Day, 080000T), false, ''));
        AssertRefusal(Response, 'PreconditionFailed', 'taskNo', 'open or rejected');
        Visit.Init();
        Visit."Resource No." := 'X83OTHER';
        Visit."Project No." := ProjectNo;
        Visit."Task No." := TaskNo;
        Visit.Date := Day;
        Visit.Status := Visit.Status::Running;
        Visit."Started At" := CurrentDateTime();
        Visit.Insert(true);
        ForeignId := Visit."Entry No.";
        Response := Run("Message Type ori"::"Projects.Visit.Stop", StopJson(ForeignId, Clock(Day, 120000T)));
        AssertRefusal(Response, 'PermissionDenied', 'visitId', 'your own resource');
        Visit.Get(ForeignId);
        Assert.AreEqual(Visit.Status::Running, Visit.Status, 'Another technician''s visit is unchanged.');
    end;

    [Test]
    procedure Scenario_Edge_Rounding15_AndZeroHours()
    var
        Detail: Record "Time Sheet Detail";
        Visit: Record "Proj. Field Visit ori";
        ResourceNo: Code[20];
        SheetNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Day: Date;
        VisitId: Integer;
    begin
        Day := Today();
        Prepare(ResourceNo, SheetNo, ProjectNo, TaskNo, Day, true, 15, false);
        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 080000T));
        Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 081000T)));
        Visit.Get(VisitId);
        Assert.AreEqual(0.25, Visit."Hours Written", 'Ten minutes rounds to 15. Status ' + Format(Visit.Status));
        Detail.SetRange("Time Sheet No.", SheetNo);
        Detail.CalcSums(Quantity);
        Assert.AreEqual(0.25, Detail.Quantity, 'The rounded hours are added.');
        VisitId := StartedVisit(ProjectNo, TaskNo, 'work', Clock(Day, 090000T));
        Run("Message Type ori"::"Projects.Visit.Stop", StopJson(VisitId, Clock(Day, 090000T)));
        Visit.Get(VisitId);
        Assert.AreEqual(0, Visit."Hours Written", 'Zero duration writes zero hours.');
        Assert.AreEqual(0, Visit."Time Sheet Line No.", 'Zero hours does not claim a line.');
        Assert.AreEqual(1, Detail.Count(), 'Zero hours does not insert a detail.');
    end;

    [Test]
    procedure Scenario_AC08_GenericFieldWrite_Refused()
    var
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        Fields: JsonObject;
    begin
        // Do not turn change logging on here. The platform caches that choice for the session,
        // and the later PROJ VISIT test cannot insert change log entries.
        ClearVisitChangeLog();
        Visit.Init();
        Visit."Resource No." := 'X83HINT';
        Visit.Status := Visit.Status::Running;
        Visit.Insert(true);
        Fields.Add('Status', 'Stopped');
        Response := GenericWrite(Visit."Entry No.", Fields);
        Assert.AreEqual('Error', TextOf(Response, 'status'), 'Status is closed.');
        Assert.AreEqual('PermissionDenied', TextOf(Response, 'code'), 'Dedicated refusal.');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains('Projects.Visit.Start'), 'The hint names the visit types.');
        Visit.Get(Visit."Entry No.");
        Assert.AreEqual(Visit.Status::Running, Visit.Status, 'Status is unchanged.');
    end;

    [Test]
    procedure Scenario_AC09_Help_EnglishChapters_TranslatedDiscovery()
    begin
        AssertHelp("Message Type ori"::"Projects.Visit.Start");
        AssertHelp("Message Type ori"::"Projects.Visit.Stop");
        AssertHelp("Message Type ori"::"Projects.Visit.Complete");
    end;

    local procedure AssertHelp(MessageType: Enum "Message Type ori")
    var
        Api: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        English: Text;
        Icelandic: Text;
        EnglishKeywords: Text;
        IcelandicKeywords: Text;
        Overview: Text;
        IcelandicOverview: Text;
        Notes: Text;
        Previous: Integer;
    begin
        Api := MessageType;
        Contract := MessageType;
        Discovery := MessageType;
        Previous := GlobalLanguage();
        GlobalLanguage(1033);
        English := Api.GetDescription();
        EnglishKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(Overview), 'Overview.');
        Assert.IsTrue(Contract.GetNotes(Notes), 'Notes.');
        Assert.IsFalse(English.Contains('message type'), 'No message type wording.');
        Assert.IsFalse(Overview.Contains('codeunit'), 'No AL object name.');
        GlobalLanguage(1039);
        Icelandic := Api.GetDescription();
        IcelandicKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(IcelandicOverview), 'Icelandic overview.');
        Assert.AreNotEqual(English, Icelandic, 'Discovery is translated.');
        Assert.AreEqual(EnglishKeywords.Split(',').Count(), IcelandicKeywords.Split(',').Count(), 'Keyword counts match.');
        Assert.AreEqual(Overview, IcelandicOverview, 'Chapters stay English.');
        GlobalLanguage(Previous);
    end;

    local procedure Prepare(var ResourceNo: Code[20]; var SheetNo: Code[20]; var ProjectNo: Code[20]; var TaskNo: Code[20]; Day: Date; Planned: Boolean; Rounding: Integer; Unplanned: Boolean): Code[20]
    var
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        Setup: Record "Projects Setup ori";
        Mileage: Record Resource;
        WorkType: Record "Work Type";
        LibraryJob: Codeunit "Library - Job";
        LibraryTimeSheet: Codeunit "Library - Time Sheet";
        MileageNo: Code[20];
    begin
        Isolate();
        ClearVisitChangeLog();
        OpenAccountingPeriod(Day);
        ResourceNo := CreateResource(UserId());
        MileageNo := CreateResource(OtherOwnerTok);
        Mileage.Get(ResourceNo);
        WorkType.Init();
        WorkType.Code := CopyStr('T83' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(WorkType.Code));
        WorkType.Description := 'Travel';
        // Time Sheet Line rejects a work type whose unit differs from the resource.
        WorkType.Validate("Unit of Measure Code", Mileage."Base Unit of Measure");
        WorkType.Insert(true);
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Travel Work Type Code" := WorkType.Code;
        Setup."Mileage Resource No." := MileageNo;
        Setup."Rounding Minutes" := Rounding;
        Setup."Client Time Tolerance Hours" := 24;
        Setup."Allow Unplanned Tasks" := Unplanned;
        Setup.Modify(true);
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        ProjectNo := Job."No.";
        TaskNo := JobTask."Job Task No.";
        if Planned then
            LibraryTimeSheet.CreateJobPlanningLine(Planning, ProjectNo, TaskNo, ResourceNo, Day);
        SheetNo := InsertSheet(ResourceNo, Day);
        exit(WorkType.Code);
    end;

    local procedure ClearVisitChangeLog()
    var
        LogTable: Record "Change Log Setup (Table)";
        LogField: Record "Change Log Setup (Field)";
        ChangeLogMgt: Codeunit "Change Log Management";
    begin
        LogField.SetRange("Table No.", Database::"Proj. Field Visit ori");
        if not LogField.IsEmpty() then
            LogField.DeleteAll();
        if LogTable.Get(Database::"Proj. Field Visit ori") then
            LogTable.Delete();
        Clear(ChangeLogMgt);
    end;

    local procedure OpenAccountingPeriod(Day: Date)
    var
        AccountingPeriod: Record "Accounting Period";
    begin
        // CRONUS Ísland keeps the current month closed. Hour lines refuse a closed period.
        AccountingPeriod.SetFilter("Starting Date", '..%1', Day);
        if not AccountingPeriod.FindLast() then
            exit;
        if not AccountingPeriod.Closed then
            exit;
        AccountingPeriod.Closed := false;
        AccountingPeriod.Modify();
    end;

    local procedure MileageResource(): Code[20]
    var
        Setup: Record "Projects Setup ori";
    begin
        Setup.Get();
        exit(Setup."Mileage Resource No.");
    end;

    local procedure StartedVisit(ProjectNo: Code[20]; TaskNo: Code[20]; Kind: Text; At: Text): Integer
    var
        Response: JsonObject;
    begin
        Response := Run("Message Type ori"::"Projects.Visit.Start", StartJson(ProjectNo, TaskNo, Kind, At, false, ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), 'Visit start.');
        exit(NumberOf(Response, 'visitId'));
    end;

    local procedure Run(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        MsgInterface: Interface "Msg Interface ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        Commit();
        MsgInterface.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure StartJson(ProjectNo: Code[20]; TaskNo: Code[20]; Kind: Text; At: Text; AutoStop: Boolean; RequestId: Text) Request: JsonObject
    begin
        if ProjectNo <> '' then
            Request.Add('projectNo', ProjectNo);
        if TaskNo <> '' then
            Request.Add('taskNo', TaskNo);
        Request.Add('kind', Kind);
        Request.Add('at', At);
        if AutoStop then
            Request.Add('autoStop', true);
        if RequestId <> '' then
            Request.Add('clientRequestId', RequestId);
    end;

    local procedure StopJson(VisitId: Integer; At: Text) Request: JsonObject
    begin
        if VisitId <> 0 then
            Request.Add('visitId', VisitId);
        Request.Add('at', At);
    end;

    local procedure CompleteJson(VisitId: Integer; ProjectNo: Code[20]; TaskNo: Code[20]; Mileage: Decimal; Outcome: Text; RequestId: Text) Request: JsonObject
    begin
        if VisitId <> 0 then
            Request.Add('visitId', VisitId);
        if ProjectNo <> '' then
            Request.Add('projectNo', ProjectNo);
        if TaskNo <> '' then
            Request.Add('taskNo', TaskNo);
        if Mileage <> 0 then
            Request.Add('mileageKm', Mileage);
        if Outcome <> '' then
            Request.Add('outcome', Outcome);
        if RequestId <> '' then
            Request.Add('clientRequestId', RequestId);
    end;

    local procedure UnknownStart(ProjectNo: Code[20]; TaskNo: Code[20]) Request: JsonObject
    begin
        Request := StartJson(ProjectNo, TaskNo, 'work', Clock(Today(), 080000T), false, '');
        Request.Add('extra', 'no');
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; ExpectedNextPart: Text)
    begin
        Assert.AreEqual('Error', TextOf(Response, 'status'), 'Refused.');
        Assert.AreEqual(ExpectedCode, TextOf(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(ExpectedParameter, TextOf(Response, 'parameter'), 'Refusal parameter.');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains(ExpectedNextPart), TextOf(Response, 'nextStep'));
    end;

    local procedure GenericWrite(EntryNo: Integer; Fields: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        PrimaryKey: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        Request: JsonObject;
        ContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        PrimaryKey.Add('EntryNo_', EntryNo);
        Row.Add('primaryKey', PrimaryKey);
        Row.Add('fields', Fields);
        Rows.Add(Row);
        Request.Add('tableId', Database::"Proj. Field Visit ori");
        Request.Add('data', Rows);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'XVISIT83', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure Dump(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
        Result := CopyStr(Result, 1, 240);
    end;

    local procedure TextOf(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure DecimalOf(Response: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
        Value: Decimal;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                Evaluate(Value, Token.AsValue().AsText(), 9);
        exit(Value);
    end;

    local procedure NumberOf(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
    end;

    local procedure Child(Response: JsonObject; Name: Text) Node: JsonObject
    var
        Token: JsonToken;
    begin
        Response.Get(Name, Token);
        Node := Token.AsObject();
    end;

    local procedure Clock(Day: Date; At: Time): Text
    begin
        exit(Format(CreateDateTime(Day, At), 0, 9));
    end;

    local procedure Today(): Date
    begin
        exit(DT2Date(CurrentDateTime()));
    end;

    local procedure Isolate()
    var
        Resource: Record Resource;
    begin
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", OtherOwnerTok, false);
    end;

    local procedure CreateResource(Owner: Text): Code[20]
    var
        Resource: Record Resource;
        UnitOfMeasure: Record "Unit of Measure";
        LibraryResource: Codeunit "Library - Resource";
    begin
        LibraryResource.CreateResourceNew(Resource);
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
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(Owner), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Modify(true);
        exit(Resource."No.");
    end;

    local procedure InsertSheet(ResourceNo: Code[20]; Day: Date): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := CopyStr('X83' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := Day;
        Header."Ending Date" := Day + 6;
        Header."Owner User ID" := CopyStr(UpperCase(UserId()), 1, MaxStrLen(Header."Owner User ID"));
        Header.Insert(false);
        exit(Header."No.");
    end;
}
