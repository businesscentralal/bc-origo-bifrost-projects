namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Permission tests for the Projects.Usage.* message types (projects#52, AC11).</summary>
codeunit 97154 "TS Usage Perm Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure ReadRole_CanList_CannotRegister()
    var
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        TempArgument: Record "Message Argument ori" temporary;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsTrue(Mgt.CanUse(7), 'A read-only role sees List.');
        Assert.IsFalse(Mgt.CanUse(1), 'A read-only role cannot register.');
        Assert.IsFalse(Mgt.CanUse(5), 'A read-only role cannot transfer.');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Mgt.Execute(TempArgument, 1);
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal code.');
        Response.Get('nextStep', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('BIFROST Full ori'), 'Names the permission set.');
    end;

    [Test]
    procedure NoJournalWrite_TransferRefusedWithNextStep()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        Item: Record Item;
        ItemTemplate: Record "Item Journal Template";
        ItemBatch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        LibraryInventory: Codeunit "Library - Inventory";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Header.Init();
        Header."No." := CopyStr('XU52P' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Starting Date" := WorkDate();
        Header."Ending Date" := WorkDate() + 6;
        Header."Owner User ID" := 'XOWNER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert(false);
        Line.Init();
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := 10000;
        Line.Insert(false);
        LibraryInventory.CreateItem(Item);
        Usage.Init();
        Usage."Time Sheet No." := Header."No.";
        Usage."Time Sheet Line No." := 10000;
        Usage."No." := Item."No.";
        Usage.Date := WorkDate();
        Usage.Quantity := 1;
        Usage.Status := Usage.Status::Approved;
        Usage.Insert();
        LibraryInventory.CreateItemJournalTemplate(ItemTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemBatch, ItemTemplate.Name);
        Request.Add('timeSheetNo', Header."No.");
        Request.Add('itemTemplate', ItemTemplate.Name);
        Request.Add('itemBatch', ItemBatch.Name);
        Lower.PushPermissionSetWithoutDefaults('TSUsageNoJournal ori');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Mgt.Execute(TempArgument, 5);
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal code.');
        Response.Get('nextStep', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('journal permissions'), 'Names the journal permissions.');
        Usage.Get(Usage."Entry No.");
        Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Nothing changed.');
    end;
}
