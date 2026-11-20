namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Time Sheet Date on project-invoiced sales lines (projects#71).</summary>
codeunit 97112 "Proj. TS Date Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryJob: Codeunit "Library - Job";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure CreateInvoice_SetsDocumentDate()
    var
        JobPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
    begin
        // [SCENARIO] AC1: an invoice line created from a planning line carries the planning line's Document Date.
        NewBillableLine(JobPlanningLine, 1, WorkDate() - 3, WorkDate() - 5);
        CreateDocument(JobPlanningLine, false, SalesLine);
        Assert.AreEqual(SalesLine."Document Type"::Invoice, SalesLine."Document Type", 'An invoice line is created.');
        Assert.AreEqual(WorkDate() - 3, SalesLine."Time Sheet Date ori", 'Time Sheet Date = planning line Document Date.');
    end;

    [Test]
    procedure CreateInvoice_BlankDocumentDate_UsesPlanningDate()
    var
        JobPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
    begin
        // [SCENARIO] AC1: a blank Document Date falls back to the Planning Date.
        NewBillableLine(JobPlanningLine, 1, 0D, WorkDate() - 7);
        CreateDocument(JobPlanningLine, false, SalesLine);
        Assert.AreEqual(WorkDate() - 7, SalesLine."Time Sheet Date ori", 'Time Sheet Date = planning line Planning Date.');
    end;

    [Test]
    procedure PostInvoice_CarriesDateToPostedLine()
    var
        JobPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        PostedNo: Code[20];
    begin
        // [SCENARIO] AC2: posting the invoice carries Time Sheet Date to the posted invoice line.
        NewBillableLine(JobPlanningLine, 1, WorkDate() - 2, WorkDate() - 4);
        CreateDocument(JobPlanningLine, false, SalesLine);
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        PostedNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesInvoiceLine.SetRange("Document No.", PostedNo);
        SalesInvoiceLine.SetRange("Job Contract Entry No.", JobPlanningLine."Job Contract Entry No.");
        SalesInvoiceLine.FindFirst();
        Assert.AreEqual(WorkDate() - 2, SalesInvoiceLine."Time Sheet Date ori", 'Posted invoice line keeps the Time Sheet Date.');
    end;

    [Test]
    procedure PostCreditMemo_CarriesDateToPostedLine()
    var
        JobPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        PostedNo: Code[20];
    begin
        // [SCENARIO] AC1/AC2: a credit memo from a negative planning line gets the date, and posting carries it.
        NewBillableLine(JobPlanningLine, -1, WorkDate() - 6, WorkDate() - 8);
        CreateDocument(JobPlanningLine, true, SalesLine);
        Assert.AreEqual(SalesLine."Document Type"::"Credit Memo", SalesLine."Document Type", 'A credit memo line is created.');
        Assert.AreEqual(WorkDate() - 6, SalesLine."Time Sheet Date ori", 'Credit memo line Time Sheet Date.');
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        PostedNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesCrMemoLine.SetRange("Document No.", PostedNo);
        SalesCrMemoLine.SetRange("Job Contract Entry No.", JobPlanningLine."Job Contract Entry No.");
        SalesCrMemoLine.FindFirst();
        Assert.AreEqual(WorkDate() - 6, SalesCrMemoLine."Time Sheet Date ori", 'Posted credit memo line keeps the Time Sheet Date.');
    end;

    [Test]
    procedure ManualSalesLine_StaysBlank()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        // [SCENARIO] AC3: a manual sales line without a Job Contract Entry No. has no Time Sheet Date.
        LibrarySales.CreateSalesInvoice(SalesHeader);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindFirst();
        Assert.AreEqual(0, SalesLine."Job Contract Entry No.", 'Manual line has no Job Contract Entry No.');
        Assert.AreEqual(0D, SalesLine."Time Sheet Date ori", 'Manual line has a blank Time Sheet Date.');
    end;

    [Test]
    procedure Lookup_NoJobContractEntry_IsBlank()
    var
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
    begin
        // [SCENARIO] AC3 edge: no Job Contract Entry No. (or an unknown one) gives a blank date.
        Assert.AreEqual(0D, TSDateMgt.GetTimeSheetDate(0), 'Entry 0 gives a blank date.');
        Assert.AreEqual(0D, TSDateMgt.GetTimeSheetDate(-1), 'Unknown entry gives a blank date.');
    end;

    [Test]
    procedure Backfill_FillsOpenAndPostedLines_SecondRunChangesNothing()
    var
        JobPlanningLine: Record "Job Planning Line";
        PostedPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
        PostedSourceLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
        PostedNo: Code[20];
    begin
        // [SCENARIO] AC5: the backfill fills blank dates on open and posted project lines and is idempotent.
        NewBillableLine(PostedPlanningLine, 1, WorkDate() - 9, WorkDate() - 10);
        CreateDocument(PostedPlanningLine, false, PostedSourceLine);
        SalesHeader.Get(PostedSourceLine."Document Type", PostedSourceLine."Document No.");
        PostedNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesInvoiceLine.SetRange("Document No.", PostedNo);
        SalesInvoiceLine.SetRange("Job Contract Entry No.", PostedPlanningLine."Job Contract Entry No.");
        SalesInvoiceLine.FindFirst();
        SalesInvoiceLine."Time Sheet Date ori" := 0D;
        SalesInvoiceLine.Modify(false);

        NewBillableLine(JobPlanningLine, 1, WorkDate() - 11, WorkDate() - 12);
        CreateDocument(JobPlanningLine, false, SalesLine);
        SalesLine."Time Sheet Date ori" := 0D;
        SalesLine.Modify(false);

        Assert.IsTrue(TSDateMgt.Backfill() >= 2, 'The first run fills at least the two blanked lines.');
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        SalesInvoiceLine.Get(SalesInvoiceLine."Document No.", SalesInvoiceLine."Line No.");
        Assert.AreEqual(WorkDate() - 11, SalesLine."Time Sheet Date ori", 'Open line backfilled.');
        Assert.AreEqual(WorkDate() - 9, SalesInvoiceLine."Time Sheet Date ori", 'Posted line backfilled.');

        Assert.AreEqual(0, TSDateMgt.Backfill(), 'A second run changes nothing.');
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Assert.AreEqual(WorkDate() - 11, SalesLine."Time Sheet Date ori", 'Open line unchanged by the second run.');
    end;

    [Test]
    procedure ColumnVisibility_FollowsSubPageLinkDocument()
    var
        JobPlanningLine: Record "Job Planning Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        LinkedLine: Record "Sales Line";
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
    begin
        // [SCENARIO] AC4: the column is shown for a project document (SubPageLink filter in group 4) and hidden for a manual one.
        NewBillableLine(JobPlanningLine, 1, WorkDate() - 1, WorkDate() - 1);
        CreateDocument(JobPlanningLine, false, SalesLine);
        LinkedLine.FilterGroup(4);
        LinkedLine.SetRange("Document Type", SalesLine."Document Type");
        LinkedLine.SetRange("Document No.", SalesLine."Document No.");
        LinkedLine.FilterGroup(0);
        Assert.IsTrue(TSDateMgt.HasProjectLines(LinkedLine), 'Project invoice shows the column.');

        LibrarySales.CreateSalesInvoice(SalesHeader);
        Clear(LinkedLine);
        LinkedLine.FilterGroup(4);
        LinkedLine.SetRange("Document Type", SalesHeader."Document Type");
        LinkedLine.SetRange("Document No.", SalesHeader."No.");
        LinkedLine.FilterGroup(0);
        Assert.IsFalse(TSDateMgt.HasProjectLines(LinkedLine), 'Manual invoice hides the column.');
    end;

    local procedure NewBillableLine(var JobPlanningLine: Record "Job Planning Line"; Quantity: Decimal; DocumentDate: Date; PlanningDate: Date)
    var
        Job: Record Job;
        JobTask: Record "Job Task";
        SourceLine: Record "Job Planning Line";
    begin
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryJob.CreateJobPlanningLine(LibraryJob.PlanningLineTypeContract(), LibraryJob.ResourceType(), JobTask, SourceLine);
        if Quantity > 0 then
            JobPlanningLine := SourceLine
        else begin
            SourceLine.Delete(true);
            LibraryJob.CreateJobPlanningLine(JobTask, LibraryJob.PlanningLineTypeContract(), LibraryJob.ResourceType(), SourceLine."No.", Quantity, JobPlanningLine);
        end;
        JobPlanningLine.Validate("Planning Date", PlanningDate);
        JobPlanningLine."Document Date" := DocumentDate;
        JobPlanningLine.Modify(true);
    end;

    local procedure CreateDocument(var JobPlanningLine: Record "Job Planning Line"; CreditMemo: Boolean; var SalesLine: Record "Sales Line")
    var
        JobCreateInvoice: Codeunit "Job Create-Invoice";
    begin
        JobPlanningLine.SetRecFilter();
        JobCreateInvoice.CreateSalesInvoiceLines(JobPlanningLine."Job No.", JobPlanningLine, '', true, WorkDate(), WorkDate(), CreditMemo);
        SalesLine.SetRange("Job Contract Entry No.", JobPlanningLine."Job Contract Entry No.");
        SalesLine.FindFirst();
    end;
}
