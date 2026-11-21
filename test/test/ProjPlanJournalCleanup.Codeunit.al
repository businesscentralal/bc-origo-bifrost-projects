namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Removes only this story's marked native fixtures from an owned test company.</summary>
codeunit 97183 "Proj. Plan Jnl Cleanup ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    /// <summary>Cleans self-seeded AL and MCP fixtures, including their owned posting entries.</summary>
    [Test]
    procedure AC99_CleanupOwnedFixtures()
    var
        Project: Record Job;
        Assert: Codeunit "Library Assert";
    begin
        // Story #81, AC01-AC05 | Time: none | Risk: Owned fixture cleanup only
        if not CompanyName().StartsWith('CRONUS') then
            Error('Fixture cleanup is restricted to owned CRONUS test companies.');
        Project.SetRange(Description, 'X PlanJournal81 fixture');
        while Project.FindFirst() do
            Cleanup(Project);
        Assert.IsTrue(Project.IsEmpty(), 'All marked project journal fixtures removed');
        Commit();
    end;

    local procedure Cleanup(var Project: Record Job)
    var
        Planning: Record "Job Planning Line";
        Task: Record "Job Task";
        UsageLink: Record "Job Usage Link";
        JobLedger: Record "Job Ledger Entry";
        Journal: Record "Job Journal Line";
        Batch: Record "Job Journal Batch";
        Template: Record "Job Journal Template";
        Customer: Record Customer;
        JobGroup: Record "Job Posting Group";
        GL: Record "G/L Entry";
        Account: Record "G/L Account";
        LedgerRef: RecordRef;
        ResourceNo: Code[20];
        ItemNo: Code[20];
    begin
        Project.TestField(Description, 'X PlanJournal81 fixture');
        if CopyStr(Project."No.", 1, 1) <> 'X' then
            Error('Only exact story-owned X fixtures can be removed.');
        Planning.Get(Project."No.", 'X100', 10000);
        ResourceNo := Planning."No.";
        Planning.Get(Project."No.", 'X100', 20000);
        ItemNo := Planning."No.";
        Journal.SetRange("Journal Template Name", CopyStr(Project."No.", 1, 10));
        Journal.DeleteAll(false);
        Batch.SetRange("Journal Template Name", CopyStr(Project."No.", 1, 10));
        Batch.DeleteAll(false);
        if Template.Get(CopyStr(Project."No.", 1, 10)) then begin
            Template.TestField(Description, 'X PlanJournal81 fixture');
            Template.Delete(false);
        end;
        UsageLink.SetRange("Job No.", Project."No.");
        UsageLink.DeleteAll(false);
        JobLedger.SetRange("Job No.", Project."No.");
        LedgerRef.GetTable(JobLedger);
        DeleteLedgerAndRegisters(LedgerRef, Database::"Job Register");
        CleanupResource(ResourceNo);
        CleanupItem(ItemNo);
        GL.SetRange("G/L Account No.", Project."No.");
        LedgerRef.GetTable(GL);
        DeleteLedgerAndRegisters(LedgerRef, Database::"G/L Register");
        Planning.SetRange("Job No.", Project."No.");
        Planning.DeleteAll(false);
        Task.SetRange("Job No.", Project."No.");
        Task.DeleteAll(false);
        Customer.Get(Project."Bill-to Customer No.");
        Customer.TestField(Name, 'X Projects unit test');
        Customer.Delete(false);
        if JobGroup.Get(Project."No.") then
            JobGroup.Delete(false);
        Account.Get(Project."No.");
        Account.TestField(Name, 'X PlanJournal81 fixture');
        Account.Delete(false);
        Project.Delete(false);
    end;

    local procedure CleanupResource(ResourceNo: Code[20])
    var
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        ResourceLedger: Record "Res. Ledger Entry";
        Unit: Record "Unit of Measure";
        LedgerRef: RecordRef;
    begin
        Resource.Get(ResourceNo);
        Resource.TestField(Name, 'X Projects resource');
        ResourceLedger.SetRange("Resource No.", ResourceNo);
        LedgerRef.GetTable(ResourceLedger);
        DeleteLedgerAndRegisters(LedgerRef, Database::"Resource Register");
        ResourceUnit.SetRange("Resource No.", ResourceNo);
        ResourceUnit.DeleteAll(false);
        if Unit.Get(Resource."Base Unit of Measure") then
            Unit.Delete(false);
        Resource.Delete(false);
        CleanupPostingGroups(ResourceNo);
    end;

    local procedure CleanupItem(ItemNo: Code[20])
    var
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Unit: Record "Unit of Measure";
        ItemLedger: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Relation: Record "G/L - Item Ledger Relation";
        Application: Record "Item Application Entry";
        InventorySetup: Record "Inventory Posting Setup";
        InventoryGroup: Record "Inventory Posting Group";
        LedgerRef: RecordRef;
    begin
        Item.Get(ItemNo);
        Item.TestField(Description, 'X Projects item');
        ValueEntry.SetRange("Item No.", ItemNo);
        ValueEntry.SetLoadFields("Entry No.");
        if ValueEntry.FindSet() then
            repeat
                Relation.SetRange("Value Entry No.", ValueEntry."Entry No.");
                Relation.DeleteAll(false);
            until ValueEntry.Next() = 0;
        ValueEntry.DeleteAll(false);
        Application.SetRange("Item No.", ItemNo);
        Application.DeleteAll(false);
        ItemLedger.SetRange("Item No.", ItemNo);
        LedgerRef.GetTable(ItemLedger);
        DeleteLedgerAndRegisters(LedgerRef, Database::"Item Register");
        ItemUnit.SetRange("Item No.", ItemNo);
        ItemUnit.DeleteAll(false);
        if Unit.Get(Item."Base Unit of Measure") then
            Unit.Delete(false);
        InventorySetup.SetRange("Invt. Posting Group Code", Item."Inventory Posting Group");
        InventorySetup.DeleteAll(false);
        if InventoryGroup.Get(Item."Inventory Posting Group") then
            InventoryGroup.Delete(false);
        Item.Delete(false);
        CleanupPostingGroups(ItemNo);
    end;

    local procedure CleanupPostingGroups(MasterNo: Code[20])
    var
        General: Record "General Posting Setup";
        Business: Record "Gen. Business Posting Group";
        Product: Record "Gen. Product Posting Group";
    begin
        General.SetRange("Gen. Prod. Posting Group", MasterNo);
        General.DeleteAll(false);
        if Business.Get(MasterNo) then
            Business.Delete(false);
        if Product.Get(MasterNo) then
            Product.Delete(false);
    end;

    local procedure DeleteLedgerAndRegisters(var OwnedEntries: RecordRef; RegisterTableNo: Integer)
    var
        Registers: RecordRef;
        AllEntries: RecordRef;
        ScopedEntries: RecordRef;
        FromEntry: Integer;
        ToEntry: Integer;
    begin
        if OwnedEntries.IsEmpty() then
            exit;
        Registers.Open(RegisterTableNo);
        AllEntries.Open(OwnedEntries.Number());
        ScopedEntries.Open(OwnedEntries.Number());
        ScopedEntries.SetView(OwnedEntries.GetView());
        if Registers.FindSet() then
            repeat
                // Register tables share fields 2/3 for their first/last ledger entry number.
                FromEntry := Registers.Field(2).Value();
                ToEntry := Registers.Field(3).Value();
                if (FromEntry > 0) and (ToEntry >= FromEntry) then begin
                    AllEntries.Field(1).SetRange(FromEntry, ToEntry);
                    ScopedEntries.Field(1).SetRange(FromEntry, ToEntry);
                    if (ScopedEntries.Count() > 0) and (ScopedEntries.Count() = AllEntries.Count()) then
                        Registers.Delete(false);
                end;
            until Registers.Next() = 0;
        OwnedEntries.DeleteAll(false);
    end;
}
