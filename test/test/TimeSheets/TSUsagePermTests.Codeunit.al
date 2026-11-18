namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
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
    [Test]
    procedure Scenario_AC05_JobLineWriteWithReadOnlyTemplate_Transfers()
    begin
        RunJobPermissionScenario(true);
    end;

    [Test]
    procedure Scenario_AC11_TemplateWriteWithoutJobLine_Refused()
    begin
        RunJobPermissionScenario(false);
    end;

    local procedure RunJobPermissionScenario(CanWriteLine: Boolean)
    var
        Header: Record "Time Sheet Header";
        SheetLine: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        Item: Record Item;
        Job: Record Job;
        Task: Record "Job Task";
        Template: Record "Job Journal Template";
        Batch: Record "Job Journal Batch";
        JournalLine: Record "Job Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryJob: Codeunit "Library - Job";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] An approved usage line on a project-linked time sheet line.
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, Task);
        LibraryInventory.CreateItem(Item);
        LibraryJob.CreateJobJournalTemplate(Template);
        LibraryJob.CreateJobJournalBatch(Template.Name, Batch);
        Header."No." := CopyStr('XU52J' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Header."No."));
        Header."Starting Date" := WorkDate();
        Header."Ending Date" := WorkDate() + 6;
        Header."Owner User ID" := 'XOWNER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert();
        SheetLine."Time Sheet No." := Header."No.";
        SheetLine."Line No." := 10000;
        SheetLine."Job No." := Job."No.";
        SheetLine."Job Task No." := Task."Job Task No.";
        SheetLine.Insert();
        Usage."Time Sheet No." := Header."No.";
        Usage."Time Sheet Line No." := SheetLine."Line No.";
        Usage."No." := Item."No.";
        Usage.Date := WorkDate();
        Usage.Quantity := 1;
        Usage.Status := Usage.Status::Approved;
        Usage.Insert();
        Request.Add('timeSheetNo', Header."No.");
        Request.Add('jobTemplate', Template.Name);
        Request.Add('jobBatch', Batch.Name);
        if CanWriteLine then
            Lower.PushPermissionSetWithoutDefaults('TSUsageJobLine ori')
        else
            Lower.PushPermissionSetWithoutDefaults('TSUsageJobNoLine ori');
        Assert.AreEqual(CanWriteLine, JournalLine.WritePermission(), 'Job line permission is the deciding gate.');
        Assert.AreEqual(not CanWriteLine, Template.WritePermission(), 'Opposite template-write permission exposes the regression.');
        TempArgument.ID := CreateGuid();
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        // [WHEN] The reduced-permission caller transfers through the message manager.
        Mgt.Execute(TempArgument, 5);
        Response := TempArgument.GetResponseJson();
        Usage.Get(Usage."Entry No.");
        // [THEN] Template write is neither required nor sufficient for journal line creation.
        if CanWriteLine then begin
            Response.Get('status', Token);
            Assert.AreEqual('Success', Token.AsValue().AsText(), 'Read-only templates permit transfer: ' + TempArgument.GetResponseText());
            Assert.AreEqual(Usage.Status::Transferred, Usage.Status, 'Transferred.');
            JournalLine.Get(Usage."Journal Template Name", Usage."Journal Batch Name", Usage."Journal Line No.");
            Assert.AreEqual(Job."No.", JournalLine."Job No.", 'Correct job journal line.');
        end else begin
            Response.Get('code', Token);
            Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal must be the explicit permission gate.');
            Response.Get('nextStep', Token);
            Assert.IsTrue(Token.AsValue().AsText().Contains('journal permissions'), 'Actionable next step.');
            Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Unchanged.');
            JournalLine.SetRange("Journal Template Name", Template.Name);
            JournalLine.SetRange("Journal Batch Name", Batch.Name);
            Assert.IsTrue(JournalLine.IsEmpty(), 'No journal line created.');
        end;
    end;

}
