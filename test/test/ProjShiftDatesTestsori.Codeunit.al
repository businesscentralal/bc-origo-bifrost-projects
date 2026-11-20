namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue #76: date shifts, native filters, atomic refusals and English help.</summary>
codeunit 97114 "Proj. Shift Dates Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";
        ProjectNo: Code[20];

    /// <summary>AC01 TaskRange ShiftsThreeOfSix.</summary>
    [Test]
    procedure Scenario_AC01_TaskRange_ShiftsThreeOfSix()
    var
        Request: JsonObject;
        Response: JsonObject;
        Changes: JsonArray;
        Change: JsonToken;
    begin
        // Story #76 AC01 | Fixed dates | API-only operation: native adapter is tested directly.
        Seed();
        Request := BaseRequest();
        Request.Add('fromTaskNo', '1000');
        Request.Add('toTaskNo', '1000');
        Response := Send(Request);
        AssertSuccess(Response, 3, 3);
        Changes := Response.GetArray('changedLines');
        foreach Change in Changes do begin
            Assert.AreEqual('1000', Change.AsObject().GetText('taskNo'), 'Only the selected task');
            Assert.AreEqual('2026-01-10', Change.AsObject().GetText('oldDate'), 'Old date retained');
            Assert.AreEqual('2026-01-17', Change.AsObject().GetText('newDate'), 'One week');
        end;
        AssertDate('1000', 10000, 20260117D, 20260110D);
        AssertDate('2000', 10000, 20260110D, 20260110D);
    end;

    /// <summary>AC02 BillableFixedCurrency UsesNativeWindow.</summary>
    [Test]
    procedure Scenario_AC02_BillableFixedCurrency_UsesNativeWindow()
    var
        Line: Record "Job Planning Line";
        Request: JsonObject;
    begin
        Seed();
        Line.Get(ProjectNo, '1000', 30000);
        Line."Currency Date" := 20260111D;
        Line.Modify();
        Request.Add('projectNo', ProjectNo);
        Request.Add('lineType', 'Billable');
        Request.Add('fixedDate', '2026-02-20');
        Request.Add('dateField', 'currencyDate');
        Request.Add('includeFrom', '2026-01-10');
        Request.Add('includeTo', '2026-01-10');
        AssertSuccess(Send(Request), 3, 6);
        AssertDate('1000', 10000, 20260110D, 20260110D);
        AssertDate('1000', 20000, 20260110D, 20260220D);
        AssertDate('1000', 30000, 20260110D, 20260111D);
        Line.Get(ProjectNo, '1000', 20000);
        Assert.AreEqual(20260220D, Line."Document Date", 'Native currency batch also changes document date');
    end;

    /// <summary>AC02 BudgetBoth ChangesThreeDateFields.</summary>
    [Test]
    procedure Scenario_AC02_BudgetBoth_ChangesThreeDateFields()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Replace('lineType', 'Budget');
        Request.Add('dateField', 'both');
        AssertSuccess(Send(Request), 4, 12);
        AssertDate('1000', 20000, 20260110D, 20260110D);
        AssertDate('2000', 30000, 20260117D, 20260117D);
    end;

    /// <summary>AC03 TransferredLine RefusesEntireBatch.</summary>
    [Test]
    procedure Scenario_AC03_TransferredLine_RefusesEntireBatch()
    begin
        Seed();
        AddInvoice(false);
        AssertRefusal(BaseRequest(), 'PreconditionFailed');
    end;

    /// <summary>AC03 InvoicedLine RefusesEntireBatch.</summary>
    [Test]
    procedure Scenario_AC03_InvoicedLine_RefusesEntireBatch()
    begin
        Seed();
        AddInvoice(true);
        AssertRefusal(BaseRequest(), 'PreconditionFailed');
    end;

    /// <summary>AC03 InvoiceOutsideScope DoesNotRefuse.</summary>
    [Test]
    procedure Scenario_AC03_InvoiceOutsideScope_DoesNotRefuse()
    var
        Request: JsonObject;
    begin
        Seed();
        AddInvoice(false);
        Request := BaseRequest();
        Request.Add('toTaskNo', '1000');
        AssertSuccess(Send(Request), 3, 3);
    end;

    /// <summary>AC04 ConflictingDateOptions Refused.</summary>
    [Test]
    procedure Scenario_AC04_ConflictingDateOptions_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Add('fixedDate', '2026-02-01');
        AssertRefusal(Request, 'ConflictingIdentifiers');
    end;

    /// <summary>AC04 MissingDateOption Refused.</summary>
    [Test]
    procedure Scenario_AC04_MissingDateOption_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Remove('dateFormula');
        AssertRefusal(Request, 'MissingParameter');
    end;

    /// <summary>AC04 BadFormulaAndDates Refused.</summary>
    [Test]
    procedure Scenario_AC04_BadFormulaAndDates_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Replace('dateFormula', 'not-a-formula');
        AssertRefusal(Request, 'InvalidParameterFormat');
        Request.Remove('dateFormula');
        Request.Add('fixedDate', '2026-02-30');
        AssertRefusal(Request, 'InvalidParameterFormat');
        Request.Replace('fixedDate', '2026-02-28');
        Request.Add('includeFrom', 'wrong');
        AssertRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>AC04 UnknownKeyAndExpectedCount Refused.</summary>
    [Test]
    procedure Scenario_AC04_UnknownKeyAndExpectedCount_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Add('surprise', true);
        AssertRefusal(Request, 'UnknownParameter');
        Request.Remove('surprise');
        Request.Add('expectedCount', 6);
        AssertRefusal(Request, 'UnknownParameter');
    end;

    /// <summary>AC04 UnknownProjectAndTask Refused.</summary>
    [Test]
    procedure Scenario_AC04_UnknownProjectAndTask_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Replace('projectNo', 'X-NOT-FOUND-76');
        AssertRefusal(Request, 'RecordNotFound');
        Request.Replace('projectNo', ProjectNo);
        Request.Add('fromTaskNo', '9999');
        AssertRefusal(Request, 'RecordNotFound');
        Request.Remove('fromTaskNo');
        Request.Add('toTaskNo', '9999');
        AssertRefusal(Request, 'RecordNotFound');
    end;

    /// <summary>AC04 BlockedProject Refused.</summary>
    [Test]
    procedure Scenario_AC04_BlockedProject_Refused()
    var
        Project: Record Job;
    begin
        Seed();
        Project.Get(ProjectNo);
        Project.Blocked := Project.Blocked::All;
        Project.Modify();
        AssertRefusal(BaseRequest(), 'PreconditionFailed');
    end;

    /// <summary>AC04 InvalidOptionsAndRanges Refused.</summary>
    [Test]
    procedure Scenario_AC04_InvalidOptionsAndRanges_Refused()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := BaseRequest();
        Request.Replace('lineType', 'Invalid');
        AssertRefusal(Request, 'InvalidParameterFormat');
        Request.Replace('lineType', 'Both');
        Request.Add('dateField', 'invalid');
        AssertRefusal(Request, 'InvalidParameterFormat');
        Request.Remove('dateField');
        Request.Add('includeFrom', '2026-02-01');
        Request.Add('includeTo', '2026-01-01');
        AssertRefusal(Request, 'InvalidParameterFormat');
        Request.Remove('includeFrom');
        Request.Remove('includeTo');
        Request.Add('fromTaskNo', '2000');
        Request.Add('toTaskNo', '1000');
        AssertRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>AC04 NativeFailure RollsBackEarlierTask.</summary>
    [Test]
    procedure Scenario_AC04_NativeFailure_RollsBackEarlierTask()
    var
        Line: Record "Job Planning Line";
    begin
        Seed();
        Line.Get(ProjectNo, '2000', 30000);
        Line."Planning Date" := 0D;
        Line.Modify();
        AssertRefusal(BaseRequest(), 'BusinessCentralError');
    end;

    /// <summary>AC05 NoCount PlainWriteAndEmptyWindow.</summary>
    [Test]
    procedure Scenario_AC05_NoCount_PlainWriteAndEmptyWindow()
    var
        Request: JsonObject;
    begin
        // AC05 superseded by the 20 November ruling: no confirmation count.
        Seed();
        Request := BaseRequest();
        AssertSuccess(Send(Request), 6, 6);
        Request.Add('includeFrom', '2027-01-01');
        AssertSuccess(Send(Request), 0, 0);
    end;

    /// <summary>AC07 InvariantFormulaAndEnglishHelp BothLanguages.</summary>
    [Test]
    procedure Scenario_AC07_InvariantFormulaAndEnglishHelp_BothLanguages()
    var
        Impl: Codeunit "Proj. Shift Dates Impl ori";
        Request: JsonObject;
        HelpEn: Text;
        HelpIs: Text;
        DescriptionEn: Text;
        Effect: JsonObject;
        Parameters: JsonArray;
        OldLanguage: Integer;
    begin
        Seed();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Impl.GetOverview(HelpEn);
        DescriptionEn := Impl.GetDescription();
        GlobalLanguage(1039);
        Impl.GetOverview(HelpIs);
        Assert.AreEqual(HelpEn, HelpIs, 'Help remains English');
        Assert.AreNotEqual(DescriptionEn, Impl.GetDescription(), 'Discovery is localized');
        Request := BaseRequest();
        AssertSuccess(Send(Request), 6, 6);
        Request.Replace('dateFormula', '-1W');
        AssertSuccess(Send(Request), 6, 6);
        AssertDate('1000', 10000, 20260110D, 20260110D);
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', Effect.GetText('effect'), 'Approved plain write');
        Impl.GetParameters(Parameters);
        Assert.AreEqual(9, Parameters.Count(), 'No expectedCount parameter');
        GlobalLanguage(OldLanguage);
    end;

    /// <summary>AC02 MonthEndAndNoOp ReportActualChanges.</summary>
    [Test]
    procedure Scenario_AC02_MonthEndAndNoOp_ReportActualChanges()
    var
        Line: Record "Job Planning Line";
        Request: JsonObject;
    begin
        Seed();
        Line.SetRange("Job No.", ProjectNo);
        Line.ModifyAll("Planning Date", 20260131D);
        Request := BaseRequest();
        Request.Replace('dateFormula', '+1M');
        AssertSuccess(Send(Request), 6, 6);
        AssertDate('1000', 10000, 20260228D, 20260110D);
        Request.Remove('dateFormula');
        Request.Add('fixedDate', '2026-02-28');
        AssertSuccess(Send(Request), 0, 0);
    end;

    local procedure Seed()
    var
        Project: Record Job;
        Task: Record "Job Task";
        Line: Record "Job Planning Line";
        Request: JsonObject;
        TaskIndex: Integer;
        LineIndex: Integer;
    begin
        // Self-created customer, project and Text planning lines; no demo data or credentials.
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        Project.Get(ProjectNo);
        for TaskIndex := 1 to 2 do begin
            Task.Init();
            Task."Job No." := ProjectNo;
            Task."Job Task No." := Format(TaskIndex * 1000, 0, 9);
            Task."Job Task Type" := Task."Job Task Type"::Posting;
            Task.Insert(true);
            for LineIndex := 1 to 3 do begin
                Line.Init();
                Line."Job No." := ProjectNo;
                Line."Job Task No." := Task."Job Task No.";
                Line."Line No." := LineIndex * 10000;
                Line.Type := Line.Type::Text;
                Line.Validate("Line Type", Enum::"Job Planning Line Line Type".FromInteger(LineIndex - 1));
                Line."Planning Date" := 20260110D;
                Line."Currency Date" := 20260110D;
                Line."Document Date" := 20260110D;
                Line.Insert(true);
            end;
        end;
    end;

    local procedure BaseRequest() Request: JsonObject
    begin
        Request.Add('projectNo', ProjectNo);
        Request.Add('lineType', 'Both');
        Request.Add('dateFormula', '+1W');
    end;

    local procedure Send(Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Shift Dates Impl ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.PlanningLine.ShiftDates";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Impl.ShiftDates(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure AssertSuccess(Response: JsonObject; Lines: Integer; Fields: Integer)
    begin
        Assert.AreEqual('Success', Response.GetText('status'), Format(Response));
        Assert.AreEqual(Lines, Response.GetObject('summary').GetInteger('changedLineCount'), 'Distinct changed lines');
        Assert.AreEqual(Fields, Response.GetArray('changedLines').Count(), 'Changed fields');
    end;

    local procedure AssertRefusal(Request: JsonObject; ExpectedCode: Text)
    var
        Response: JsonObject;
    begin
        Response := Send(Request);
        Assert.AreEqual('Error', Response.GetText('status'), 'Error status');
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), Format(Response));
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
        AssertDate('1000', 10000, 20260110D, 20260110D);
        AssertDate('2000', 10000, 20260110D, 20260110D);
    end;

    local procedure AssertDate(TaskNo: Code[20]; LineNo: Integer; PlanningDate: Date; CurrencyDate: Date)
    var
        Line: Record "Job Planning Line";
    begin
        Line.Get(ProjectNo, TaskNo, LineNo);
        Assert.AreEqual(PlanningDate, Line."Planning Date", 'Stored planning date');
        Assert.AreEqual(CurrencyDate, Line."Currency Date", 'Stored currency date');
    end;

    local procedure AddInvoice(Posted: Boolean)
    var
        Invoice: Record "Job Planning Line Invoice";
    begin
        Invoice."Job No." := ProjectNo;
        Invoice."Job Task No." := '2000';
        Invoice."Job Planning Line No." := 30000;
        Invoice."Document No." := ProjectNo;
        if Posted then
            Invoice."Document Type" := Invoice."Document Type"::"Posted Invoice"
        else
            Invoice."Document Type" := Invoice."Document Type"::Invoice;
        Invoice."Quantity Transferred" := 1;
        Invoice.Insert();
    end;
}
