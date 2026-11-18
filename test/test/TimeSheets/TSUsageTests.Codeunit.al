namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Behavior tests for the Projects.Usage.* message types (projects#52).</summary>
codeunit 97153 "TS Usage Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryJob: Codeunit "Library - Job";
        LibraryResource: Codeunit "Library - Resource";

    [Test]
    procedure Register_Item_CreatesOpenLine()
    var
        Item: Record Item;
        Usage: Record "TS Usage Line ori";
        Response: JsonObject;
        SheetNo: Code[20];
        ItemNo: Code[20];
    begin
        // [SCENARIO] AC01: the owner registers an item on an own sheet line.
        SheetNo := NewSheet(true);
        ItemNo := NewItem();
        Response := Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Item', ItemNo, 3));
        Assert.AreEqual('Success', Text(Response, 'status'), 'Register succeeds.');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Assert.AreEqual(1, Usage.Count(), 'One usage line.');
        Usage.FindFirst();
        Assert.AreEqual(Usage.Status::Open, Usage.Status, 'Starts Open.');
        Assert.AreEqual(3, Usage.Quantity, 'Quantity.');
        Assert.AreEqual(ItemNo, Usage."No.", 'Item number.');
        Item.Get(ItemNo);
        Assert.AreEqual(Item."Base Unit of Measure", Usage."Unit of Measure Code", 'Defaults to the item base unit.');
    end;

    [Test]
    procedure Register_Resource_CreatesOpenLine()
    var
        Usage: Record "TS Usage Line ori";
        Response: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        Response := Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Resource', NewResource(), 120));
        Assert.AreEqual('Success', Text(Response, 'status'), 'Register succeeds.');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Usage.FindFirst();
        Assert.AreEqual(Usage.Type::Resource, Usage.Type, 'Resource type.');
    end;

    [Test]
    procedure Register_MissingLineNo_Refused()
    var
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        Request := RegisterRequest(SheetNo, 10000, 'Item', NewItem(), 1);
        Request.Remove('lineNo');
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", Request), 'MissingParameter', 'lineNo');
    end;

    [Test]
    procedure Register_ForeignSheet_Refused()
    var
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(false);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Item', NewItem(), 1)), 'PermissionDenied', 'timeSheetNo');
    end;

    [Test]
    procedure Register_UnknownLine_Refused()
    var
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 99000, 'Item', NewItem(), 1)), 'RecordNotFound', 'lineNo');
    end;

    [Test]
    procedure Register_ZeroQuantity_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Item', NewItem(), 0)), 'InvalidParameterFormat', 'quantity');
        Usage.SetRange("Time Sheet No.", SheetNo);
        Assert.IsTrue(Usage.IsEmpty(), 'Nothing registered.');
    end;

    [Test]
    procedure Register_UnknownItem_Refused()
    var
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Item', 'NOSUCHITEM-X', 1)), 'RecordNotFound', 'no');
    end;

    [Test]
    procedure Register_BlockedItem_Refused()
    var
        Item: Record Item;
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        Item.Get(NewItem());
        Item.Blocked := true;
        Item.Modify();
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", RegisterRequest(SheetNo, 10000, 'Item', Item."No.", 1)), 'PreconditionFailed', 'no');
    end;

    [Test]
    procedure Register_DateOutsideWeek_Refused()
    var
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        Request := RegisterRequest(SheetNo, 10000, 'Item', NewItem(), 1);
        Request.Replace('date', Format(WorkDate() + 30, 0, 9));
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", Request), 'InvalidParameterFormat', 'date');
    end;

    [Test]
    procedure Register_UnknownKey_Refused()
    var
        Request: JsonObject;
        SheetNo: Code[20];
    begin
        SheetNo := NewSheet(true);
        Request := RegisterRequest(SheetNo, 10000, 'Item', NewItem(), 1);
        Request.Add('surprise', 1);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Register", Request), 'UnknownParameter', 'surprise');
    end;

    [Test]
    procedure Submit_OpenAndRejected_Submitted_ApprovedRefused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Entries: JsonArray;
        Request: JsonObject;
    begin
        // [SCENARIO] AC03: only Open or Rejected lines can be submitted.
        SheetNo := NewSheet(true);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Open);
        Request.Add('timeSheetNo', SheetNo);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Submit", Request), 'status'), 'Submit succeeds.');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Submitted, Usage.Status, 'Submitted.');
        Entries.Add(EntryNo);
        Request.Add('entryNos', Entries);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Submit", Request), 'PreconditionFailed', 'entryNos');
    end;

    [Test]
    procedure Approve_ByApprover_Approved()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Request: JsonObject;
    begin
        // [SCENARIO] AC04: the sheet approver approves a Submitted line.
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Request.Add('timeSheetNo', SheetNo);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Approve", Request), 'status'), 'Approve succeeds.');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Approved.');
        Assert.AreNotEqual('', Usage."Approved By", 'Approver stored.');
    end;

    [Test]
    procedure Approve_ByOwner_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Request: JsonObject;
    begin
        SheetNo := NewSheet(true);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Request.Add('timeSheetNo', SheetNo);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Approve", Request), 'PermissionDenied', 'timeSheetNo');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Submitted, Usage.Status, 'Unchanged.');
    end;

    [Test]
    procedure Approve_OpenLine_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        Entries: JsonArray;
        Request: JsonObject;
    begin
        SheetNo := NewSheet(false);
        Entries.Add(NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Open));
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('entryNos', Entries);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Approve", Request), 'PreconditionFailed', 'entryNos');
    end;

    [Test]
    procedure Reject_WithComment_Rejected()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Request: JsonObject;
    begin
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('comment', 'Wrong quantity');
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Reject", Request), 'status'), 'Reject succeeds.');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Rejected, Usage.Status, 'Rejected.');
        Assert.AreEqual('Wrong quantity', Usage."Reject Comment", 'Comment stored.');
    end;

    [Test]
    procedure Reject_TooLongComment_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        Request: JsonObject;
    begin
        SheetNo := NewSheet(false);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('comment', PadStr('', 251, 'x'));
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Reject", Request), 'InvalidParameterFormat', 'comment');
    end;

    [Test]
    procedure Transfer_Item_CreatesItemJournalLine_RepeatCreatesNothing()
    var
        ItemJournalLine: Record "Item Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Request: JsonObject;
    begin
        // [SCENARIO] AC05: an Approved item line becomes an item journal line, once.
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        Request := TransferRequest(SheetNo);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Transfer", Request), 'status'), 'Transfer succeeds.');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Transferred, Usage.Status, 'Transferred.');
        ItemJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        Assert.AreEqual(Usage."No.", ItemJournalLine."Item No.", 'Journal item.');
        Assert.AreEqual(Usage.Quantity, ItemJournalLine.Quantity, 'Journal quantity.');
        ItemJournalLine.SetRange("Journal Template Name", Usage."Journal Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", Usage."Journal Batch Name");
        ItemJournalLine.SetRange("Document No.", Usage."Document No.");
        Assert.AreEqual(1, ItemJournalLine.Count(), 'One journal line.');
        Run("Message Type ori"::"Projects.Usage.Transfer", Request);
        Assert.AreEqual(1, ItemJournalLine.Count(), 'The repeat creates nothing.');
    end;

    [Test]
    procedure Transfer_Resource_CreatesResourceJournalLine()
    var
        ResJournalLine: Record "Res. Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
    begin
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Resource', NewResource(), Usage.Status::Approved);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo)), 'status'), 'Transfer succeeds.');
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Transferred, Usage.Status, 'Transferred.');
        ResJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        Assert.AreEqual(Usage."No.", ResJournalLine."Resource No.", 'Journal resource.');
    end;

    [Test]
    procedure Transfer_LineWithJob_CreatesJobJournalLine()
    var
        Job: Record Job;
        JobTask: Record "Job Task";
        JobJournalLine: Record "Job Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
    begin
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        SheetNo := NewSheet(false);
        SetLineJob(SheetNo, Job."No.", JobTask."Job Task No.");
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo)), 'status'), 'Transfer succeeds.');
        Usage.Get(EntryNo);
        JobJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        Assert.AreEqual(Job."No.", JobJournalLine."Job No.", 'Job journal job.');
    end;

    [Test]
    procedure Transfer_MissingTemplateKey_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        Request: JsonObject;
    begin
        SheetNo := NewSheet(false);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        Request.Add('timeSheetNo', SheetNo);
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Transfer", Request), 'MissingParameter', 'itemTemplate');
    end;

    [Test]
    procedure Transfer_OneInvalidLine_RollsEverythingBack()
    var
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        FirstNo: Integer;
        SecondNo: Integer;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] AC06: a failing line leaves no journal line and no state change.
        SheetNo := NewSheet(false);
        FirstNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        Item.Get(NewItem());
        SecondNo := NewUsage(SheetNo, 'Item', Item."No.", Usage.Status::Approved);
        Item.Blocked := true;
        Item.Modify();
        Request := TransferRequest(SheetNo);
        Response := Run("Message Type ori"::"Projects.Usage.Transfer", Request);
        Assert.AreEqual('Error', Text(Response, 'status'), 'The transfer is refused.');
        Usage.Get(FirstNo);
        Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'First line unchanged.');
        Usage.Get(SecondNo);
        Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Second line unchanged.');
        ItemJournalLine.SetRange("Document No.", Usage."Document No.");
        ItemJournalLine.SetFilter("Document No.", 'TSU*');
        ItemJournalLine.SetRange("Item No.", Usage."No.");
        Assert.IsTrue(ItemJournalLine.IsEmpty(), 'No journal line remains.');
    end;

    [Test]
    procedure LedgerEntry_MarksPosted_JournalDelete_ReturnsToApproved()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJournalLine: Record "Item Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        PostedNo: Integer;
        DeletedNo: Integer;
    begin
        // [SCENARIO] AC07: a ledger entry marks Posted; deleting the journal line returns to Approved.
        SheetNo := NewSheet(false);
        PostedNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        DeletedNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved);
        Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo));
        Usage.Get(PostedNo);
        ItemLedgerEntry.Init();
        ItemLedgerEntry."Entry No." := LastItemLedgerEntryNo() + 1;
        ItemLedgerEntry."Document No." := Usage."Document No.";
        ItemLedgerEntry.Insert(true);
        Usage.Get(PostedNo);
        Assert.AreEqual(Usage.Status::Posted, Usage.Status, 'Posted.');
        Assert.AreEqual(ItemLedgerEntry."Entry No.", Usage."Ledger Entry No.", 'Ledger entry stored.');
        ItemLedgerEntry.Delete();
        Usage.Get(DeletedNo);
        ItemJournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
        ItemJournalLine.Delete(true);
        Usage.Get(DeletedNo);
        Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Back to Approved.');
        Assert.AreEqual(0, Usage."Journal Line No.", 'Journal link cleared.');
    end;

    [Test]
    procedure Transfer_ThenPostJournal_MarksUsagePosted()
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        ItemNo: Code[20];
        EntryNo: Integer;
    begin
        // [SCENARIO] AC07 with the real posting routine: posting the journal marks the usage Posted.
        ItemNo := NewItem();
        LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJournalBatch, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, ItemJournalLine."Entry Type"::"Positive Adjmt.", ItemNo, 10);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Item', ItemNo, Usage.Status::Approved);
        Run("Message Type ori"::"Projects.Usage.Transfer", TransferRequest(SheetNo));
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Transferred, Usage.Status, 'Transferred.');
        LibraryInventory.PostItemJournalLine(Usage."Journal Template Name", Usage."Journal Batch Name");
        Usage.Get(EntryNo);
        Assert.AreEqual(Usage.Status::Posted, Usage.Status, 'Posting the journal marks the usage Posted.');
        Assert.AreNotEqual(0, Usage."Ledger Entry No.", 'The ledger entry is stored.');
    end;

    [Test]
    procedure Reverse_PostedLine_FlagsAndCreatesReversingLine_SecondRefused()
    var
        ItemJournalLine: Record "Item Journal Line";
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        EntryNo: Integer;
        Request: JsonObject;
    begin
        // [SCENARIO] AC08: Reverse flags once and creates a negative journal line.
        SheetNo := NewSheet(false);
        EntryNo := NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Posted);
        Request := TransferRequest(SheetNo);
        Request.Remove('timeSheetNo');
        Request.Add('entryNo', EntryNo);
        Request.Add('createJournalLine', true);
        Assert.AreEqual('Success', Text(Run("Message Type ori"::"Projects.Usage.Reverse", Request), 'status'), 'Reverse succeeds.');
        Usage.Get(EntryNo);
        Assert.IsTrue(Usage.Reversed, 'Flagged reversed.');
        ItemJournalLine.SetFilter("Document No.", 'TSR*');
        ItemJournalLine.SetRange("Item No.", Usage."No.");
        ItemJournalLine.FindFirst();
        Assert.AreEqual(-Usage.Quantity, ItemJournalLine.Quantity, 'Negative quantity.');
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Reverse", Request), 'PreconditionFailed', 'entryNo');
    end;

    [Test]
    procedure Reverse_NotPosted_Refused()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        Request: JsonObject;
    begin
        SheetNo := NewSheet(false);
        Request.Add('entryNo', NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Approved));
        AssertRefusal(Run("Message Type ori"::"Projects.Usage.Reverse", Request), 'PreconditionFailed', 'entryNo');
    end;

    [Test]
    procedure List_OwnLines_ApproverPending_Paged()
    var
        Usage: Record "TS Usage Line ori";
        SheetNo: Code[20];
        Response: JsonObject;
        Request: JsonObject;
        Lines: JsonToken;
    begin
        // [SCENARIO] AC10: List is read-only and paged.
        SheetNo := NewSheet(true);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Open);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Request.Add('timeSheetNo', SheetNo);
        Response := Run("Message Type ori"::"Projects.Usage.List", Request);
        Response.Get('lines', Lines);
        Assert.AreEqual(2, Lines.AsArray().Count(), 'Owner sees both lines.');
        Request.Add('take', 1);
        Response := Run("Message Type ori"::"Projects.Usage.List", Request);
        Response.Get('lines', Lines);
        Assert.AreEqual(1, Lines.AsArray().Count(), 'Paged to one.');
        Assert.AreEqual('true', Text(Response, 'hasMore'), 'More pages.');
        SheetNo := NewSheet(false);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Open);
        NewUsage(SheetNo, 'Item', NewItem(), Usage.Status::Submitted);
        Clear(Request);
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('pending', true);
        Response := Run("Message Type ori"::"Projects.Usage.List", Request);
        Response.Get('lines', Lines);
        Assert.AreEqual(1, Lines.AsArray().Count(), 'Approver sees the submitted line only.');
    end;

    [Test]
    procedure GenericWrite_OfStatusAndJournalFields_Restricted()
    var
        Usage: Record "TS Usage Line ori";
    begin
        // [SCENARIO] AC09: generic writes of managed fields are refused.
        Assert.IsTrue(IsFieldRestricted(Usage.FieldNo(Status), 'writeRestricted'), 'Status.');
        Assert.IsTrue(IsFieldRestricted(Usage.FieldNo(Reversed), 'writeRestricted'), 'Reversed.');
        Assert.IsTrue(IsFieldRestricted(Usage.FieldNo("Journal Line No."), 'writeRestricted'), 'Journal line.');
        Assert.IsFalse(IsFieldRestricted(Usage.FieldNo(Description), 'writeRestricted'), 'Description is free.');
    end;

    [Test]
    procedure Captions_1033_1039_AreTranslated()
    var
        Usage: Record "TS Usage Line ori";
        English: Text;
        Icelandic: Text;
        Previous: Integer;
    begin
        // [SCENARIO] The page and table captions exist in English and Icelandic.
        Previous := GlobalLanguage();
        GlobalLanguage(1033);
        English := Usage.TableCaption() + '|' + Usage.FieldCaption(Status) + '|' + Format(Usage.Status::Approved);
        GlobalLanguage(1039);
        Icelandic := Usage.TableCaption() + '|' + Usage.FieldCaption(Status) + '|' + Format(Usage.Status::Approved);
        GlobalLanguage(Previous);
        Assert.AreEqual('Time Sheet Usage Line|Status|Approved', English, 'English captions.');
        Assert.AreEqual('Notkunarlína tímaskýrslu|Staða|Samþykkt', Icelandic, 'Icelandic captions.');
    end;

    [Test]
    procedure Discovery_1033_1039_AllTypesDescribed()
    begin
        // [SCENARIO] AC12: every usage type has a description in English and Icelandic.
        AssertDescribed("Message Type ori"::"Projects.Usage.Register");
        AssertDescribed("Message Type ori"::"Projects.Usage.Submit");
        AssertDescribed("Message Type ori"::"Projects.Usage.Approve");
        AssertDescribed("Message Type ori"::"Projects.Usage.Reject");
        AssertDescribed("Message Type ori"::"Projects.Usage.Transfer");
        AssertDescribed("Message Type ori"::"Projects.Usage.Reverse");
        AssertDescribed("Message Type ori"::"Projects.Usage.List");
    end;

    local procedure AssertDescribed(MessageType: Enum "Message Type ori")
    var
        Discovery: Interface "Msg Interface ori";
        English: Text;
        Icelandic: Text;
        Previous: Integer;
    begin
        Discovery := MessageType;
        Previous := GlobalLanguage();
        GlobalLanguage(1033);
        English := Discovery.GetDescription();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetDescription();
        GlobalLanguage(Previous);
        Assert.AreNotEqual('', English, 'English description.');
        Assert.AreNotEqual('', Icelandic, 'Icelandic description.');
        Assert.AreNotEqual(English, Icelandic, 'The Icelandic description is translated.');
    end;

    local procedure IsFieldRestricted(FieldNumber: Integer; RestrictionName: Text): Boolean
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageImplementation: Interface "Msg Interface ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FieldJson: JsonObject;
        FieldNumbers: JsonArray;
        Fields: JsonArray;
        Token: JsonToken;
    begin
        TempArgument.Init();
        TempArgument."Type" := TempArgument."Type"::"Help.Fields.Get";
        TempArgument."Version" := TempArgument."Version"::"1.0";
        TempArgument.Insert();
        RequestJson.Add('tableId', Database::"TS Usage Line ori");
        FieldNumbers.Add(FieldNumber);
        RequestJson.Add('fieldNumbers', FieldNumbers);
        TempArgument.SetRequestJson(RequestJson);
        MessageImplementation := TempArgument.GetMessageTypeInterface();
        MessageImplementation.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        ResponseJson.Get('result', Token);
        Fields := Token.AsArray();
        Fields.Get(0, Token);
        FieldJson := Token.AsObject();
        FieldJson.Get(RestrictionName, Token);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure Run(MessageType: Enum "Message Type ori"; RequestJson: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "TS Usage Mgt ori";
    begin
        // Called through the manager: the license check sits in ExecuteBifrostTask and is a licence-path check (NOT_RUN per PR).
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument."Type" := MessageType;
        TempArgument."Version" := TempArgument."Version"::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(RequestJson);
        Mgt.Execute(TempArgument, OperationOf(MessageType));
        exit(TempArgument.GetResponseJson());
    end;

    local procedure OperationOf(MessageType: Enum "Message Type ori"): Integer
    begin
        case MessageType of
            "Message Type ori"::"Projects.Usage.Register":
                exit(1);
            "Message Type ori"::"Projects.Usage.Submit":
                exit(2);
            "Message Type ori"::"Projects.Usage.Approve":
                exit(3);
            "Message Type ori"::"Projects.Usage.Reject":
                exit(4);
            "Message Type ori"::"Projects.Usage.Transfer":
                exit(5);
            "Message Type ori"::"Projects.Usage.Reverse":
                exit(6);
        end;
        exit(7);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text)
    begin
        Assert.AreEqual('Error', Text(Response, 'status'), 'The call should be refused.');
        Assert.AreEqual(ExpectedCode, Text(Response, 'code'), 'Refusal code.');
        Assert.AreEqual(ExpectedParameter, Text(Response, 'parameter'), 'Refusal parameter.');
        Assert.AreNotEqual('', Text(Response, 'nextStep'), 'A next step is given.');
    end;

    local procedure Text(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Response.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
    end;

    local procedure RegisterRequest(SheetNo: Code[20]; LineNo: Integer; TypeName: Text; No: Code[20]; Quantity: Decimal) Request: JsonObject
    begin
        Request.Add('timeSheetNo', SheetNo);
        Request.Add('lineNo', LineNo);
        Request.Add('type', TypeName);
        Request.Add('no', No);
        Request.Add('date', Format(WorkDate(), 0, 9));
        Request.Add('quantity', Quantity);
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
        ResTemplate.Name := CopyStr('TU' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 10);
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

    local procedure NewItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItem(Item);
        exit(Item."No.");
    end;

    local procedure NewResource(): Code[20]
    var
        Resource: Record Resource;
    begin
        LibraryResource.CreateResourceNew(Resource);
        exit(Resource."No.");
    end;

    // The sheet belongs to the caller (owner) or is approved by the caller (approver); never both.
    local procedure NewSheet(CallerIsOwner: Boolean): Code[20]
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
    begin
        Header.Init();
        Header."No." := CopyStr('XU52' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Resource No." := NewResource();
        Header."Starting Date" := WorkDate();
        Header."Ending Date" := WorkDate() + 6;
        if CallerIsOwner then begin
            Header."Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Owner User ID"));
            Header."Approver User ID" := 'XAPPROVER';
        end else begin
            Header."Owner User ID" := 'XOWNER';
            Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        end;
        Header.Insert(false);
        Line.Init();
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        Line.Insert(false);
        exit(Header."No.");
    end;

    local procedure SetLineJob(SheetNo: Code[20]; JobNo: Code[20]; TaskNo: Code[20])
    var
        Line: Record "Time Sheet Line";
    begin
        Line.Get(SheetNo, 10000);
        Line."Job No." := JobNo;
        Line."Job Task No." := TaskNo;
        Line.Modify(false);
    end;

    local procedure NewUsage(SheetNo: Code[20]; TypeName: Text; No: Code[20]; Status: Enum "TS Usage Status ori"): Integer
    var
        Header: Record "Time Sheet Header";
        Usage: Record "TS Usage Line ori";
    begin
        Header.Get(SheetNo);
        Usage.Init();
        Usage."Time Sheet No." := SheetNo;
        Usage."Time Sheet Line No." := 10000;
        Usage."Resource No." := Header."Resource No.";
        if TypeName = 'Item' then
            Usage.Type := Usage.Type::Item
        else
            Usage.Type := Usage.Type::Resource;
        Usage."No." := No;
        Usage.Date := WorkDate();
        Usage.Quantity := 2;
        Usage.Status := Status;
        Usage.Insert();
        exit(Usage."Entry No.");
    end;

    local procedure LastItemLedgerEntryNo(): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        if ItemLedgerEntry.FindLast() then
            exit(ItemLedgerEntry."Entry No.");
    end;
}
