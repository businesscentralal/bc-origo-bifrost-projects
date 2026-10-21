namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Verifies exact standard-report selection, required filters and safe native XML view serialization.</summary>
codeunit 97126 "Projects Report Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>Unknown Report: Has Actionable Refusal.</summary>
    [Test]
    procedure UnknownReport_HasActionableRefusal()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('report', 'not-a-report');
        Request.Add('format', 'json');
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Unknown report');
        Assert.AreEqual('Use one of the values listed in the help.', Response.GetText('nextStep'), 'Exact next step');
    end;

    /// <summary>Missing Required Filter: Refuses Before Report Run.</summary>
    [Test]
    procedure MissingRequiredFilter_RefusesBeforeReportRun()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('report', 'actualToBudget');
        Request.Add('format', 'pdf');
        Response := ValidateRequest(Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Project required');
        Assert.AreEqual('projectNo', Response.GetText('parameter'), 'Named missing project filter');
        Assert.AreEqual('Pass the filter named in the refusal.', Response.GetText('nextStep'), 'Exact next step');
        Request.Replace('report', 'register');
        Response := ValidateRequest(Request);
        Assert.AreEqual('registerNo', Response.GetText('parameter'), 'Register needs explicit register number');
    end;

    /// <summary>Wrong Type And Unknown Key: Are Not Silently Ignored.</summary>
    [Test]
    procedure WrongTypeAndUnknownKey_AreNotSilentlyIgnored()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('report', 1009);
        Request.Add('format', 'json');
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Report selector must be a string');
        Request.Replace('report', 'analysis');
        Request.Add('arbitraryReportId', 1009);
        Response := ValidateRequest(Request);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'No arbitrary report execution');
    end;

    /// <summary>Native Request: Uses Exact Filters And Deterministic Analysis Columns.</summary>
    [Test]
    procedure NativeRequest_UsesExactFiltersAndDeterministicAnalysisColumns()
    var
        Project: Record Job;
        ReportAdapter: Codeunit "Projects Report ori";
        Request: JsonObject;
        Document: XmlDocument;
        Nodes: XmlNodeList;
        Xml: Text;
    begin
        Library.Initialize();
        Project."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Project.Insert(true);
        Request.Add('report', 'analysis');
        Request.Add('format', 'json');
        Request.Add('projectNo', Project."No.");
        Request.Add('fromDate', '2026-01-01');
        Request.Add('toDate', '2026-01-31');
        Assert.IsFalse(ValidateRequest(Request).Contains('code'), 'Valid filters accepted');
        Xml := ReportAdapter.RequestXml(Request);
        XmlDocument.ReadFrom(Xml, Document);
        Document.SelectNodes('ReportParameters/DataItems/DataItem', Nodes);
        Assert.AreEqual(2, Nodes.Count(), 'Project and task views are serialized');
        Document.SelectNodes('ReportParameters/Options/Field', Nodes);
        Assert.AreEqual(16, Nodes.Count(), 'All eight amount/currency selections fixed; no saved user options');
        Assert.IsTrue(Xml.Contains(Project."No."), 'Exact project view retained');
    end;

    /// <summary>Edge: Xml Filter Cannot Inject Another Data Item.</summary>
    [Test]
    procedure Edge_XmlFilterCannotInjectAnotherDataItem()
    var
        ReportAdapter: Codeunit "Projects Report ori";
        Request: JsonObject;
        Document: XmlDocument;
        Nodes: XmlNodeList;
    begin
        Request.Add('report', 'actualToBudget');
        Request.Add('format', 'json');
        Request.Add('projectNo', 'X&<test>');
        XmlDocument.ReadFrom(ReportAdapter.RequestXml(Request), Document);
        Document.SelectNodes('ReportParameters/DataItems/DataItem', Nodes);
        Assert.AreEqual(2, Nodes.Count(), 'Filter XML is text, never injected markup');
    end;

    /// <summary>Native dataset decimals become JSON numbers and caption/total rows are excluded.</summary>
    [Test]
    procedure AnalysisDataset_ProducesTypedAmounts()
    var
        Adapter: Codeunit "Projects Report ori";
        Document: XmlDocument;
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Document := Dataset('<Column name="No_Job">OWN-PROJECT</Column><Column name="JobTaskNo_JobTask">OWN-TASK</Column><Column name="Amt1">1234.56</Column><Column name="Amt6">-9.5</Column>');
        Rows := Adapter.ShapeDataset('analysis', Document);
        Assert.AreEqual(1, Rows.Count(), 'One native task row');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual('OWN-PROJECT', Row.GetText('projectNo'), 'Exact project');
        Assert.AreEqual('OWN-TASK', Row.GetText('taskNo'), 'Exact task');
        Assert.AreEqual(1234.56, Row.GetDecimal('budgetPriceLCY'), 'Budget price numeric');
        Assert.AreEqual(-9.5, Row.GetDecimal('actualCostLCY'), 'Negative actual cost retained');
        Assert.AreEqual(0, Row.GetDecimal('invoicedCostLCY'), 'Missing native amount is numeric zero');
    end;

    /// <summary>Native actual-to-budget buffer amounts retain their own budget, usage and difference meaning.</summary>
    [Test]
    procedure ActualToBudgetDataset_PreservesDifferenceAndIdentifiers()
    var
        Adapter: Codeunit "Projects Report ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Rows := Adapter.ShapeDataset('actualToBudget', Dataset('<Column name="JobDiffBufferNo">OWN-ITEM</Column><Column name="JobDiffBufferUOMcode">PCS</Column><Column name="Amt1">8</Column><Column name="Amt2">3</Column><Column name="Amt3">5</Column><Column name="Amt4">24</Column><Column name="Amt5">9</Column><Column name="Amt6">15</Column>'));
        Assert.AreEqual(1, Rows.Count(), 'One native buffer row');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual('OWN-ITEM', Row.GetText('no'), 'Native item identity');
        Assert.AreEqual('PCS', Row.GetText('unitOfMeasureCode'), 'Native UOM');
        Assert.AreEqual(8, Row.GetDecimal('budgetQuantity'), 'Native budget quantity');
        Assert.AreEqual(3, Row.GetDecimal('actualQuantity'), 'Native usage quantity');
        Assert.AreEqual(5, Row.GetDecimal('quantityDifference'), 'Native difference');
        Assert.AreEqual(15, Row.GetDecimal('costDifferenceLCY'), 'Native cost difference');
    end;

    /// <summary>The usage-only second buffer has different native column names and must not disappear.</summary>
    [Test]
    procedure UsageOnlyDataset_UsesSecondNativeBuffer()
    var
        Adapter: Codeunit "Projects Report ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Rows := Adapter.ShapeDataset('actualToBudget', Dataset('<Column name="JobDiffBuffer2No">OWN-UNBUDGETED</Column><Column name="Amt21">2</Column><Column name="Amt39">-2</Column><Column name="Amt55">10</Column><Column name="Amt66">-10</Column>'));
        Assert.AreEqual(1, Rows.Count(), 'Usage-only native buffer retained');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual(0, Row.GetDecimal('budgetQuantity'), 'No budget');
        Assert.AreEqual(2, Row.GetDecimal('actualQuantity'), 'Usage quantity');
        Assert.AreEqual(-10, Row.GetDecimal('costDifferenceLCY'), 'Unbudgeted cost difference');
    end;

    /// <summary>Register details use native ledger entry identifiers and numeric amounts.</summary>
    [Test]
    procedure RegisterDataset_ProducesLedgerRows()
    var
        Adapter: Codeunit "Projects Report ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Rows := Adapter.ShapeDataset('register', Dataset('<Column name="Job_Ledger_Entry__Entry_No__">42</Column><Column name="Job_Register__No__">7</Column><Column name="Job_Ledger_Entry__Job_No__">OWN-PROJECT</Column><Column name="Job_Ledger_Entry_Quantity">-2.5</Column><Column name="Job_Ledger_Entry__Total_Cost__LCY__">-15.25</Column>'));
        Assert.AreEqual(1, Rows.Count(), 'One native ledger row');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual(42, Row.GetInteger('entryNo'), 'Native ledger identifier');
        Assert.AreEqual(7, Row.GetInteger('registerNo'), 'Native register identifier');
        Assert.AreEqual(-2.5, Row.GetDecimal('quantity'), 'Native signed quantity');
        Assert.AreEqual(-15.25, Row.GetDecimal('totalCostLCY'), 'Native signed cost');
    end;

    /// <summary>Empty datasets and header/totals-only datasets answer an empty shaped list.</summary>
    [Test]
    procedure EmptyAndCaptionDatasets_ReturnEmptyList()
    var
        Adapter: Codeunit "Projects Report ori";
        Rows: JsonArray;
        Name: Text;
        Names: List of [Text];
    begin
        Names.Add('actualToBudget');
        Names.Add('analysis');
        Names.Add('wipToGL');
        Names.Add('register');
        foreach Name in Names do begin
            Rows := Adapter.ShapeDataset(Name, Dataset(''));
            Assert.AreEqual(0, Rows.Count(), 'No rows for ' + Name);
            Rows := Adapter.ShapeDataset(Name, Dataset('<Column name="CompanyName">Owned company</Column><Column name="JobTotalAmt4">10</Column>'));
            Assert.AreEqual(0, Rows.Count(), 'Captions/totals excluded for ' + Name);
        end;
    end;

    /// <summary>Executes the real native report for an isolated empty project without creating ledger entries.</summary>
    [Test]
    procedure NativeEmptyActualToBudget_ReturnsEmptyList()
    var
        Project: Record Job;
        Adapter: Codeunit "Projects Report ori";
        Request: JsonObject;
        Rows: JsonArray;
    begin
        Library.Initialize();
        Project."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Project."No."));
        Project.Insert(true);
        Request.Add('report', 'actualToBudget');
        Request.Add('format', 'json');
        Request.Add('projectNo', Project."No.");
        Rows := Adapter.RenderJson(Request);
        Assert.AreEqual(0, Rows.Count(), 'No task or planning rows is a successful empty report');
    end;

    /// <summary>WIP continuation rows retain their account identity and the native balance/difference meanings.</summary>
    [Test]
    procedure WipDataset_RetainsContinuationPostingGroups()
    var
        Adapter: Codeunit "Projects Report ori";
        Document: XmlDocument;
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        XmlDocument.ReadFrom('<ReportDataSet><DataItems><DataItem><Column name="GLAcc__No__">OWN-ACCOUNT</Column><Column name="GLAcc_Name">Owned account</Column><Column name="JobBuffer__Account_No__2_">GROUP-A</Column><Column name="JobBuffer__Amount_3_">90</Column><Column name="GLAccJobTotal">100</Column><Column name="GLAccJobTotal___JobBuffer__Amount_3_">10</Column></DataItem><DataItem><Column name="JobBuffer__Account_No__2_">GROUP-B</Column><Column name="GLAccJobTotal">120</Column><Column name="GLAccJobTotal___JobBuffer__Amount_3_">120</Column></DataItem></DataItems></ReportDataSet>', Document);
        Rows := Adapter.ShapeDataset('wipToGL', Document);
        Assert.AreEqual(2, Rows.Count(), 'Both native posting group rows retained');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual(90, Row.GetDecimal('glBalanceLCY'), 'Amount3 is native G/L balance');
        Assert.AreEqual(100, Row.GetDecimal('wipAmountLCY'), 'Native WIP running total');
        Assert.AreEqual(10, Row.GetDecimal('differenceLCY'), 'Native difference retained');
        Rows.Get(1, Token);
        Row := Token.AsObject();
        Assert.AreEqual('OWN-ACCOUNT', Row.GetText('accountNo'), 'Native continuation carries same account');
        Assert.AreEqual('GROUP-B', Row.GetText('postingGroup'), 'Continuation posting group retained');
    end;

    /// <summary>Only the four verified BC 28 standard reports can be selected.</summary>
    [Test]
    procedure Selectors_MapOnlyToVerifiedNativeReportIds()
    var
        Adapter: Codeunit "Projects Report ori";
    begin
        Assert.AreEqual(1009, Adapter.ReportId('actualToBudget'), 'Native Actual to Budget');
        Assert.AreEqual(1008, Adapter.ReportId('analysis'), 'Native Analysis');
        Assert.AreEqual(1010, Adapter.ReportId('wipToGL'), 'Native WIP to G/L');
        Assert.AreEqual(1015, Adapter.ReportId('register'), 'Native Register');
        Assert.AreEqual(0, Adapter.ReportId('1009'), 'Arbitrary numeric selectors excluded');
    end;

    /// <summary>Native analysis calculation and XML shaping agree on fresh nonzero budget amounts.</summary>
    [Test]
    procedure NativeAnalysis_ProducesOwnedNonzeroBudget()
    var
        Adapter: Codeunit "Projects Report ori";
        Planning: JsonObject;
        Request: JsonObject;
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Planning := Library.NewPlanningRequest('Item');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Planning), 'Success');
        Request.Add('report', 'analysis');
        Request.Add('format', 'json');
        Request.Add('projectNo', Planning.GetText('projectNo'));
        Request.Add('taskNo', Planning.GetText('taskNo'));
        Request.Add('fromDate', '2026-10-01');
        Request.Add('toDate', '2026-10-31');
        Rows := Adapter.RenderJson(Request);
        Assert.AreEqual(1, Rows.Count(), 'One native task row for owned task');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual(Planning.GetText('projectNo'), Row.GetText('projectNo'), 'Native exact project filter');
        Assert.AreEqual(33, Row.GetDecimal('budgetPriceLCY'), 'Native three units at price11');
        Assert.AreEqual(21, Row.GetDecimal('budgetCostLCY'), 'Native three units at cost7');
        Assert.AreEqual(0, Row.GetDecimal('actualCostLCY'), 'No posted actual usage');
        Request.Replace('fromDate', '2026-11-01');
        Request.Replace('toDate', '2026-11-30');
        Rows := Adapter.RenderJson(Request);
        Assert.AreEqual(0, Rows.Count(), 'Out-of-range planning quantities do not appear');
    end;

    /// <summary>Native actual-to-budget uses the same confirmed project/task filters and buffer quantities.</summary>
    [Test]
    procedure NativeActualToBudget_ProducesOwnedPlanningQuantity()
    var
        Adapter: Codeunit "Projects Report ori";
        Planning: JsonObject;
        Request: JsonObject;
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        Planning := Library.NewPlanningRequest('Item');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Planning), 'Success');
        Request.Add('report', 'actualToBudget');
        Request.Add('format', 'json');
        Request.Add('projectNo', Planning.GetText('projectNo'));
        Request.Add('taskNo', Planning.GetText('taskNo'));
        Rows := Adapter.RenderJson(Request);
        Assert.AreEqual(1, Rows.Count(), 'One native item budget detail');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Assert.AreEqual(Planning.GetText('no'), Row.GetText('no'), 'Native item identifier');
        Assert.AreEqual(3, Row.GetDecimal('budgetQuantity'), 'Native planned quantity');
        Assert.AreEqual(0, Row.GetDecimal('actualQuantity'), 'No actual usage');
        Assert.AreEqual(21, Row.GetDecimal('budgetCostLCY'), 'Native planned cost');
    end;

    local procedure Dataset(Columns: Text) Document: XmlDocument
    begin
        XmlDocument.ReadFrom('<ReportDataSet><DataItems><DataItem>' + Columns + '</DataItem></DataItems></ReportDataSet>', Document);
    end;

    local procedure ValidateRequest(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        ReportAdapter: Codeunit "Projects Report ori";
        Response: JsonObject;
    begin
        Library.Initialize();
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        if ReportAdapter.Validate(TempArgument, Request) then
            Response.Add('status', 'Success')
        else
            Response := TempArgument.GetResponseJson();
        exit(Response);
    end;
}
