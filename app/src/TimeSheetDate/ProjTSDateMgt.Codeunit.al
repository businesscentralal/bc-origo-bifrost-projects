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

    /// <summary>True when the document the lines part shows (SubPageLink filter, or the current line) has a line with a Job Contract Entry No.; when no document is known yet, true when the company has any such line.</summary>
    procedure HasProjectLines(var SalesLine: Record "Sales Line"): Boolean
    var
        DocLine: Record "Sales Line";
        DocNoFilter: Text;
        DocTypeFilter: Text;
    begin
        DocNoFilter := GetLinkFilter(SalesLine."Document No.", SalesLine.GetFilter("Document No."), GetGroupFilter(SalesLine, 4, true));
        DocTypeFilter := GetGroupFilter(SalesLine, 4, false);
        if SalesLine."Document No." <> '' then
            DocLine.SetRange("Document Type", SalesLine."Document Type")
        else
            if DocTypeFilter <> '' then
                DocLine.SetFilter("Document Type", DocTypeFilter);
        if DocNoFilter <> '' then
            DocLine.SetFilter("Document No.", DocNoFilter);
        DocLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocLine.IsEmpty());
    end;

    procedure HasProjectLines(var SalesInvoiceLine: Record "Sales Invoice Line"): Boolean
    var
        DocLine: Record "Sales Invoice Line";
        DocNoFilter: Text;
        GroupFilter: Text;
    begin
        SalesInvoiceLine.FilterGroup(4);
        GroupFilter := SalesInvoiceLine.GetFilter("Document No.");
        SalesInvoiceLine.FilterGroup(0);
        DocNoFilter := GetLinkFilter(SalesInvoiceLine."Document No.", SalesInvoiceLine.GetFilter("Document No."), GroupFilter);
        if DocNoFilter <> '' then
            DocLine.SetFilter("Document No.", DocNoFilter);
        DocLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocLine.IsEmpty());
    end;

    procedure HasProjectLines(var SalesCrMemoLine: Record "Sales Cr.Memo Line"): Boolean
    var
        DocLine: Record "Sales Cr.Memo Line";
        DocNoFilter: Text;
        GroupFilter: Text;
    begin
        SalesCrMemoLine.FilterGroup(4);
        GroupFilter := SalesCrMemoLine.GetFilter("Document No.");
        SalesCrMemoLine.FilterGroup(0);
        DocNoFilter := GetLinkFilter(SalesCrMemoLine."Document No.", SalesCrMemoLine.GetFilter("Document No."), GroupFilter);
        if DocNoFilter <> '' then
            DocLine.SetFilter("Document No.", DocNoFilter);
        DocLine.SetFilter("Job Contract Entry No.", '<>0');
        exit(not DocLine.IsEmpty());
    end;

    local procedure GetGroupFilter(var SalesLine: Record "Sales Line"; Group: Integer; DocumentNo: Boolean) Result: Text
    begin
        SalesLine.FilterGroup(Group);
        if DocumentNo then
            Result := SalesLine.GetFilter("Document No.")
        else
            Result := SalesLine.GetFilter("Document Type");
        SalesLine.FilterGroup(0);
    end;

    local procedure GetLinkFilter(CurrentDocumentNo: Code[20]; Group0Filter: Text; Group4Filter: Text): Text
    begin
        if CurrentDocumentNo <> '' then
            exit(CurrentDocumentNo);
        if Group4Filter <> '' then
            exit(Group4Filter);
        exit(Group0Filter);
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
