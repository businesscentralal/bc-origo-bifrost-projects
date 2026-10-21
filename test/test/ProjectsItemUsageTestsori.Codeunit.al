namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Tests native item usage with isolated project/item fixtures and strict refusal assertions.</summary>
codeunit 97125 "Projects Item Usage Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>A native journal post produces only ledger entries for the owned project and item.</summary>
    [Test]
    procedure HappyPath_PostsThroughNativeProjectJournal()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.GetInteger('firstEntryNo') > 0, 'Native posting returns a ledger entry');
        Ledger.Get(Response.GetInteger('firstEntryNo'));
        Assert.AreEqual(Request.GetText('projectNo'), Ledger."Job No.", 'Owned project ledger entry');
        Assert.AreEqual(Request.GetText('taskNo'), Ledger."Job Task No.", 'Owned project task');
        Assert.AreEqual(2, Ledger.Quantity, 'Native usage quantity');
        Assert.AreEqual(Ledger.Type::Item, Ledger.Type, 'Item usage posting');
        Assert.AreEqual(Response.GetInteger('firstEntryNo'), Response.GetInteger('lastEntryNo'), 'Single line ledger range');
    end;

    /// <summary>Blocked projects refuse before any native ledger write.</summary>
    [Test]
    procedure BlockedProject_RefusesWithoutLedgerWrites()
    var
        Project: Record Job;
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Project.Get(Request.GetText('projectNo'));
        Project.Blocked := Project.Blocked::All;
        Project.Modify(true);
        Response := ValidateRequest(Request);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Blocked project refusal');
        Assert.AreEqual('Change the status with Projects.Project.SetStatus.', Response.GetText('nextStep'), 'Exact status remedy');
        Ledger.SetRange("Job No.", Project."No.");
        Assert.IsTrue(Ledger.IsEmpty(), 'No owned project ledger entries');
    end;

    /// <summary>A missing later item refuses the whole request before the valid first line can post.</summary>
    [Test]
    procedure InvalidSecondItem_RefusesEntireArrayBeforePosting()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Lines := Request.GetArray('lines');
        Line.Add('itemNo', 'X-MISSING-' + CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 8));
        Line.Add('quantity', 1);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := Execute(Request);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing second item');
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Ledger.IsEmpty(), 'Valid first line was not posted');
    end;

    /// <summary>Empty arrays and non-object lines have deterministic actionable refusals.</summary>
    [Test]
    procedure EmptyAndWrongTypedLines_Refuse()
    var
        Request: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Empty array');
        Assert.AreEqual('lines', Response.GetText('parameter'), 'Names missing lines');
        Lines.Add(7);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Scalar is not a usage object');
    end;

    /// <summary>Unknown nested fields and numeric strings are never silently accepted.</summary>
    [Test]
    procedure NestedUnknownAndWrongTypedKeys_Refuse()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Add('unitCost', 100);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'No silent direct price/cost overrides');
        Line.Remove('unitCost');
        Line.Replace('quantity', '2');
        Clear(Lines);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Numeric string is not a number');
    end;

    /// <summary>Zero and negative quantities refuse before entering native posting.</summary>
    [Test]
    procedure NonpositiveQuantity_Refuses()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Replace('quantity', 0);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Zero is not item consumption');
        Line.Replace('quantity', -1);
        Clear(Lines);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Negative consumption excluded');
    end;

    /// <summary>A single serial number cannot consume multiple base units.</summary>
    [Test]
    procedure SerialQuantity_RequiresOneBaseUnit()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Add('serialNo', 'OWN-SERIAL');
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Two base units cannot share one serial');
        Assert.AreEqual('serialNo', Response.GetText('parameter'), 'Names tracking selector');
    end;

    /// <summary>A later native validation error rolls back an earlier successfully processed line.</summary>
    [Test]
    procedure NativeFailureOnSecondLine_RollsBackFirstLine()
    var
        Item: Record Item;
        Ledger: Record "Job Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
        Observer: Codeunit "Proj. Usage Observed ori";
        Request: JsonObject;
        OtherRequest: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        OtherRequest := NewRequest();
        Line := OtherRequest.GetArray('lines').GetObject(0);
        Item.Get(Line.GetText('itemNo'));
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Lines := Request.GetArray('lines');
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Observer.ObserveProject(CopyStr(Request.GetText('projectNo'), 1, 20));
        BindSubscription(Observer);
        Usage.Execute(TempArgument);
        UnbindSubscription(Observer);
        Assert.IsTrue(Observer.ObservedCount() > 0, 'An earlier native ledger insertion actually occurred before the later failure');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Error', Response.GetText('status'), 'Native blocked second item is a clean error');
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Ledger.IsEmpty(), 'Earlier first-line native posting rolled back with the whole task');
    end;

    /// <summary>Every native line entry is captured rather than only the final returned posting identifier.</summary>
    [Test]
    procedure MultipleNativeLines_ReturnExactCreatedEntryList()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        TotalQuantity: Decimal;
        LineText: Text;
    begin
        Request := NewRequest();
        Lines := Request.GetArray('lines');
        Lines.GetObject(0).WriteTo(LineText);
        Line.ReadFrom(LineText);
        Line.Replace('quantity', 1);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('entryNos').Count(), 'Both native lines are captured');
        TotalQuantity := 0;
        foreach Token in Response.GetArray('entryNos') do begin
            Ledger.Get(Token.AsValue().AsInteger());
            Assert.AreEqual(Request.GetText('projectNo'), Ledger."Job No.", 'Every captured entry belongs to owned project');
            TotalQuantity += Ledger.Quantity;
        end;
        Assert.AreEqual(3, TotalQuantity, 'Both native quantities accounted for');
    end;

    /// <summary>A real tracked receipt is consumed through native project posting with no leftover task reservations.</summary>
    [Test]
    procedure TrackedLot_FromOwnedInventory_PreservesTrackingAndQuantity()
    begin
        AssertTrackedInventoryPost(false);
    end;

    /// <summary>One self-received serial unit is consumed exactly once and retains its serial on both ledgers.</summary>
    [Test]
    procedure TrackedSerial_FromOwnedInventory_PreservesTrackingAndQuantity()
    begin
        AssertTrackedInventoryPost(true);
    end;

    local procedure AssertTrackedInventoryPost(Serial: Boolean)
    var
        ItemLedger: Record "Item Ledger Entry";
        ProjectLedger: Record "Job Ledger Entry";
        Reservation: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        TrackingNo: Code[50];
        Quantity: Decimal;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        TrackingNo := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(TrackingNo));
        Quantity := 2;
        if Serial then begin
            Quantity := 1;
            Line.Add('serialNo', TrackingNo);
        end else
            Line.Add('lotNo', TrackingNo);
        Line.Replace('quantity', Quantity);
        SeedTrackedInventory(CopyStr(Line.GetText('itemNo'), 1, 20), Serial, TrackingNo, Quantity);
        ItemLedger.SetRange("Item No.", Line.GetText('itemNo'));
        ItemLedger.CalcSums(Quantity);
        Assert.AreEqual(Quantity, ItemLedger.Quantity, 'Self-created stock was received by native item journal');
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(1, Response.GetArray('entryNos').Count(), 'One native project consumption entry');
        ProjectLedger.Get(Response.GetInteger('firstEntryNo'));
        Assert.AreEqual(Request.GetText('projectNo'), ProjectLedger."Job No.", 'Owned project');
        Assert.AreEqual(Quantity, ProjectLedger.Quantity, 'Exact consumed quantity');
        ItemLedger.SetRange("Entry Type", ItemLedger."Entry Type"::"Negative Adjmt.");
        Assert.AreEqual(1, ItemLedger.Count(), 'One native stock consumption entry');
        ItemLedger.FindFirst();
        Assert.AreEqual(-Quantity, ItemLedger.Quantity, 'Consumption reduces real inventory');
        if Serial then begin
            Assert.AreEqual(TrackingNo, ItemLedger."Serial No.", 'Item ledger serial preserved');
            Assert.AreEqual(TrackingNo, ProjectLedger."Serial No.", 'Project ledger serial preserved');
        end else begin
            Assert.AreEqual(TrackingNo, ItemLedger."Lot No.", 'Item ledger lot preserved');
            Assert.AreEqual(TrackingNo, ProjectLedger."Lot No.", 'Project ledger lot preserved');
        end;
        ItemLedger.SetRange("Entry Type");
        ItemLedger.CalcSums(Quantity, "Remaining Quantity");
        Assert.AreEqual(0, ItemLedger.Quantity, 'Receipt less consumption is zero');
        Assert.AreEqual(0, ItemLedger."Remaining Quantity", 'No owned stock left');
        Reservation.SetRange("Item No.", Line.GetText('itemNo'));
        Assert.IsTrue(Reservation.IsEmpty(), 'Native posting consumed all task tracking reservations');
    end;

    local procedure SeedTrackedInventory(ItemNo: Code[20]; Serial: Boolean; TrackingNo: Code[50]; Quantity: Decimal)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        InventoryGroup: Record "Inventory Posting Group";
        InventorySetup: Record "Inventory Posting Setup";
        GeneralSetup: Record "General Posting Setup";
        Account: Record "G/L Account";
        TempJournal: Record "Item Journal Line" temporary;
        Tracking: Record "Reservation Entry";
        PostItem: Codeunit "Item Jnl.-Post Line";
        CreateEntry: Codeunit "Create Reserv. Entry";
    begin
        Item.Get(ItemNo);
        TrackingCode.Code := CopyStr(ItemNo, 1, MaxStrLen(TrackingCode.Code));
        TrackingCode."SN Specific Tracking" := Serial;
        TrackingCode."Lot Specific Tracking" := not Serial;
        TrackingCode.Insert(true);
        InventoryGroup.Code := ItemNo;
        InventoryGroup.Insert(true);
        Account."No." := ItemNo;
        Account.Name := 'X owned inventory posting account';
        Account."Direct Posting" := true;
        Account.Insert(true);
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
        Item.Validate(Type, Item.Type::Inventory);
        Item.Validate("Inventory Posting Group", InventoryGroup.Code);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        TempJournal."Line No." := 10000;
        TempJournal."Entry Type" := TempJournal."Entry Type"::"Positive Adjmt.";
        TempJournal.Validate("Posting Date", WorkDate());
        TempJournal.Validate("Document No.", ItemNo);
        TempJournal.Validate("Item No.", ItemNo);
        TempJournal.Validate("Gen. Bus. Posting Group", GeneralSetup."Gen. Bus. Posting Group");
        TempJournal.Validate(Quantity, Quantity);
        TempJournal.Validate("Unit Cost", 7);
        if Serial then
            Tracking."Serial No." := TrackingNo
        else
            Tracking."Lot No." := TrackingNo;
        CreateEntry.CreateReservEntryFor(Database::"Item Journal Line", TempJournal."Entry Type".AsInteger(), TempJournal."Journal Template Name", TempJournal."Journal Batch Name", 0, TempJournal."Line No.", TempJournal."Qty. per Unit of Measure", Quantity, TempJournal."Quantity (Base)", Tracking);
        CreateEntry.CreateEntry(ItemNo, '', '', Item.Description, 0D, WorkDate(), 0, "Reservation Status"::Surplus);
        PostItem.RunWithCheck(TempJournal);
    end;

    local procedure NewRequest() Request: JsonObject
    var
        Project: Record Job;
        PlanningLine: Record "Job Planning Line";
        Planning: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
    begin
        Planning := Library.NewPlanningRequest('Item');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Planning), 'Success');
        PlanningLine.Get(Planning.GetText('projectNo'), Planning.GetText('taskNo'), Planning.GetInteger('lineNo'));
        PlanningLine.Validate("Usage Link", true);
        PlanningLine.Modify(true);
        Project.Get(Planning.GetText('projectNo'));
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        Request.Add('projectNo', Planning.GetText('projectNo'));
        Request.Add('taskNo', Planning.GetText('taskNo'));
        Line.Add('itemNo', Planning.GetText('no'));
        Line.Add('quantity', 2);
        Lines.Add(Line);
        Request.Add('lines', Lines);
    end;

    local procedure ValidateRequest(Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        if Usage.Validate(TempArgument, Request) then
            Response.Add('status', 'Success')
        else
            Response := TempArgument.GetResponseJson();
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Usage.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;
}
