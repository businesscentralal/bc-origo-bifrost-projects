namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.Period;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Posting;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Utilities;
using Microsoft.Warehouse.Structure;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Behavior tests for Projects.VisitItem.Register, Projects.VanStock.Get and the additive usage placement keys (projects#84).</summary>
codeunit 97188 "Proj. Van Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryJob: Codeunit "Library - Job";
        OtherOwnerTok: Label 'X84OTHER', Locked = true;

    [Test]
    procedure Scenario_AC01_DescriptionResolves_WritesOpenLine_AndReplays()
    var
        Usage: Record "TS Usage Line ori";
        Response: JsonObject;
        ItemNo: Code[20];
        Token: Text;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        Token := Unique();
        ItemNo := StockedItem(Van, 'Filter ' + Token, 10, false);
        Response := Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson('', Token, 2), 'REQ-' + Token));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(1, Usage.Count(), 'One line written.');
        Usage.FindFirst();
        Assert.AreEqual(ItemNo, Usage."No.", 'Resolved by description.');
        Assert.AreEqual(Van, Usage."Location Code", 'Van location.');
        Assert.AreEqual(Usage.Status::Open, Usage.Status, 'Open.');
        Assert.AreEqual(2, Usage.Quantity, 'Quantity.');
        Response := Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson('', Token, 2), 'REQ-' + Token));
        Assert.AreEqual('Success', TextOf(Response, 'status'), 'Replay.');
        Assert.AreEqual(1, Usage.Count(), 'The same clientRequestId writes nothing new.');
    end;

    [Test]
    procedure Scenario_AC02_Ambiguous_WritesNothing()
    var
        Usage: Record "TS Usage Line ori";
        Response: JsonObject;
        Token: Text;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        Good: Code[20];
        Items: JsonArray;
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        Token := Unique();
        StockedItem(Van, 'Cable ' + Token + ' A', 10, false);
        StockedItem(Van, 'Cable ' + Token + ' B', 10, false);
        Good := StockedItem(Van, 'Plug ' + Unique(), 10, false);
        Items.Add(ItemJson(Good, '', 1));
        Items.Add(ItemJson('', Token, 1));
        Response := Run("Message Type ori"::"Projects.VisitItem.Register", RegisterMany(ProjectNo, TaskNo, Items));
        Assert.AreEqual('Ambiguous', TextOf(Response, 'status'), Dump(Response));
        Assert.AreEqual(1, ArrayOf(Response, 'ambiguous').Count(), 'One ambiguous input.');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(0, Usage.Count(), 'Nothing written for any item.');
    end;

    [Test]
    procedure Scenario_AC03_Transfer_CarriesLocationBinLot()
    var
        JobJournalLine: Record "Job Journal Line";
        Reservation: Record "Reservation Entry";
        Usage: Record "TS Usage Line ori";
        Bin: Record Bin;
        Location: Record Location;
        BinContent: Record "Bin Content";
        Header: Record "Time Sheet Header";
        Response: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
        Entry: JsonObject;
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Lot ' + Unique(), 0, true);
        Location.Get(Van);
        Location."Bin Mandatory" := true;
        Location.Modify();
        LibraryWarehouse.CreateBin(Bin, Van, 'B' + CopyStr(Unique(), 1, 5), '', '');
        BinContent.Init();
        BinContent."Location Code" := Van;
        BinContent."Bin Code" := Bin.Code;
        BinContent."Item No." := ItemNo;
        BinContent."Unit of Measure Code" := BaseUnit(ItemNo);
        BinContent.Insert();
        Entry := ItemJson(ItemNo, '', 3);
        Entry.Add('binCode', Bin.Code);
        Entry.Add('lotNo', 'LOT84');
        Response := Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, Entry, ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.SetRange("Time Sheet No.", SheetNo);
        Usage.FindFirst();
        Assert.AreEqual('LOT84', Usage."Lot No.", 'Lot stored.');
        Header.Get(SheetNo);
        Header."Owner User ID" := 'X84OWNER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Modify();
        Usage.Status := Usage.Status::Approved;
        Usage.Modify();
        Response := Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.Get(Usage."Entry No.");
        Assert.AreEqual(Usage.Status::Transferred, Usage.Status, 'Transferred.');
        JobJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        Assert.AreEqual(Van, JobJournalLine."Location Code", 'Journal line carries the van.');
        Assert.AreEqual(Bin.Code, JobJournalLine."Bin Code", 'Journal line carries the bin.');
        Reservation.SetRange("Source Type", Database::"Job Journal Line");
        Reservation.SetRange("Source ID", JobJournalLine."Journal Template Name");
        Reservation.SetRange("Source Ref. No.", JobJournalLine."Line No.");
        Assert.AreEqual(1, Reservation.Count(), 'One tracking entry.');
        Reservation.FindFirst();
        Assert.AreEqual('LOT84', Reservation."Lot No.", 'Journal line carries the lot.');
    end;

    [Test]
    procedure Scenario_AC03_PostingJournal_MarksPosted_LowersVanStock()
    var
        JobJournalLine: Record "Job Journal Line";
        Usage: Record "TS Usage Line ori";
        Header: Record "Time Sheet Header";
        JobPost: Codeunit "Job Jnl.-Post Line";
        Response: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
        Before: Decimal;
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Post ' + Unique(), 10, false);
        Response := Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 4), ''));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Before := Inventory(ItemNo, Van);
        Usage.SetRange("Time Sheet No.", SheetNo);
        Usage.FindFirst();
        Header.Get(SheetNo);
        Header."Owner User ID" := 'X84OWNER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Modify();
        Usage.Status := Usage.Status::Approved;
        Usage.Modify();
        Response := Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.Get(Usage."Entry No.");
        JobJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        JobPost.RunWithCheck(JobJournalLine);
        Usage.Get(Usage."Entry No.");
        Assert.AreEqual(Usage.Status::Posted, Usage.Status, 'Posted.');
        Assert.AreEqual(Before - 4, Inventory(ItemNo, Van), 'Van stock is lower.');
    end;

    [Test]
    procedure Scenario_AC04_VanStock_SubtractsPending_FlagsBelowMinimum()
    var
        Sku: Record "Stockkeeping Unit";
        Response: JsonObject;
        Node: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
        Request: JsonObject;
        Items: JsonArray;
        Token: JsonToken;
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Stock ' + Unique(), 10, false);
        Sku.Init();
        Sku."Location Code" := Van;
        Sku."Item No." := ItemNo;
        Sku."Reorder Point" := 8;
        Sku.Insert();
        Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 3), ''));
        Request.Add('itemFilter', ItemNo);
        Response := Run("Message Type ori"::"Projects.VanStock.Get", Request);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Items := ArrayOf(Response, 'items');
        Assert.AreEqual(1, Items.Count(), 'One item.');
        Items.Get(0, Token);
        Node := Token.AsObject();
        Assert.AreEqual(10, DecimalOf(Node, 'inventory'), 'Inventory.');
        Assert.AreEqual(3, DecimalOf(Node, 'pendingUsage'), 'Pending.');
        Assert.AreEqual(7, DecimalOf(Node, 'available'), 'Available after pending usage.');
        Assert.AreEqual('true', TextOf(Node, 'belowMinimum'), 'Below the reorder point.');
        Clear(Request);
        Request.Add('belowMinimumOnly', true);
        Response := Run("Message Type ori"::"Projects.VanStock.Get", Request);
        Assert.IsTrue(ArrayOf(Response, 'items').Count() >= 1, 'Below minimum list.');
    end;

    [Test]
    procedure Scenario_AC05_UsageRegister_Parity_AndPlacementKeys()
    var
        Usage: Record "TS Usage Line ori";
        Line: Record "Time Sheet Line";
        Response: JsonObject;
        Request: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
        Lines: JsonArray;
        Token: JsonToken;
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Parity ' + Unique(), 10, false);
        Line.Init();
        Line."Time Sheet No." := SheetNo;
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := WorkDate();
        Line.Insert(false);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNo', 10000);
        Request.Add('type', 'Item');
        Request.Add('no', ItemNo);
        Request.Add('date', Format(Today(), 0, 9));
        Request.Add('quantity', 1);
        Response := Run("Message Type ori"::"Projects.Usage.Register", Request);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Lines := ArrayOf(Response, 'lines');
        Lines.Get(0, Token);
        Assert.IsFalse(Token.AsObject().Contains('locationCode'), 'No new keys without placement.');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Usage.FindFirst();
        Assert.AreEqual('', Usage."Location Code", 'Blank location.');
        Request.Add('locationCode', Van);
        Response := Run("Message Type ori"::"Projects.Usage.Register", Request);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Usage.SetRange("Location Code", Van);
        Assert.AreEqual(1, Usage.Count(), 'The new key is stored.');
    end;

    [Test]
    procedure Scenario_AC06_Refusals_ChangeNothing()
    var
        Usage: Record "TS Usage Line ori";
        Item: Record Item;
        Reference: Record "Item Reference";
        Setup: Record "Proj. Technician Setup ori";
        Request: JsonObject;
        Entry: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
        OtherNo: Code[20];
        TrackedNo: Code[20];
        BlockedNo: Code[20];
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Ref ' + Unique(), 10, false);
        OtherNo := StockedItem(Van, 'Other ' + Unique(), 10, false);
        TrackedNo := StockedItem(Van, 'Tracked ' + Unique(), 0, true);
        BlockedNo := StockedItem(Van, 'Blocked ' + Unique(), 10, false);
        Item.Get(BlockedNo);
        Item.Blocked := true;
        Item.Modify();
        Reference.Init();
        Reference."Item No." := OtherNo;
        Reference."Reference Type" := Reference."Reference Type"::"Bar Code";
        Reference."Reference No." := 'R84' + CopyStr(Unique(), 1, 8);
        Reference.Insert();
        // MissingParameter
        Request.Add('projectNo', ProjectNo);
        Request.Add('taskNo', TaskNo);
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Request), 'MissingParameter', 'items', 'key');
        // UnknownParameter
        Request := Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 1), '');
        Request.Add('bogus', 1);
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Request), 'UnknownParameter', 'bogus', 'unknown');
        // InvalidParameterFormat: quantity <= 0 and serial quantity > 1
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 0), '')), 'InvalidParameterFormat', 'quantity', 'documented');
        Entry := ItemJson(ItemNo, '', 2);
        Entry.Add('serialNo', 'SN1');
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, Entry, '')), 'InvalidParameterFormat', 'quantity', 'serial');
        // RecordNotFound: item, task, bin
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson('NOSUCH84', '', 1), '')), 'RecordNotFound', 'itemNo', 'exists');
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, 'NOTASK', ItemJson(ItemNo, '', 1), '')), 'RecordNotFound', 'taskNo', 'exists');
        Entry := ItemJson(ItemNo, '', 1);
        Entry.Add('binCode', 'NOBIN84');
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, Entry, '')), 'RecordNotFound', 'binCode', 'exists');
        // ConflictingIdentifiers
        Entry := ItemJson(ItemNo, '', 1);
        Entry.Add('reference', Reference."Reference No.");
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, Entry, '')), 'ConflictingIdentifiers', 'reference', 'same item');
        // PreconditionFailed: blocked, tracked without lot
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(BlockedNo, '', 1), '')), 'PreconditionFailed', 'itemNo', 'blocked');
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(TrackedNo, '', 1), '')), 'PreconditionFailed', 'lotNo', 'lotNo');
        // PreconditionFailed: Submitted sheet line, then no van location
        SubmitTaskLine(SheetNo, ProjectNo, TaskNo);
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 1), '')), 'PreconditionFailed', 'taskNo', 'open');
        Setup.SetRange("Van Location Code", Van);
        Setup.DeleteAll();
        AssertRefusal(Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 1), '')), 'PreconditionFailed', '', 'van location');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(0, Usage.Count(), 'Refusals write nothing.');
    end;

    [Test]
    procedure Scenario_AC09_GenericPlacementWrite_Refused()
    var
        Usage: Record "TS Usage Line ori";
        Fields: JsonObject;
        Response: JsonObject;
        Van: Code[10];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        ItemNo: Code[20];
    begin
        Prepare(Van, SheetNo, ProjectNo, TaskNo);
        ItemNo := StockedItem(Van, 'Generic ' + Unique(), 10, false);
        Run("Message Type ori"::"Projects.VisitItem.Register", Register(ProjectNo, TaskNo, ItemJson(ItemNo, '', 1), ''));
        Usage.SetRange("Time Sheet No.", SheetNo);
        Usage.FindFirst();
        Fields.Add('Lot No.', 'HACK');
        Response := GenericWrite(Usage."Entry No.", Fields);
        Assert.AreEqual('Error', TextOf(Response, 'status'), Dump(Response));
        Usage.Get(Usage."Entry No.");
        Assert.AreEqual('', Usage."Lot No.", 'Lot unchanged.');
    end;

    [Test]
    procedure Scenario_AC10_Help_EnglishChapters_TranslatedDiscovery()
    begin
        AssertHelp("Message Type ori"::"Projects.VisitItem.Register");
        AssertHelp("Message Type ori"::"Projects.VanStock.Get");
    end;

    local procedure Unique(): Text
    begin
        exit('Z' + CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 10));
    end;

    local procedure Prepare(var Van: Code[10]; var SheetNo: Code[20]; var ProjectNo: Code[20]; var TaskNo: Code[20])
    var
        Job: Record Job;
        JobTask: Record "Job Task";
        Location: Record Location;
        Setup: Record "Proj. Technician Setup ori";
        ResourceNo: Code[20];
    begin
        Isolate();
        OpenAccountingPeriod(Today());
        ResourceNo := CreateResource(UserId());
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        Van := Location.Code;
        Setup.Init();
        Setup."Resource No." := ResourceNo;
        Setup."Van Location Code" := Van;
        Setup.Insert();
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        ProjectNo := Job."No.";
        TaskNo := JobTask."Job Task No.";
        SheetNo := InsertSheet(ResourceNo, Today());
    end;

    local procedure StockedItem(Van: Code[10]; Description: Text; Quantity: Decimal; Tracked: Boolean): Code[20]
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Description := CopyStr(Description, 1, MaxStrLen(Item.Description));
        if Tracked then begin
            TrackingCode.Init();
            TrackingCode.Code := CopyStr('T84' + CopyStr(Unique(), 1, 6), 1, MaxStrLen(TrackingCode.Code));
            TrackingCode."Lot Specific Tracking" := true;
            TrackingCode.Insert();
            Item."Item Tracking Code" := TrackingCode.Code;
        end;
        Item.Modify();
        if Quantity > 0 then begin
            LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
            LibraryInventory.CreateItemJournalBatch(ItemJournalBatch, ItemJournalTemplate.Name);
            LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, ItemJournalLine."Entry Type"::"Positive Adjmt.", Item."No.", Quantity);
            ItemJournalLine.Validate("Location Code", Van);
            ItemJournalLine.Modify(true);
            LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
        end;
        exit(Item."No.");
    end;

    local procedure BaseUnit(ItemNo: Code[20]): Code[10]
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        exit(Item."Base Unit of Measure");
    end;

    local procedure Inventory(ItemNo: Code[20]; Van: Code[10]): Decimal
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        Item.SetRange("Location Filter", Van);
        Item.CalcFields(Inventory);
        exit(Item.Inventory);
    end;

    local procedure ItemJson(ItemNo: Code[20]; Description: Text; Quantity: Decimal) Entry: JsonObject
    begin
        if ItemNo <> '' then
            Entry.Add('itemNo', ItemNo);
        if Description <> '' then
            Entry.Add('description', Description);
        Entry.Add('quantity', Quantity);
    end;

    local procedure Register(ProjectNo: Code[20]; TaskNo: Code[20]; Entry: JsonObject; RequestId: Text) Request: JsonObject
    var
        Items: JsonArray;
    begin
        Items.Add(Entry);
        Request := RegisterMany(ProjectNo, TaskNo, Items);
        if RequestId <> '' then
            Request.Add('clientRequestId', RequestId);
    end;

    local procedure RegisterMany(ProjectNo: Code[20]; TaskNo: Code[20]; Items: JsonArray) Request: JsonObject
    begin
        Request.Add('projectNo', ProjectNo);
        Request.Add('taskNo', TaskNo);
        Request.Add('items', Items);
    end;

    local procedure ArrayOf(Response: JsonObject; Name: Text) Result: JsonArray
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            Result := Token.AsArray();
    end;

    local procedure SubmitTaskLine(SheetNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20])
    var
        Line: Record "Time Sheet Line";
    begin
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange("Job No.", ProjectNo);
        Line.SetRange("Job Task No.", TaskNo);
        if not Line.FindFirst() then begin
            Line.Init();
            Line."Time Sheet No." := SheetNo;
            Line."Line No." := 90000;
            Line."Time Sheet Starting Date" := Today();
            Line.Type := Line.Type::Job;
            Line."Job No." := ProjectNo;
            Line."Job Task No." := TaskNo;
            Line.Insert(false);
        end;
        Line.Status := Line.Status::Submitted;
        Line.Modify(false);
    end;

    local procedure TransferRequest(SheetNo: Code[20]) Request: JsonObject
    var
        ItemTemplate: Record "Item Journal Template";
        ItemBatch: Record "Item Journal Batch";
        ResTemplate: Record "Res. Journal Template";
        ResBatch: Record "Res. Journal Batch";
        JobTemplate: Record "Job Journal Template";
        JobBatch: Record "Job Journal Batch";
    begin
        LibraryInventory.CreateItemJournalTemplate(ItemTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemBatch, ItemTemplate.Name);
        ResTemplate.Init();
        ResTemplate.Name := CopyStr('TV' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 10);
        ResTemplate.Insert();
        ResBatch.Init();
        ResBatch."Journal Template Name" := ResTemplate.Name;
        ResBatch.Name := 'B1';
        ResBatch.Insert();
        LibraryJob.CreateJobJournalTemplate(JobTemplate);
        LibraryJob.CreateJobJournalBatch(JobTemplate.Name, JobBatch);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('itemTemplate', ItemTemplate.Name);
        Request.Add('itemBatch', ItemBatch.Name);
        Request.Add('resourceTemplate', ResTemplate.Name);
        Request.Add('resourceBatch', ResBatch.Name);
        Request.Add('jobTemplate', JobTemplate.Name);
        Request.Add('jobBatch', JobBatch.Name);
    end;

    local procedure Today(): Date
    begin
        exit(DT2Date(CurrentDateTime()));
    end;

    local procedure AssertHelp(MessageType: Enum "Message Type ori")
    var
        Api: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        English: Text;
        Icelandic: Text;
        EnglishKeywords: Text;
        IcelandicKeywords: Text;
        Overview: Text;
        IcelandicOverview: Text;
        Notes: Text;
        Previous: Integer;
    begin
        Api := MessageType;
        Contract := MessageType;
        Discovery := MessageType;
        Previous := GlobalLanguage();
        GlobalLanguage(1033);
        English := Api.GetDescription();
        EnglishKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(Overview), 'Overview.');
        Assert.IsTrue(Contract.GetNotes(Notes), 'Notes.');
        Assert.IsFalse(English.Contains('message type'), 'No message type wording.');
        Assert.IsFalse(Overview.Contains('codeunit'), 'No AL object name.');
        GlobalLanguage(1039);
        Icelandic := Api.GetDescription();
        IcelandicKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(IcelandicOverview), 'Icelandic overview.');
        Assert.AreNotEqual(English, Icelandic, 'Discovery is translated.');
        Assert.AreEqual(EnglishKeywords.Split(',').Count(), IcelandicKeywords.Split(',').Count(), 'Keyword counts match.');
        Assert.AreEqual(Overview, IcelandicOverview, 'Chapters stay English.');
        GlobalLanguage(Previous);
    end;

    local procedure Run(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        MsgInterface: Interface "Msg Interface ori";
        UsageMgt: Codeunit "TS Usage Mgt ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        MsgInterface := TempArgument.GetMessageTypeInterface();
        Commit();
        // Usage messages are called through the manager: the licence check sits in ExecuteBifrostTask (NOT_RUN per PR).
        if MessageType = "Message Type ori"::"Projects.Usage.Register" then
            UsageMgt.Execute(TempArgument, 1)
        else
            if MessageType = "Message Type ori"::"Projects.Usage.Transfer" then
                UsageMgt.Execute(TempArgument, 5)
            else
                MsgInterface.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; ExpectedNextPart: Text)
    begin
        Assert.AreEqual('Error', TextOf(Response, 'status'), 'Refused.');
        Assert.AreEqual(ExpectedCode, TextOf(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(ExpectedParameter, TextOf(Response, 'parameter'), 'Refusal parameter.');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains(ExpectedNextPart), TextOf(Response, 'nextStep'));
    end;

    local procedure GenericWrite(EntryNo: Integer; Fields: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        PrimaryKey: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        Request: JsonObject;
        ContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        PrimaryKey.Add('EntryNo_', EntryNo);
        Row.Add('primaryKey', PrimaryKey);
        Row.Add('fields', Fields);
        Rows.Add(Row);
        Request.Add('tableId', Database::"TS Usage Line ori");
        Request.Add('data', Rows);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'XVISIT83', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure Dump(Response: JsonObject) Result: Text
    begin
        Response.WriteTo(Result);
        Result := CopyStr(Result, 1, 240);
    end;

    local procedure TextOf(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure DecimalOf(Response: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
        Value: Decimal;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                Evaluate(Value, Token.AsValue().AsText(), 9);
        exit(Value);
    end;

    local procedure NumberOf(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if Response.Get(Name, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
    end;

    local procedure Child(Response: JsonObject; Name: Text) Node: JsonObject
    var
        Token: JsonToken;
    begin
        Response.Get(Name, Token);
        Node := Token.AsObject();
    end;

    local procedure Isolate()
    var
        Resource: Record Resource;
    begin
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", OtherOwnerTok, false);
    end;

    local procedure CreateResource(Owner: Text): Code[20]
    var
        Resource: Record Resource;
        UnitOfMeasure: Record "Unit of Measure";
        LibraryResource: Codeunit "Library - Resource";
    begin
        LibraryResource.CreateResourceNew(Resource);
        if Resource."Base Unit of Measure" = '' then begin
            if not UnitOfMeasure.Get('HOUR') then begin
                UnitOfMeasure.Init();
                UnitOfMeasure.Code := 'HOUR';
                UnitOfMeasure.Description := 'Hour';
                UnitOfMeasure.Insert(true);
            end;
            Resource.Validate("Base Unit of Measure", UnitOfMeasure.Code);
        end;
        Resource.Validate("Use Time Sheet", true);
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(Owner), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Modify(true);
        exit(Resource."No.");
    end;

    local procedure OpenAccountingPeriod(Day: Date)
    var
        AccountingPeriod: Record "Accounting Period";
    begin
        // CRONUS Ísland keeps the current month closed. Hour lines refuse a closed period.
        AccountingPeriod.SetFilter("Starting Date", '..%1', Day);
        if not AccountingPeriod.FindLast() then
            exit;
        if not AccountingPeriod.Closed then
            exit;
        AccountingPeriod.Closed := false;
        AccountingPeriod.Modify();
    end;

    local procedure InsertSheet(ResourceNo: Code[20]; Day: Date): Code[20]
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := CopyStr('X84' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := ResourceNo;
        Header."Starting Date" := Day;
        Header."Ending Date" := Day + 6;
        Header."Owner User ID" := CopyStr(UpperCase(UserId()), 1, MaxStrLen(Header."Owner User ID"));
        Header.Insert(false);
        exit(Header."No.");
    end;
}
