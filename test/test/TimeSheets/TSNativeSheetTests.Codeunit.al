namespace Origo.Bifrost.Projects;

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

/// <summary>Behavior tests for the native time sheet message types.</summary>
codeunit 97148 "TS Native Sheet Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC05_MissingKey_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;

    [Test]
    procedure Scenario_AC05_UnknownKey_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', 'TS');
        Request.Add('extra', 'x');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'UnknownParameter', 'extra', 'Remove the unknown key.');
    end;

    [Test]
    procedure Scenario_AC02_NotOwner_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), 'OTHER');
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'PermissionDenied', 'timeSheetNo', 'Only the owner can submit; ask the owner.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual('Open', Format(Line.Status), 'A refused submit must leave the line open.');
    end;

    [Test]
    procedure Scenario_AC03_NoLines_PreconditionFailed()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'lineNos', 'Add lines first.');
    end;

    [Test]
    procedure Scenario_AC01_AC06_SubmitAndRetry_Unchanged()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Submit should succeed.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual('Submitted', Format(Line.Status), 'The open line should be submitted.');

        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Submitting again should succeed.');
        Assert.IsTrue(ReadText(Response, 'lines').Contains('"changed":false'), 'The submitted line must be returned explicitly as unchanged.');
    end;

    [Test]
    procedure Scenario_AC04_BadJobLine_InvalidLine()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Line.Get(SheetNo, 10000);
        Line.Type := Line.Type::Job;
        Line.Status := Line.Status::Open;
        Line.Modify(false);
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Fix the line and submit again.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual('Open', Format(Line.Status), 'A failed submit must roll the line back.');
    end;

    [Test]
    procedure Scenario_AC01_ResourceAndDate_Submits()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        ResourceNo: Code[20];
        SheetNo: Code[20];
    begin
        // [GIVEN] An owned time sheet and an open line with quantity.
        ResourceNo := CreateResource(true);
        SheetNo := CreateSheet(ResourceNo, WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('resourceNo', ResourceNo);
        Request.Add('date', Format(WorkDate(), 0, 9));
        // [WHEN] The alternative identifier resolves the time sheet.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        // [THEN] The exact line is submitted.
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Submit succeeds.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Alternative identifier selects the correct sheet.');
    end;

    [Test]
    procedure Scenario_AC01_SelectedLine_LeavesOtherOpen()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        LineNos: JsonArray;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        CreateLine(SheetNo, 20000, 'Open');
        LineNos.Add(20000);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Selected submit succeeds.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Unselected line stays open.');
        Line.Get(SheetNo, 20000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Selected line is submitted.');
    end;

    [Test]
    procedure Scenario_AC03_ApprovedOnly_PreconditionFailed()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Approved');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'PreconditionFailed', 'lineNos', 'Add lines first.');
    end;

    [Test]
    procedure Scenario_AC04_MixedValidInvalid_RollsBackAll()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // [GIVEN] Valid first line and invalid project line later in the selection.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        CreateLine(SheetNo, 20000, 'Open');
        Line.Get(SheetNo, 20000);
        Line.Type := Line.Type::Job;
        Line.Modify(false);
        Request.Add('timeSheetNo', SheetNo);
        // [WHEN] Standard BC Submit rejects the second line.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        // [THEN] The first submission is rolled back with the second, not partially committed.
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Fix the line and submit again.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Earlier valid line must roll back.');
        Line.Get(SheetNo, 20000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Invalid line stays open.');
    end;

    [Test]
    procedure Scenario_AC05_WrongTypedIdentifier_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', 42);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    [Test]
    procedure Scenario_AC05_ConflictingIdentifiers_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', 'X60');
        Request.Add('resourceNo', 'X60');
        Request.Add('date', '2026-11-02');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'timeSheetNo', 'Send only one identifier for the time sheet.');
    end;

    [Test]
    procedure Scenario_AC05_MissingSheet_RecordNotFound()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('timeSheetNo', CopyStr(Format(CreateGuid(), 0, 4), 1, 20));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'timeSheetNo', 'Use an identifier that exists.');
    end;

    [Test]
    procedure Scenario_AC06_EmptySelection_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        LineNos: JsonArray;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        Assert.AreEqual('[]', ReadText(TempArgument.GetResponseJson(), 'lines'), 'Empty selection must return an explicit empty array.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Empty selection cannot submit any line.');
    end;

    [Test]
    procedure Scenario_AC05_OutOfRangeLineNo_CleanRefusal()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        LineNos: JsonArray;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineNos.Add(2147483648.0);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'lineNos', 'Send the key with the documented type.');
    end;

    [Test]
    procedure Scenario_AC09_OmitCommit_CleanRefusal()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Impl: Codeunit "TS Sheet Submit Impl ori";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        TempArgument.Type := "Message Type ori"::"Projects.TimeSheet.Submit";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument."Omit Commit" := true;
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        Request.Add('timeSheetNo', SheetNo);
        TempArgument.SetRequestJson(Request);
        Impl.ExecuteBifrostTask(TempArgument);
        AssertRefusal(TempArgument, 'PreconditionFailed', '', 'Submit outside an uncommitted batch.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Refused batch writes no line.');
    end;

    [Test]
    procedure Scenario_AC10_IcelandicHelp_IsLocalized()
    var
        Parts: Codeunit "TS Contract Parts ori";
        English: Text;
        Icelandic: Text;
        OriginalLanguage: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Parts.GetOverview("Message Type ori"::"Projects.TimeSheet.Submit", English);
        GlobalLanguage(1039);
        Parts.GetOverview("Message Type ori"::"Projects.TimeSheet.Submit", Icelandic);
        GlobalLanguage(OriginalLanguage);
        Assert.IsTrue(English.Contains('owner'), 'English overview describes owner submission.');
        Assert.IsTrue(Icelandic.Contains('eiganda'), 'Icelandic overview must be translated.');
    end;

    [Test]
    procedure Scenario_AC08_GenericStatusWrite_Denied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        RecordJson: JsonObject;
        PrimaryKey: JsonObject;
        Fields: JsonObject;
        Records: JsonArray;
        SheetNo: Code[20];
        LanguageId: Integer;
        LanguageIds: List of [Integer];
        PreviousLanguage: Integer;
    begin
        // [GIVEN] An owned open line, with no bypass of field restrictions or write guards.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        PrimaryKey.Add('TimeSheetNo', SheetNo);
        PrimaryKey.Add('LineNo', 10000);
        Fields.Add('Status', 'Submitted');
        RecordJson.Add('primaryKey', PrimaryKey);
        RecordJson.Add('fields', Fields);
        Records.Add(RecordJson);
        Request.Add('tableId', Database::"Time Sheet Line");
        Request.Add('data', Records);
        PreviousLanguage := GlobalLanguage();
        LanguageIds.Add(1033);
        LanguageIds.Add(1039);
        foreach LanguageId in LanguageIds do begin
            GlobalLanguage(LanguageId);
            // [WHEN] The real generic message implementation processes the protected field.
            DispatchGenericWrite(TempArgument, Request);
            // [THEN] The dedicated-type hint is composed by Foundation and nothing is written.
            Assert.AreEqual('PermissionDenied', ReadText(TempArgument.GetResponseJson(), 'code'), 'Status must be protected.');
            Assert.IsTrue(StrPos(ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'Projects.TimeSheet.Submit') > 0, 'The hint must name Projects.TimeSheet.Submit.');
            Assert.IsTrue(StrPos(ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'Projects.TimeSheet.Approve') > 0, 'The hint must name Projects.TimeSheet.Approve.');
            Assert.IsTrue(StrPos(ReadText(TempArgument.GetResponseJson(), 'nextStep'), 'Projects.TimeSheet.Reject') > 0, 'The hint must name Projects.TimeSheet.Reject.');
            Line.Get(SheetNo, 10000);
            Assert.AreEqual(Line.Status::Open, Line.Status, 'Generic status writes must leave the line open.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Scenario_AC09_EmptyLine_FollowsBCPolicy()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Detail: Record "Time Sheet Detail";
        Line: Record "Time Sheet Line";
        Setup: Record "Resources Setup";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // [GIVEN] An empty line and the standard policy to reject empty submissions.
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Detail.SetRange("Time Sheet No.", SheetNo);
        Detail.DeleteAll();
        EnsureSetup(Setup);
        Setup."Time Sheet Submission Policy" := Setup."Time Sheet Submission Policy"::"Stop and Show Empty Line Error";
        Setup.Modify();
        Request.Add('timeSheetNo', SheetNo);
        // [WHEN] Submit follows the native BC operation rather than assigning Status directly.
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Submit", Request);
        // [THEN] The native refusal is clean and the line stays open.
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Fix the line and submit again.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Standard empty-line policy must be preserved.');
    end;

    local procedure DispatchGenericWrite(var TempArgument: Record "Message Argument ori" temporary; Request: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
        Response: JsonObject;
    begin
        // Use the public entry point: it derives the licence context from the real company.
        // Directly invoking the generic implementation omits that context and is not equivalent.
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'XSUBMIT60', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        TempArgument.SetResponseJson(Response);
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
        Resource.Rename(CopyStr('X60' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Resource."No.")));
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
        Header."No." := CopyStr('X60' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
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
            else
                Line.Status := Line.Status::Open;
        end;
        Line.Insert(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := LineNo;
        Detail.Date := Header."Starting Date";
        Detail.Quantity := 8;
        Detail.Insert(false);
    end;

    local procedure EnsureSetup(var ResourcesSetup: Record "Resources Setup")
    begin
        if not ResourcesSetup.Get() then begin
            ResourcesSetup.Init();
            ResourcesSetup.Insert();
        end;
    end;

}
