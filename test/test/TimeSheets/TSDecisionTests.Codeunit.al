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

/// <summary>Behavior tests for the issue 63 approval and rejection messages.</summary>
codeunit 97145 "TS Decision Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Issue 89: Approve help hides internal parameters at locale 1033.</summary>
    [Test]
    procedure ApproveHelp1033_HidesInternalParameters()
    begin
        // [SCENARIO] The complete decision contract exposes only public request parameters.
        AssertPublicDecisionContract("Message Type ori"::"Projects.TimeSheet.Approve", 1033);
    end;

    /// <summary>Issue 89: Approve help hides internal parameters at locale 1039.</summary>
    [Test]
    procedure ApproveHelp1039_HidesInternalParameters()
    begin
        // [SCENARIO] The complete decision contract exposes only public request parameters.
        AssertPublicDecisionContract("Message Type ori"::"Projects.TimeSheet.Approve", 1039);
    end;

    /// <summary>Issue 89: Reject help hides internal parameters at locale 1033.</summary>
    [Test]
    procedure RejectHelp1033_HidesInternalParameters()
    begin
        // [SCENARIO] The complete decision contract exposes only public request parameters.
        AssertPublicDecisionContract("Message Type ori"::"Projects.TimeSheet.Reject", 1033);
    end;

    /// <summary>Issue 89: Reject help hides internal parameters at locale 1039.</summary>
    [Test]
    procedure RejectHelp1039_HidesInternalParameters()
    begin
        // [SCENARIO] The complete decision contract exposes only public request parameters.
        AssertPublicDecisionContract("Message Type ori"::"Projects.TimeSheet.Reject", 1039);
    end;

    [Test]
    procedure Scenario_AC03_Approve_NotApprover_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC03 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        SetApprover(SheetNo, 'XOTHER');
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'PermissionDenied', 'timeSheetNo', 'Only the approver named on the time sheet can approve.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'A refused approval must leave the line submitted.');
    end;

    [Test]
    procedure Scenario_AC04_Approve_OpenLine_MustBeSubmittedFirst()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Lines: JsonArray;
        SheetNo: Code[20];
    begin
        // Story #63, AC04 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        SetApprover(SheetNo, UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Lines.Add(10000);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', Lines);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Submit it first with Projects.TimeSheet.Submit.');
    end;

    [Test]
    procedure Scenario_AC06_Approve_Submitted_ThenUnchanged()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC06 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        SetApprover(SheetNo, UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Approve should succeed.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Approved, Line.Status, 'The submitted line should be approved.');

        Request.Add('lineNos', OneLine());
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Approving again should succeed.');
        Assert.IsFalse(ReadText(Response, 'lines').Contains('"changed":true'), 'An already approved line should not change.');
    end;

    [Test]
    procedure Scenario_AC02_Reject_WithComment()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Comment: Record "Time Sheet Comment Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC02 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        SetApprover(SheetNo, UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('comment', 'Please split the job.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Reject should succeed.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Rejected, Line.Status, 'The line should be rejected.');
        Comment.SetRange("No.", SheetNo);
        Comment.SetRange("Time Sheet Line No.", 10000);
        Assert.IsFalse(Comment.IsEmpty(), 'The comment should be stored on the line.');
    end;

    /// <summary>Verifies Scenario AC05 Approve MissingIdentifier Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_MissingIdentifier_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;

    /// <summary>Verifies Scenario AC05 Approve WrongIdentifierType Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_WrongIdentifierType_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 23);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC05 Approve OverlongIdentifier Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_OverlongIdentifier_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', PadStr('X', 21, 'X'));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC05 Approve UnknownKey Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_UnknownKey_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('unexpected', true);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'UnknownParameter', 'unexpected', 'Remove the unknown key.');
    end;

    /// <summary>Verifies Scenario AC05 Approve UnknownSheet Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_UnknownSheet_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 'X63-MISSING');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'timeSheetNo', 'Use an identifier that exists.');
        AssertMissingSheetCaption(TempArgument);
    end;

    /// <summary>Verifies Scenario AC05 Approve ConflictingIdentifiers Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_ConflictingIdentifiers_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 'X63-MISSING');
        Request.Add('timeSheetId', Format(CreateGuid(), 0, 4));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'timeSheetNo', 'Send only one identifier for the time sheet.');
    end;

    /// <summary>Verifies Scenario AC07 Approve ReadRole Denied.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC07_Approve_ReadRole_Denied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Impl: Interface "Msg Interface ori";
    begin
        // Story #63, AC07 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        // [GIVEN] Read role without native write permissions.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Impl := "Message Type ori"::"Projects.TimeSheet.Approve";
        // [WHEN] Discovery and execution use the same permission boundary.
        Assert.IsFalse(Impl.IsEnabled(), 'Read role must not enable this write.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        // [THEN] No sheet access or write occurs.
        AssertRefusal(TempArgument, 'PermissionDenied', '', 'Assign the BIFROST Full ori and PROJ TS ADMIN ori permission sets.');
    end;

    /// <summary>Verifies Scenario AC14 Approve EmptySelection WritesNothing.</summary>
    [Test]
    procedure Scenario_AC14_Approve_EmptySelection_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        EmptyLines: JsonArray;
        SheetNo: Code[20];
    begin
        // Story #63, AC14 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', EmptyLines);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Empty selection succeeds.');
        Assert.AreEqual('[]', ReadText(TempArgument.GetResponseJson(), 'lines'), 'No selected lines.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Empty selection must not change a line.');
    end;

    /// <summary>Verifies Scenario AC05 Approve LineNumberOverflow Refused.</summary>
    [Test]
    procedure Scenario_AC05_Approve_LineNumberOverflow_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
        LineNos: JsonArray;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineNos.ReadFrom('[2147483648]');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'lineNos', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC04 Approve MixedInvalidLines WritesNothing.</summary>
    [Test]
    procedure Scenario_AC04_Approve_MixedInvalidLines_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
        LineNos: JsonArray;
    begin
        // Story #63, AC04 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        CreateLine(SheetNo, 20000, 'Rejected');
        LineNos.ReadFrom('[10000,20000]');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Submit it first with Projects.TimeSheet.Submit.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Validation must be atomic.');
    end;

    /// <summary>Verifies Scenario AC14 Approve NoSubmittedLines ReturnsEmpty.</summary>
    [Test]
    procedure Scenario_AC14_Approve_NoSubmittedLines_ReturnsEmpty()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC14 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'No submitted lines succeeds.');
        Assert.AreEqual('[]', ReadText(TempArgument.GetResponseJson(), 'lines'), 'Open lines must not appear as approved or rejected.');
    end;

    /// <summary>Verifies Scenario AC05 Reject MissingIdentifier Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_MissingIdentifier_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'MissingParameter', 'timeSheetNo', 'Send the missing key.');
    end;

    /// <summary>Verifies Scenario AC05 Reject WrongIdentifierType Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_WrongIdentifierType_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 23);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC05 Reject OverlongIdentifier Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_OverlongIdentifier_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', PadStr('X', 21, 'X'));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'timeSheetNo', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC05 Reject UnknownKey Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_UnknownKey_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('unexpected', true);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'UnknownParameter', 'unexpected', 'Remove the unknown key.');
    end;

    /// <summary>Verifies Scenario AC05 Reject UnknownSheet Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_UnknownSheet_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 'X63-MISSING');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'RecordNotFound', 'timeSheetNo', 'Use an identifier that exists.');
        AssertMissingSheetCaption(TempArgument);
    end;

    /// <summary>Verifies Scenario AC05 Reject ConflictingIdentifiers Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_ConflictingIdentifiers_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('timeSheetNo', 'X63-MISSING');
        Request.Add('timeSheetId', Format(CreateGuid(), 0, 4));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'ConflictingIdentifiers', 'timeSheetNo', 'Send only one identifier for the time sheet.');
    end;

    /// <summary>Verifies Scenario AC07 Reject ReadRole Denied.</summary>
    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure Scenario_AC07_Reject_ReadRole_Denied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Impl: Interface "Msg Interface ori";
    begin
        // Story #63, AC07 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        // [GIVEN] Read role without native write permissions.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Impl := "Message Type ori"::"Projects.TimeSheet.Reject";
        // [WHEN] Discovery and execution use the same permission boundary.
        Assert.IsFalse(Impl.IsEnabled(), 'Read role must not enable this write.');
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        // [THEN] No sheet access or write occurs.
        AssertRefusal(TempArgument, 'PermissionDenied', '', 'Assign the BIFROST Full ori and PROJ TS ADMIN ori permission sets.');
    end;

    /// <summary>Verifies Scenario AC14 Reject EmptySelection WritesNothing.</summary>
    [Test]
    procedure Scenario_AC14_Reject_EmptySelection_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        EmptyLines: JsonArray;
        SheetNo: Code[20];
    begin
        // Story #63, AC14 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', EmptyLines);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Empty selection succeeds.');
        Assert.AreEqual('[]', ReadText(TempArgument.GetResponseJson(), 'lines'), 'No selected lines.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Empty selection must not change a line.');
    end;

    /// <summary>Verifies Scenario AC05 Reject LineNumberOverflow Refused.</summary>
    [Test]
    procedure Scenario_AC05_Reject_LineNumberOverflow_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
        LineNos: JsonArray;
    begin
        // Story #63, AC05 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        LineNos.ReadFrom('[2147483648]');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'lineNos', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC04 Reject MixedInvalidLines WritesNothing.</summary>
    [Test]
    procedure Scenario_AC04_Reject_MixedInvalidLines_WritesNothing()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
        LineNos: JsonArray;
    begin
        // Story #63, AC04 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        CreateLine(SheetNo, 20000, 'Rejected');
        LineNos.ReadFrom('[10000,20000]');
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNos', LineNos);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'InvalidLine', 'lineNos', 'Submit it first with Projects.TimeSheet.Submit.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Validation must be atomic.');
    end;

    /// <summary>Verifies Scenario AC14 Reject NoSubmittedLines ReturnsEmpty.</summary>
    [Test]
    procedure Scenario_AC14_Reject_NoSubmittedLines_ReturnsEmpty()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC14 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Open');
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'No submitted lines succeeds.');
        Assert.AreEqual('[]', ReadText(TempArgument.GetResponseJson(), 'lines'), 'Open lines must not appear as approved or rejected.');
    end;

    /// <summary>Verifies Scenario AC02 Reject OverlongComment Refused.</summary>
    [Test]
    procedure Scenario_AC02_Reject_OverlongComment_Refused()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #63, AC02 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Request.Add('comment', PadStr('X', 81, 'X'));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Reject", Request);
        AssertRefusal(TempArgument, 'InvalidParameterFormat', 'comment', 'Send the key with the documented type.');
    end;

    /// <summary>Verifies Scenario AC01 Approve SystemId SelectsOnlySubmitted.</summary>
    [Test]
    procedure Scenario_AC01_Approve_SystemId_SelectsOnlySubmitted()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC01 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        CreateLine(SheetNo, 20000, 'Open');
        Header.Get(SheetNo);
        Request.Add('timeSheetId', Format(Header.SystemId, 0, 4));
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'SystemId approves.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Approved, Line.Status, 'Selected submitted line approved.');
        Line.Get(SheetNo, 20000);
        Assert.AreEqual(Line.Status::Open, Line.Status, 'Open line stays open.');
    end;

    /// <summary>Verifies Scenario AC09 Approve NativeFailure RollsBackEarlierLine.</summary>
    [Test]
    procedure Scenario_AC09_Approve_NativeFailure_RollsBackEarlierLine()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        // Story #63, AC09 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        SheetNo := CreateSheet(CreateResource(true), WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        CreateLine(SheetNo, 20000, 'Submitted');
        Line.Get(SheetNo, 20000);
        Line."Approver ID" := 'XOTHER';
        Line.Modify(false);
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Assert.AreEqual('Error', ReadText(TempArgument.GetResponseJson(), 'status'), 'Native failure is returned as JSON.');
        Assert.AreEqual('BusinessCentralError', ReadText(TempArgument.GetResponseJson(), 'code'), 'Native failure is structured.');
        Line.Get(SheetNo, 10000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Earlier approval rolled back.');
        Line.Get(SheetNo, 20000);
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'Failing line stays submitted.');
    end;

    /// <summary>Verifies Scenario AC08 StatusField RestrictedButReadable.</summary>
    [Test]
    procedure Scenario_AC08_StatusField_RestrictedButReadable()
    var
        Line: Record "Time Sheet Line";
    begin
        // Story #63, AC08 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Assert.IsTrue(IsFieldRestricted(Line.FieldNo(Status), 'writeRestricted'), 'Generic status write must be blocked.');
        Assert.IsFalse(IsFieldRestricted(Line.FieldNo(Status), 'readRestricted'), 'Status reads must remain available.');
        Assert.IsFalse(IsFieldRestricted(Line.FieldNo(Description), 'writeRestricted'), 'Unrelated fields remain writable.');
    end;

    /// <summary>Native absence approval posts only its own employee absence and posting entry.</summary>
    [Test]
    procedure Scenario_AC09_ApproveAbsence_PostsNativeEntries()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Resource: Record Resource;
        Employee: Record Employee;
        Cause: Record "Cause of Absence";
        HumanUom: Record "Human Resource Unit of Measure";
        HrSetup: Record "Human Resources Setup";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Absence: Record "Employee Absence";
        Posting: Record "Time Sheet Posting Entry";
        SheetNo: Code[20];
        Request: JsonObject;
    begin
        // Story #63, AC09 | Time: WorkDate fixture; native approval date uses Today | Risk: None
        Resource.Get(CreateResource(true));
        if not HumanUom.Get(Resource."Base Unit of Measure") then begin
            HumanUom.Init();
            HumanUom.Code := Resource."Base Unit of Measure";
            HumanUom."Qty. per Unit of Measure" := 1;
            HumanUom.Insert(false);
        end;
        if not HrSetup.Get() then begin
            HrSetup.Init();
            HrSetup.Insert(false);
        end;
        if HrSetup."Base Unit of Measure" = '' then begin
            HrSetup."Base Unit of Measure" := HumanUom.Code;
            HrSetup.Modify(false);
        end;
        Employee.Init();
        Employee."No." := Resource."No.";
        Employee."Resource No." := Resource."No.";
        Employee.Insert(false);
        Cause.Init();
        Cause.Code := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Cause.Code));
        Cause."Unit of Measure Code" := Resource."Base Unit of Measure";
        Cause.Insert(false);
        SheetNo := CreateSheet(Resource."No.", WorkDate(), UserId());
        CreateLine(SheetNo, 10000, 'Submitted');
        Line.Get(SheetNo, 10000);
        Line.Type := Line.Type::Absence;
        Line."Cause of Absence Code" := Cause.Code;
        Line.Modify(false);
        Detail.Init();
        Detail."Time Sheet No." := SheetNo;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := WorkDate();
        Detail.Type := Detail.Type::Absence;
        Detail.Status := Detail.Status::Submitted;
        Detail."Cause of Absence Code" := Cause.Code;
        Detail.Quantity := 2;
        Detail.Insert(false);
        Request.Add('timeSheetNo', SheetNo);
        Execute(TempArgument, "Message Type ori"::"Projects.TimeSheet.Approve", Request);
        Assert.AreEqual('Success', ReadText(TempArgument.GetResponseJson(), 'status'), 'Native absence approval succeeds.');
        Line.Get(SheetNo, 10000);
        Assert.IsTrue(Line.Posted, 'Native approval marks absence posted.');
        Absence.SetRange("Employee No.", Employee."No.");
        Assert.AreEqual(1, Absence.Count(), 'Exactly one owned employee absence.');
        Absence.FindFirst();
        Assert.AreEqual(2, Absence.Quantity, 'Native absence quantity is preserved.');
        Posting.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(1, Posting.Count(), 'Native posting entry created.');
    end;

    local procedure AssertPublicDecisionContract(MessageType: Enum "Message Type ori"; LanguageId: Integer)
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
        Assert.IsTrue(HasContract, 'The decision type must have a public contract.');
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

    local procedure AssertMissingSheetCaption(var TempArgument: Record "Message Argument ori" temporary)
    var
        Header: Record "Time Sheet Header";
        ExpectedMsg: Label 'The identifier does not match a record in %1.', Locked = true, Comment = '%1 = table caption';
    begin
        Assert.AreEqual(StrSubstNo(ExpectedMsg, Header.TableCaption()),
            ReadText(TempArgument.GetResponseJson(), 'error'), 'Record refusal uses the native table caption.');
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
        Resource.Rename(CopyStr('X63' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Resource."No.")));
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
        // Native approval lets time-sheet administrators bypass the line approver check.
        // Establish the non-admin fixture on every test, including when the user already exists.
        if not UserSetup.Get(UserId()) then begin
            UserSetup.Init();
            UserSetup.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID")));
            UserSetup.Insert(true);
        end;
        UserSetup.Validate("Time Sheet Admin.", false);
        UserSetup.Modify(true);
    end;

    local procedure CreateSheet(ResourceNo: Code[20]; StartingDate: Date; Owner: Text): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := CopyStr('X63' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := StartingDate;
        Header."Ending Date" := StartingDate + 6;
        Header."Owner User ID" := CopyStr(Owner, 1, MaxStrLen(Header."Owner User ID"));
        Header."Approver User ID" := CopyStr(Owner, 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert(false);
        exit(Header."No.");
    end;

    local procedure SetApprover(SheetNo: Code[20]; Approver: Text)
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Get(SheetNo);
        Header."Approver User ID" := CopyStr(Approver, 1, MaxStrLen(Header."Approver User ID"));
        Header.Modify(false);
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
            'Rejected':
                Line.Status := Line.Status::Rejected;
            else
                Line.Status := Line.Status::Open;
        end;
        Line."Approver ID" := Header."Approver User ID";
        Line.Insert(false);
    end;

    local procedure IsFieldRestricted(FieldNumber: Integer; RestrictionName: Text): Boolean
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageImplementation: Interface "Msg Interface ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FieldJson: JsonObject;
        FieldNumbers: JsonArray;
        Fields: JsonArray;
        Token: JsonToken;
    begin
        // Help.Fields.Get uses the same field-access checks as Data.Records.Get/Set.
        // Invoke the public interface to exercise Foundation's private checks and our subscriber.
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Help.Fields.Get";
        TempArgument."Version" := TempArgument."Version"::"1.0";
        // Persist the temporary row so SetRequestJson/CalcFields retain the request BLOB.
        TempArgument.Insert();
        RequestJson.Add('tableId', Database::"Time Sheet Line");
        FieldNumbers.Add(FieldNumber);
        RequestJson.Add('fieldNumbers', FieldNumbers);
        TempArgument.SetRequestJson(RequestJson);
        RequestJson := TempArgument.GetRequestJson();
        Assert.IsTrue(RequestJson.Get('tableId', Token), 'Stored request must retain the table selector.');
        Assert.AreEqual(Database::"Time Sheet Line", Token.AsValue().AsInteger(), 'Stored request must target Clockify Setup.');
        Assert.IsTrue(RequestJson.Get('fieldNumbers', Token), 'Stored request must retain the field selector.');
        FieldNumbers := Token.AsArray();
        Assert.AreEqual(1, FieldNumbers.Count(), 'Stored request must select exactly one field.');
        FieldNumbers.Get(0, Token);
        Assert.AreEqual(FieldNumber, Token.AsValue().AsInteger(), 'Stored request must select the requested field.');
        MessageImplementation := TempArgument.GetMessageTypeInterface();
        MessageImplementation.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('status', Token), 'Field metadata response must include status.');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Field metadata request must succeed.');
        Assert.IsTrue(ResponseJson.Get('result', Token), 'Field metadata response must include result.');
        Fields := Token.AsArray();
        Assert.AreEqual(1, Fields.Count(), 'Exactly the requested field must be returned.');
        Fields.Get(0, Token);
        FieldJson := Token.AsObject();
        FieldJson.Get('id', Token);
        Assert.AreEqual(FieldNumber, Token.AsValue().AsInteger(), 'Metadata must identify the requested field.');
        Assert.IsTrue(FieldJson.Get(RestrictionName, Token), 'Field metadata must include ' + RestrictionName + '.');
        exit(Token.AsValue().AsBoolean());
    end;
    local procedure OneLine() LineNos: JsonArray
    begin
        LineNos.Add(10000);
    end;
}
