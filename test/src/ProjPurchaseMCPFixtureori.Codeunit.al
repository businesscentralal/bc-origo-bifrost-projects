namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Projects;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Creates unique native purchase and tracked-stock fixtures only for the owner's disposable verification environment.</summary>
codeunit 97131 "Proj. Purchase MCP Fixture ori"
{
    Access = Internal;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds native master/planning records and posts an owned positive stock adjustment; never records licensing consent.</summary>
    procedure Seed() Manifest: JsonObject
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Vendor: Record Vendor;
        Customer: Record Customer;
        VATPostingSetup: Record "VAT Posting Setup";
        Item: Record Item;
        Project: Record Job;
        PlanningLine: Record "Job Planning Line";
        Library: Codeunit "Projects Test Library ori";
        PurchaseLibrary: Codeunit "Library - Purchase";
        ERMLibrary: Codeunit "Library - ERM";
        Planning: JsonObject;
        LotNo: Code[50];
    begin
        Library.Initialize();
        Planning := Library.NewPlanningRequest('Item');
        Item.Get(Planning.GetText('no'));
        Item.Validate(Type, Item.Type::Inventory);
        Item.Modify(true);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Planning), 'Success');
        PlanningLine.Get(Planning.GetText('projectNo'), Planning.GetText('taskNo'), Planning.GetInteger('lineNo'));
        PlanningLine.Validate("Usage Link", true);
        PlanningLine.Modify(true);
        Project.Get(Planning.GetText('projectNo'));
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        LotNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(LotNo));
        SeedTrackedInventoryAtLocation(Item."No.", false, LotNo, 10, '', '');
        Item.Get(Planning.GetText('no'));
        PurchaseLibrary.CreateVendor(Vendor);
        Customer.Get(Project."Bill-to Customer No.");
        ERMLibrary.CreateVATPostingSetupWithAccounts(VATPostingSetup, VATPostingSetup."VAT Calculation Type"::"Normal VAT", 0);
        Vendor.Validate("Gen. Bus. Posting Group", Customer."Gen. Bus. Posting Group");
        Vendor.Validate("VAT Bus. Posting Group", VATPostingSetup."VAT Bus. Posting Group");
        Vendor.Modify(true);
        Item.Validate("VAT Prod. Posting Group", VATPostingSetup."VAT Prod. Posting Group");
        Item.Modify(true);
        PurchaseLibrary.CreatePurchaseDocumentWithItem(PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, Vendor."No.", Item."No.", 1, '', WorkDate());
        Manifest.Add('projectNo', Project."No.");
        Manifest.Add('taskNo', PlanningLine."Job Task No.");
        Manifest.Add('planningLineNo', PlanningLine."Line No.");
        Manifest.Add('itemNo', Item."No.");
        Manifest.Add('lotNo', LotNo);
        Manifest.Add('stockQuantity', 10);
        Manifest.Add('purchaseSystemId', Format(PurchaseLine.SystemId, 0, 4));
        Manifest.Add('documentNo', PurchaseHeader."No.");
        Manifest.Add('documentType', 'Order');
        Manifest.Add('lineNo', PurchaseLine."Line No.");
        Manifest.Add('customerNo', Project."Bill-to Customer No.");
        Manifest.Add('vendorNo', Vendor."No.");
        Manifest.Add('cleanup', 'Delete the individually owned disposable container after evidence collection; do not delete posted ledger records.');
    end;

    local procedure SeedTrackedInventoryAtLocation(ItemNo: Code[20]; Serial: Boolean; TrackingNo: Code[50]; Quantity: Decimal; LocationCode: Code[10]; BinCode: Code[20])
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        InventoryGroup: Record "Inventory Posting Group";
        InventorySetup: Record "Inventory Posting Setup";
        GeneralSetup: Record "General Posting Setup";
        Account: Record "G/L Account";
        TempJournal: Record "Item Journal Line" temporary;
        Tracking: Record "Reservation Entry";
        TempSpecification: Record "Tracking Specification" temporary;
        PostBatch: Codeunit "Item Jnl.-Post Batch";
        PostItem: Codeunit "Item Jnl.-Post Line";
        CreateEntry: Codeunit "Create Reserv. Entry";
    begin
        Item.Get(ItemNo);
        TrackingCode.Code := CopyStr(ItemNo, 1, MaxStrLen(TrackingCode.Code));
        TrackingCode."SN Specific Tracking" := Serial;
        TrackingCode."Lot Specific Tracking" := not Serial;
        if LocationCode <> '' then begin
            TrackingCode."SN Warehouse Tracking" := Serial;
            TrackingCode."Lot Warehouse Tracking" := not Serial;
        end;
        TrackingCode.Insert(true);
        InventoryGroup.Code := ItemNo;
        InventoryGroup.Insert(true);
        Account."No." := ItemNo;
        Account.Name := 'X owned inventory posting account';
        Account."Direct Posting" := true;
        Account.Insert(true);
        InventorySetup."Location Code" := LocationCode;
        InventorySetup."Invt. Posting Group Code" := InventoryGroup.Code;
        InventorySetup."Inventory Account" := Account."No.";
        InventorySetup."Inventory Account (Interim)" := Account."No.";
        InventorySetup.Insert(true);
        GeneralSetup.SetRange("Gen. Prod. Posting Group", Item."Gen. Prod. Posting Group");
        GeneralSetup.FindFirst();
        GeneralSetup."Inventory Adjmt. Account" := Account."No.";
        GeneralSetup."Direct Cost Applied Account" := Account."No.";
        GeneralSetup."COGS Account" := Account."No.";
        GeneralSetup.Modify(true);
        Assert.AreEqual(Item.Type::Inventory, Item.Type, 'Inventory type was set before planning lines were created');
        Item.Validate("Inventory Posting Group", InventoryGroup.Code);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        TempJournal."Line No." := 10000;
        TempJournal."Entry Type" := TempJournal."Entry Type"::"Positive Adjmt.";
        TempJournal.Validate("Posting Date", WorkDate());
        TempJournal.Validate("Document No.", ItemNo);
        TempJournal.Validate("Item No.", ItemNo);
        TempJournal.Validate("Gen. Bus. Posting Group", GeneralSetup."Gen. Bus. Posting Group");
        if LocationCode <> '' then
            TempJournal.Validate("Location Code", LocationCode);
        if BinCode <> '' then
            TempJournal.Validate("Bin Code", BinCode);
        TempJournal.Validate(Quantity, Quantity);
        TempJournal.Validate("Unit Cost", 7);
        if Serial then
            Tracking."Serial No." := TrackingNo
        else
            Tracking."Lot No." := TrackingNo;
        CreateEntry.CreateReservEntryFor(Database::"Item Journal Line", TempJournal."Entry Type".AsInteger(), TempJournal."Journal Template Name", TempJournal."Journal Batch Name", 0, TempJournal."Line No.", TempJournal."Qty. per Unit of Measure", Quantity, TempJournal."Quantity (Base)", Tracking);
        CreateEntry.CreateEntry(ItemNo, '', LocationCode, Item.Description, 0D, WorkDate(), 0, "Reservation Status"::Surplus);
        PostItem.RunWithCheck(TempJournal);
        if BinCode <> '' then begin
            PostItem.CollectTrackingSpecification(TempSpecification);
            PostBatch.PostWhseJnlLine(TempJournal, Quantity, TempJournal."Quantity (Base)", TempSpecification);
        end;
    end;


}
