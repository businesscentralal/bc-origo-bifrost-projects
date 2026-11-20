namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;

/// <summary>Time Sheet Date lookup, page visibility and backfill for project-invoiced sales lines (#71).</summary>
codeunit 70013581 "Proj. TS Date Mgt ori"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;
    Permissions =
        tabledata "Job Planning Line" = r,
        tabledata "Sales Line" = rm,
        tabledata "Sales Invoice Line" = rm,
        tabledata "Sales Cr.Memo Line" = rm;

    /// <summary>The planning line's Document Date, or its Planning Date when Document Date is blank.</summary>
    procedure GetTimeSheetDate(JobPlanningLine: Record "Job Planning Line"): Date
    begin
        if JobPlanningLine."Document Date" <> 0D then
            exit(JobPlanningLine."Document Date");
        exit(JobPlanningLine."Planning Date");
    end;

    /// <summary>Looks up the planning line by Job Contract Entry No., as the original Clockify app did; 0D when none.</summary>
    procedure GetTimeSheetDate(JobContractEntryNo: Integer): Date
    var
        JobPlanningLine: Record "Job Planning Line";
    begin
        if JobContractEntryNo = 0 then
            exit(0D);
        JobPlanningLine.SetLoadFields("Job Contract Entry No.", "Document Date", "Planning Date");
        JobPlanningLine.SetCurrentKey("Job Contract Entry No.");
        JobPlanningLine.SetRange("Job Contract Entry No.", JobContractEntryNo);
        if not JobPlanningLine.FindFirst() then
            exit(0D);
        exit(GetTimeSheetDate(JobPlanningLine));
    end;

    procedure HasProjectLines(SalesLine: Record "Sales Line"): Boolean
    var
        DocSalesLine: Record "Sales Line";
    begin
        if SalesLine."Document No." <> '' then begin
            DocSalesLine.SetRange("Document Type", SalesLine."Document Type");
            DocSalesLine.SetRange("Document No.", SalesLine."Document No.");
        end else begin
            DocSalesLine.CopyFilters(SalesLine);
            if DocSalesLine.GetFilter("Document No.") = '' then
                exit(false);
        end;
        DocSalesLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocSalesLine.IsEmpty());
    end;

    procedure HasProjectLines(SalesInvoiceLine: Record "Sales Invoice Line"): Boolean
    var
        DocLine: Record "Sales Invoice Line";
    begin
        if SalesInvoiceLine."Document No." <> '' then
            DocLine.SetRange("Document No.", SalesInvoiceLine."Document No.")
        else begin
            DocLine.CopyFilters(SalesInvoiceLine);
            if DocLine.GetFilter("Document No.") = '' then
                exit(false);
        end;
        DocLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocLine.IsEmpty());
    end;

    procedure HasProjectLines(SalesCrMemoLine: Record "Sales Cr.Memo Line"): Boolean
    var
        DocLine: Record "Sales Cr.Memo Line";
    begin
        if SalesCrMemoLine."Document No." <> '' then
            DocLine.SetRange("Document No.", SalesCrMemoLine."Document No.")
        else begin
            DocLine.CopyFilters(SalesCrMemoLine);
            if DocLine.GetFilter("Document No.") = '' then
                exit(false);
        end;
        DocLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocLine.IsEmpty());
    end;

    /// <summary>Fills a blank Time Sheet Date on open and posted project lines; lines that already have a date are not touched, so a re-run changes nothing. Returns the number of lines changed.</summary>
    procedure Backfill(): Integer
    begin
        exit(BackfillSalesLines() + BackfillSalesInvoiceLines() + BackfillSalesCrMemoLines());
    end;

    local procedure BackfillSalesLines() Changed: Integer
    var
        SalesLine: Record "Sales Line";
        TimeSheetDate: Date;
    begin
        SalesLine.SetLoadFields("Document Type", "Document No.", "Line No.", "Job Contract Entry No.", "Time Sheet Date ori");
        SalesLine.SetFilter("Job Contract Entry No.", '<>0');
        SalesLine.SetRange("Time Sheet Date ori", 0D);
        if SalesLine.FindSet(true) then
            repeat
                TimeSheetDate := GetTimeSheetDate(SalesLine."Job Contract Entry No.");
                if TimeSheetDate <> 0D then begin
                    SalesLine."Time Sheet Date ori" := TimeSheetDate;
                    SalesLine.Modify(false);
                    Changed += 1;
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure BackfillSalesInvoiceLines() Changed: Integer
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        TimeSheetDate: Date;
    begin
        SalesInvoiceLine.SetLoadFields("Document No.", "Line No.", "Job Contract Entry No.", "Time Sheet Date ori");
        SalesInvoiceLine.SetFilter("Job Contract Entry No.", '<>0');
        SalesInvoiceLine.SetRange("Time Sheet Date ori", 0D);
        if SalesInvoiceLine.FindSet(true) then
            repeat
                TimeSheetDate := GetTimeSheetDate(SalesInvoiceLine."Job Contract Entry No.");
                if TimeSheetDate <> 0D then begin
                    SalesInvoiceLine."Time Sheet Date ori" := TimeSheetDate;
                    SalesInvoiceLine.Modify(false);
                    Changed += 1;
                end;
            until SalesInvoiceLine.Next() = 0;
    end;

    local procedure BackfillSalesCrMemoLines() Changed: Integer
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        TimeSheetDate: Date;
    begin
        SalesCrMemoLine.SetLoadFields("Document No.", "Line No.", "Job Contract Entry No.", "Time Sheet Date ori");
        SalesCrMemoLine.SetFilter("Job Contract Entry No.", '<>0');
        SalesCrMemoLine.SetRange("Time Sheet Date ori", 0D);
        if SalesCrMemoLine.FindSet(true) then
            repeat
                TimeSheetDate := GetTimeSheetDate(SalesCrMemoLine."Job Contract Entry No.");
                if TimeSheetDate <> 0D then begin
                    SalesCrMemoLine."Time Sheet Date ori" := TimeSheetDate;
                    SalesCrMemoLine.Modify(false);
                    Changed += 1;
                end;
            until SalesCrMemoLine.Next() = 0;
    end;
}
