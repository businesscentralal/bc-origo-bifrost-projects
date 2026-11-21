namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Builds raw resource and stocked-item budget fixtures on owned test tenants.</summary>
codeunit 97181 "Proj. Plan Journal Fixture ori"
{
    Access = Internal;

    /// <summary>Creates an isolated project and journal, returning its exact request.</summary>
    internal procedure Seed() Request: JsonObject
    var
        Plan: Record "Job Planning Line";
        Project: Record Job;
        Item: Record Item;
        Account: Record "G/L Account";
        JobGroup: Record "Job Posting Group";
        InventoryGroup: Record "Inventory Posting Group";
        InventorySetup: Record "Inventory Posting Setup";
        General: Record "General Posting Setup";
        EmptyBusinessGeneral: Record "General Posting Setup";
        JournalTemplate: Record "Job Journal Template";
        Batch: Record "Job Journal Batch";
        TempStock: Record "Item Journal Line" temporary;
        Period: Record "Inventory Period";
        Library: Codeunit "Projects Test Library ori";
        PostStock: Codeunit "Item Jnl.-Post Line";
        ResourcePlan: JsonObject;
        ItemPlan: JsonObject;
        Lines: JsonArray;
        Selection: JsonObject;
        ItemNo: Code[20];
        ProjectNo: Code[20];
    begin
        WorkDate(Today());
        Period.SetRange(Closed, true);
        if Period.FindLast() then
            if Period."Ending Date" >= WorkDate() then
                WorkDate(Period."Ending Date" + 1);
        ResourcePlan := Library.NewPlanningRequest('Resource');
        ProjectNo := CopyStr(ResourcePlan.GetText('projectNo'), 1, 20);
        ResourcePlan.Replace('planningDate', Format(WorkDate(), 0, 9));
        ResourcePlan.Replace('lineType', 'Budget');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", ResourcePlan), 'Success');
        Project.Get(ProjectNo);
        Project.Description := 'X PlanJournal81 fixture';
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        ItemNo := Library.SeedPlanningMaster(Project."Bill-to Customer No.", 'Item');
        Item.Get(ItemNo);
        Item.Type := Item.Type::Inventory;
        Item.Modify(true);
        Account."No." := ProjectNo;
        Account.Name := 'X PlanJournal81 fixture';
        Account."Direct Posting" := true;
        Account.Insert(true);
        JobGroup.Code := ProjectNo;
        JobGroup."Job Costs Applied Account" := ProjectNo;
        JobGroup."Job Costs Adjustment Account" := ProjectNo;
        JobGroup."WIP Costs Account" := ProjectNo;
        JobGroup.Insert(true);
        Project.Validate("Job Posting Group", JobGroup.Code);
        Project.Modify(true);
        General.SetFilter("Gen. Prod. Posting Group", '%1|%2', ResourcePlan.GetText('no'), ItemNo);
        if General.FindSet(true) then
            repeat
                General."Inventory Adjmt. Account" := ProjectNo;
                General."Direct Cost Applied Account" := ProjectNo;
                General."COGS Account" := ProjectNo;
                General."COGS Account (Interim)" := ProjectNo;
                General.Modify(true);
                EmptyBusinessGeneral := General;
                EmptyBusinessGeneral."Gen. Bus. Posting Group" := '';
                EmptyBusinessGeneral.Insert(true);
            until General.Next() = 0;
        InventoryGroup.Code := ItemNo;
        InventoryGroup.Insert(true);
        InventorySetup."Invt. Posting Group Code" := ItemNo;
        InventorySetup."Inventory Account" := ProjectNo;
        InventorySetup."Inventory Account (Interim)" := ProjectNo;
        InventorySetup.Insert(true);
        Item.Validate("Inventory Posting Group", ItemNo);
        Item.Modify(true);
        TempStock."Line No." := 10000;
        TempStock."Entry Type" := TempStock."Entry Type"::"Positive Adjmt.";
        TempStock.Validate("Posting Date", WorkDate());
        TempStock.Validate("Document No.", ProjectNo);
        TempStock.Validate("Item No.", ItemNo);
        TempStock.Validate("Gen. Bus. Posting Group", ItemNo);
        TempStock.Validate(Quantity, 10);
        TempStock.Validate("Unit Cost", 7);
        PostStock.RunWithCheck(TempStock);
        ItemPlan := ResourcePlan.Clone().AsObject();
        ItemPlan.Replace('lineNo', 20000);
        ItemPlan.Replace('type', 'Item');
        ItemPlan.Replace('no', ItemNo);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", ItemPlan), 'Success');
        Plan.SetRange("Job No.", ProjectNo);
        if Plan.FindSet(true) then
            repeat
                Plan."Document No." := ProjectNo;
                Plan.Modify(true);
            until Plan.Next() = 0;
        JournalTemplate.Name := CopyStr(ProjectNo, 1, 10);
        JournalTemplate.Description := 'X PlanJournal81 fixture';
        JournalTemplate.Insert(true);
        Batch."Journal Template Name" := JournalTemplate.Name;
        Batch.Name := 'X81';
        Batch.Description := 'X PlanJournal81 fixture';
        Batch.Insert(true);
        Selection.Add('taskNo', 'X100');
        Selection.Add('lineNo', 10000);
        Lines.Add(Selection.Clone());
        Selection.Replace('lineNo', 20000);
        Lines.Add(Selection.Clone());
        Request.Add('projectNo', ProjectNo);
        Request.Add('planningLines', Lines);
        Request.Add('templateName', JournalTemplate.Name);
        Request.Add('batchName', Batch.Name);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Commit();
    end;

    /// <summary>Invokes the Projects transaction boundary with an isolated argument.</summary>
    internal procedure Execute(Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Proj. Plan Journal Impl ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.PlanningLine.TransferToJournal";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Impl.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    /// <summary>Posts through Foundation's dispatcher, including its real licence validation.</summary>
    internal procedure Post(Request: JsonObject) Response: JsonObject
    var
        PostRequest: JsonObject;
    begin
        PostRequest.Add('templateName', Request.GetText('templateName'));
        PostRequest.Add('batchName', Request.GetText('batchName'));
        PostRequest.Add('expectedCount', 2);
        exit(Dispatch("Message Type ori"::"Projects.ProjectJournal.Post", PostRequest));
    end;

    /// <summary>Exercises Foundation dispatch without forging licence or invocation state.</summary>
    internal procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        MessageId: Guid;
    begin
        exit(Dispatch(MessageType, Request, MessageId));
    end;

    /// <summary>Returns the persisted message identifier for read-only logging assertions.</summary>
    internal procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; var MessageId: Guid) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Commit();
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', 'XPLANJOURNAL81', 'application/json', RequestContent, EmptyTaskId, GlobalLanguage(), MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;
}
