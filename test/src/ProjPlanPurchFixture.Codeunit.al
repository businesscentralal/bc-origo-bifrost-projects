namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;
using Microsoft.Purchases.Setup;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

/// <summary>Raw acceptance fixtures shared by AL and MCP verification on owned tenants only.</summary>
codeunit 97173 "Proj. Plan Purch Fixture ori"
{
    Access = Internal;

    var
        Library: Codeunit "Projects Test Library ori";

    /// <summary>Prepares owned test setup and selects an open inventory period.</summary>
    internal procedure Initialize(AllowPosting: Boolean)
    var
        Setup: Record "Projects Setup ori";
        JobsSetup: Record Microsoft.Projects.Project.Setup."Jobs Setup";
        Period: Record Microsoft.Inventory.Setup."Inventory Period";
        GLSetup: Record "General Ledger Setup";
        UserSetup: Record System.Security.User."User Setup";
        PostingDate: Date;
    begin
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(true);
        if not JobsSetup.Get() then
            JobsSetup.Insert(true);
        // Use an open period; do not reopen or bypass a closed inventory period.
        PostingDate := Today();
        Period.SetRange(Closed, true);
        if Period.FindLast() then
            if Period."Ending Date" >= PostingDate then
                PostingDate := Period."Ending Date" + 1;
        WorkDate(PostingDate);
        if not AllowPosting then
            exit;
        GLSetup.Get();
        GLSetup."Allow Posting From" := PostingDate;
        GLSetup."Allow Posting To" := PostingDate;
        Clear(GLSetup."Allow Posting From DateFormula");
        Clear(GLSetup."Allow Posting To DateFormula");
        GLSetup.Modify(true);
        if UserSetup.Get(UserId()) then begin
            UserSetup."Allow Posting From" := PostingDate;
            UserSetup."Allow Posting To" := PostingDate;
            Clear(UserSetup."Allow Posting From DateFormula");
            Clear(UserSetup."Allow Posting To DateFormula");
            UserSetup.Modify(true);
        end;
    end;

    local procedure SeedProjectAndItem() PlanningRequest: JsonObject
    var
        Customer: Record Customer;
        Request: JsonObject;
        TaskRequest: JsonObject;
    begin
        Customer."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Customer."No."));
        Customer.Name := 'X owned purchase planning customer';
        Customer.Insert(true);
        Request.Add('projectNo', Customer."No.");
        Request.Add('billToCustomerNo', Customer."No.");
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        TaskRequest.Add('projectNo', Customer."No.");
        TaskRequest.Add('taskNo', 'X100');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        PlanningRequest := NewItemRequest(Customer."No.", 10000);
    end;

    local procedure SeedItem(CustomerNo: Code[20]): Code[20]
    var
        Customer: Record Customer;
        Item: Record Item;
        BusGroup: Record "Gen. Business Posting Group";
        ProdGroup: Record "Gen. Product Posting Group";
        General: Record "General Posting Setup";
        Unit: Record Microsoft.Foundation.UOM."Unit of Measure";
        ItemUnit: Record "Item Unit of Measure";
        CodeValue: Code[20];
    begin
        CodeValue := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        BusGroup.Code := CodeValue;
        BusGroup.Insert(true);
        ProdGroup.Code := CodeValue;
        ProdGroup.Insert(true);
        General."Gen. Bus. Posting Group" := CodeValue;
        General."Gen. Prod. Posting Group" := CodeValue;
        General.Insert(true);
        Customer.Get(CustomerNo);
        Customer.Validate("Gen. Bus. Posting Group", CodeValue);
        Customer.Modify(true);
        Unit.Code := CopyStr(CodeValue, 1, MaxStrLen(Unit.Code));
        Unit.Insert(true);
        Item."No." := CodeValue;
        Item.Description := 'X owned planning item';
        Item.Type := Item.Type::Inventory;
        Item."Gen. Prod. Posting Group" := CodeValue;
        Item."Base Unit of Measure" := Unit.Code;
        Item.Insert(true);
        ItemUnit."Item No." := CodeValue;
        ItemUnit.Code := Unit.Code;
        ItemUnit."Qty. per Unit of Measure" := 1;
        ItemUnit.Insert(true);
        exit(CodeValue);
    end;

    /// <summary>Seeds raw item demand for one project without borrowing demo master data.</summary>
    internal procedure Seed(AllowPosting: Boolean) Request: JsonObject
    var
        PlanningRequest: JsonObject;
        Item: Record Item;
        Project: Record Job;
        Planning: Record "Job Planning Line";
    begin
        Initialize(AllowPosting);
        PlanningRequest := SeedProjectAndItem();
        Item.Get(PlanningRequest.GetText('no'));
        Item.Type := Item.Type::Inventory;
        Item.Modify(true);
        PlanningRequest.Replace('planningDate', Format(WorkDate(), 0, 9));
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanningRequest), 'Success');
        Project.Get(PlanningRequest.GetText('projectNo'));
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        Planning.Get(Project."No.", 'X100', 10000);
        Planning.Validate("Usage Link", true);
        Planning.Modify(true);
        ConfigurePurchaseItem(Item, Project."No.");
        SeedNumberSeries();
        Request.Add('projectNo', Project."No.");
    end;

    /// <summary>Creates an item and returns a native planning-line request in the same project.</summary>
    internal procedure NewItemRequest(ProjectNo: Code[20]; LineNo: Integer) Request: JsonObject
    var
        Project: Record Job;
        Item: Record Item;
        MasterNo: Code[20];
    begin
        Project.Get(ProjectNo);
        MasterNo := SeedItem(Project."Bill-to Customer No.");
        Item.Get(MasterNo);
        Item.Type := Item.Type::Inventory;
        Item.Modify(true);
        Request.Add('projectNo', ProjectNo);
        Request.Add('taskNo', 'X100');
        Request.Add('lineNo', LineNo);
        Request.Add('type', 'Item');
        Request.Add('no', MasterNo);
        Request.Add('lineType', 'Both Budget and Billable');
        Request.Add('planningDate', Format(WorkDate(), 0, 9));
        Request.Add('quantity', 3);
        Request.Add('unitCost', 7);
        Request.Add('unitPrice', 11);
    end;

    /// <summary>Creates owned purchase, VAT and inventory posting setup for the item.</summary>
    internal procedure ConfigurePurchaseItem(var Item: Record Item; ProjectNo: Code[20])
    var
        Vendor: Record Vendor;
        Customer: Record Customer;
        Project: Record Job;
        Account: Record "G/L Account";
        General: Record "General Posting Setup";
        InventoryGroup: Record "Inventory Posting Group";
        InventorySetup: Record "Inventory Posting Setup";
        VendorGroup: Record "Vendor Posting Group";
        VATBus: Record "VAT Business Posting Group";
        VATProd: Record "VAT Product Posting Group";
        VATSetup: Record "VAT Posting Setup";
        JobGroup: Record "Job Posting Group";
        CodeValue: Code[20];
    begin
        CodeValue := Item."No.";
        Account."No." := CodeValue;
        Account.Name := 'X purchase planning account';
        Account."Direct Posting" := true;
        Account.Insert(true);
        Project.Get(ProjectNo);
        Customer.Get(Project."Bill-to Customer No.");
        General.Get(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        General."Purch. Account" := CodeValue;
        General."Purch. Credit Memo Account" := CodeValue;
        General."Direct Cost Applied Account" := CodeValue;
        General."Inventory Adjmt. Account" := CodeValue;
        General."COGS Account" := CodeValue;
        General."COGS Account (Interim)" := CodeValue;
        General."Invt. Accrual Acc. (Interim)" := CodeValue;
        General.Modify(true);
        InventoryGroup.Code := CodeValue;
        InventoryGroup.Insert(true);
        InventorySetup."Invt. Posting Group Code" := CodeValue;
        InventorySetup."Inventory Account" := CodeValue;
        InventorySetup."Inventory Account (Interim)" := CodeValue;
        InventorySetup.Insert(true);
        VendorGroup.Code := CodeValue;
        VendorGroup."Payables Account" := CodeValue;
        VendorGroup.Insert(true);
        VATBus.Code := CodeValue;
        VATBus.Insert(true);
        VATProd.Code := CodeValue;
        VATProd.Insert(true);
        VATSetup."VAT Bus. Posting Group" := CodeValue;
        VATSetup."VAT Prod. Posting Group" := CodeValue;
        VATSetup."Purchase VAT Account" := CodeValue;
        VATSetup."Sales VAT Account" := CodeValue;
        VATSetup.Insert(true);
        Vendor."No." := CodeValue;
        Vendor.Name := 'X owned planning vendor';
        Vendor."Gen. Bus. Posting Group" := Customer."Gen. Bus. Posting Group";
        Vendor."VAT Bus. Posting Group" := CodeValue;
        Vendor."Vendor Posting Group" := CodeValue;
        Vendor.Insert(true);
        Item.Validate("Inventory Posting Group", CodeValue);
        Item.Validate("VAT Prod. Posting Group", CodeValue);
        Item.Validate("Vendor No.", CodeValue);
        Item.Validate("Replenishment System", Item."Replenishment System"::Purchase);
        Item.Modify(true);
        if not JobGroup.Get(ProjectNo) then begin
            JobGroup.Code := ProjectNo;
            JobGroup."Job Costs Applied Account" := CodeValue;
            JobGroup."Job Costs Adjustment Account" := CodeValue;
            JobGroup."WIP Costs Account" := CodeValue;
            JobGroup.Insert(true);
        end;
        Project.Validate("Job Posting Group", ProjectNo);
        Project.Modify(true);
    end;

    local procedure SeedNumberSeries()
    var
        Setup: Record "Purchases & Payables Setup";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
    begin
        Series.Code := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Series.Code));
        Series."Default Nos." := true;
        Series.Insert(true);
        SeriesLine."Series Code" := Series.Code;
        SeriesLine."Line No." := 10000;
        SeriesLine."Starting No." := CopyStr(Series.Code, 1, 10) + '000001';
        SeriesLine."Ending No." := CopyStr(Series.Code, 1, 10) + '999999';
        SeriesLine."Increment-by No." := 1;
        SeriesLine.Insert(true);
        Setup.Get();
        Setup."Order Nos." := Series.Code;
        Setup."Posted Receipt Nos." := Series.Code;
        Setup."Posted Invoice Nos." := Series.Code;
        Setup.Modify(true);
    end;
    /// <summary>Creates two-vendor demand and records the native setup values needed for cleanup.</summary>
    internal procedure SeedMCP() Manifest: JsonObject
    var
        Setup: Record "Purchases & Payables Setup";
        Item: Record Item;
        Request: JsonObject;
        PlanningRequest: JsonObject;
    begin
        Setup.Get();
        Manifest.Add('originalOrderNos', Setup."Order Nos.");
        Manifest.Add('originalReceiptNos', Setup."Posted Receipt Nos.");
        Manifest.Add('originalInvoiceNos', Setup."Posted Invoice Nos.");
        Request := Seed(false);
        PlanningRequest := NewItemRequest(CopyStr(Request.GetText('projectNo'), 1, 20), 20000);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanningRequest), 'Success');
        Item.Get(PlanningRequest.GetText('no'));
        ConfigurePurchaseItem(Item, CopyStr(Request.GetText('projectNo'), 1, 20));
        Setup.Get();
        Manifest.Add('seedSeriesCode', Setup."Order Nos.");
        Manifest.Add('projectNo', Request.GetText('projectNo'));
        Manifest.Add('status', 'Success');
    end;

    /// <summary>Removes only the unposted fixture named by its manifest and restores purchase numbering.</summary>
    internal procedure Cleanup(Manifest: JsonObject)
    var
        Setup: Record "Purchases & Payables Setup";
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        TempItem: Record Item temporary;
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Unit: Record Microsoft.Foundation.UOM."Unit of Measure";
        Vendor: Record Vendor;
        Customer: Record Customer;
        Account: Record "G/L Account";
        Ledger: Record Microsoft.Finance.GeneralLedger.Ledger."G/L Entry";
        General: Record "General Posting Setup";
        BusGroup: Record "Gen. Business Posting Group";
        ProdGroup: Record "Gen. Product Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
        InventorySetup: Record "Inventory Posting Setup";
        VendorGroup: Record "Vendor Posting Group";
        VATBus: Record "VAT Business Posting Group";
        VATProd: Record "VAT Product Posting Group";
        VATSetup: Record "VAT Posting Setup";
        JobGroup: Record "Job Posting Group";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        ProjectNo: Code[20];
    begin
        ProjectNo := CopyStr(Manifest.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        if CopyStr(ProjectNo, 1, 1) <> 'X' then
            Error('Only owned X fixtures can be removed.');
        Project.Get(ProjectNo);
        Planning.SetRange("Job No.", ProjectNo);
        if Planning.FindSet() then
            repeat
                Item.Get(Planning."No.");
                TempItem := Item;
                if not TempItem.Insert() then;
            until Planning.Next() = 0;
        Line.SetRange("Job No.", ProjectNo);
        while Line.FindFirst() do begin
            Line.TestField("Quantity Received", 0);
            Line.TestField("Quantity Invoiced", 0);
            Header.Get(Line."Document Type", Line."Document No.");
            Header.Delete(true);
        end;
        Planning.DeleteAll(true);
        Task.SetRange("Job No.", ProjectNo);
        Task.DeleteAll(true);
        Project.Delete(true);
        if JobGroup.Get(ProjectNo) then
            JobGroup.Delete(true);
        Customer.Get(Project."Bill-to Customer No.");
        Customer.Delete(true);
        if TempItem.FindSet() then
            repeat
                Item.Get(TempItem."No.");
                Item.TestField(Description, 'X owned planning item');
                Vendor.Get(Item."Vendor No.");
                Vendor.Delete(true);
                Item.Delete(true);
                ItemUnit.SetRange("Item No.", TempItem."No.");
                ItemUnit.DeleteAll(true);
                if Unit.Get(TempItem."Base Unit of Measure") then
                    Unit.Delete(true);
                General.SetRange("Gen. Prod. Posting Group", TempItem."Gen. Prod. Posting Group");
                General.DeleteAll(true);
                InventorySetup.SetRange("Invt. Posting Group Code", TempItem."Inventory Posting Group");
                InventorySetup.DeleteAll(true);
                VATSetup.SetRange("VAT Prod. Posting Group", TempItem."VAT Prod. Posting Group");
                VATSetup.DeleteAll(true);
                if InventoryGroup.Get(TempItem."Inventory Posting Group") then
                    InventoryGroup.Delete(true);
                if VendorGroup.Get(TempItem."No.") then
                    VendorGroup.Delete(true);
                if VATBus.Get(TempItem."No.") then
                    VATBus.Delete(true);
                if VATProd.Get(TempItem."No.") then
                    VATProd.Delete(true);
                if BusGroup.Get(TempItem."No.") then
                    BusGroup.Delete(true);
                if ProdGroup.Get(TempItem."No.") then
                    ProdGroup.Delete(true);
                if Account.Get(TempItem."No.") then begin
                    Account.TestField(Name, 'X purchase planning account');
                    Ledger.SetRange("G/L Account No.", Account."No.");
                    if not Ledger.IsEmpty() then
                        Error('An owned fixture account has entries; cleanup refused.');
                    // No posting exists. Remove only this newly created test account without changing the company-wide deletion block.
                    Account.Delete(false);
                end;
            until TempItem.Next() = 0;
        Setup.Get();
        Setup.TestField("Order Nos.", Manifest.GetText('seedSeriesCode'));
        Setup."Order Nos." := CopyStr(Manifest.GetText('originalOrderNos'), 1, MaxStrLen(Setup."Order Nos."));
        Setup."Posted Receipt Nos." := CopyStr(Manifest.GetText('originalReceiptNos'), 1, MaxStrLen(Setup."Posted Receipt Nos."));
        Setup."Posted Invoice Nos." := CopyStr(Manifest.GetText('originalInvoiceNos'), 1, MaxStrLen(Setup."Posted Invoice Nos."));
        Setup.Modify(true);
        SeriesLine.SetRange("Series Code", Manifest.GetText('seedSeriesCode'));
        SeriesLine.DeleteAll(true);
        Series.Get(Manifest.GetText('seedSeriesCode'));
        Series.Delete(true);
    end;
}
