namespace Origo.Bifrost.Projects.Test;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
/// <summary>Explicit native-component Web Client fixture seeder, invoked only in the worker-owned verification container. This is not shipping licensing or MCP proof.</summary>
codeunit 97110 "Projects UI Fixture ori"
{
    Access = Internal;
    trigger OnRun()
    var
        Project: Record Job;
        PlanningLine: Record "Job Planning Line";
        Ledger: Record "Job Ledger Entry";
        Library: Codeunit "Projects Test Library ori";
        Request: JsonObject;
        CopyRequest: JsonObject;
        StatusRequest: JsonObject;
        WIPRequest: JsonObject;
        EntryNo: Integer;
        MasterNo: Code[20];
        Planning: JsonObject;
        LinkRequest: JsonObject;
        Task: JsonObject;
        Tasks: JsonArray;
        Lines: JsonArray;
    begin
        // Never replay a seeded fixture blindly. The retained owner inspects actual state before repair.
        if Project.Get('XW4-PROJECT-UI') then
            exit;
        Request := Library.NewProjectRequest();
        MasterNo := Library.SeedPlanningMaster(CopyStr(Request.GetText('billToCustomerNo'), 1, 20), 'Resource');
        Request.Replace('projectNo', 'XW4-PROJECT-UI');
        Request.Replace('description', 'X Projects UI lifecycle');
        Planning.Add('lineNo', 10000);
        Planning.Add('type', 'Resource');
        Planning.Add('no', MasterNo);
        Planning.Add('lineType', 'Both Budget and Billable');
        Planning.Add('quantity', 3);
        Planning.Add('unitCost', 7);
        Planning.Add('unitPrice', 14);
        Lines.Add(Planning);
        Task.Add('taskNo', 'X100');
        Task.Add('description', 'X Projects UI task');
        Task.Add('planningLines', Lines);
        Tasks.Add(Task);
        Request.Add('tasks', Tasks);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        CopyRequest.Add('projectNo', 'XW4-PROJECT-UI');
        CopyRequest.Add('targetProjectNo', 'XW4-COPY-UI');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Copy", CopyRequest), 'Success');
        StatusRequest.Add('projectNo', 'XW4-COPY-UI');
        StatusRequest.Add('status', 'Open');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", StatusRequest), 'Success');
        Project.Get('XW4-PROJECT-UI');
        Project.Validate("Apply Usage Link", true);
        Project.Modify(true);
        PlanningLine.Get('XW4-PROJECT-UI', 'X100', 10000);
        PlanningLine.Validate("Usage Link", true);
        PlanningLine.Modify(true);
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Job No." := 'XW4-PROJECT-UI';
        Ledger."Job Task No." := 'X100';
        Ledger."Entry Type" := Ledger."Entry Type"::Usage;
        Ledger.Type := Ledger.Type::Resource;
        Ledger."No." := PlanningLine."No.";
        Ledger."Unit of Measure Code" := PlanningLine."Unit of Measure Code";
        Ledger."Qty. per Unit of Measure" := 1;
        Ledger.Quantity := 1;
        Ledger."Quantity (Base)" := 1;
        Ledger."Posting Date" := DMY2Date(16, 10, 2026);
        Ledger."Total Cost" := 7;
        Ledger."Total Cost (LCY)" := 7;
        Ledger."Line Amount" := 14;
        Ledger."Line Amount (LCY)" := 14;
        Ledger.Insert(true);
        LinkRequest.Add('projectNo', 'XW4-PROJECT-UI');
        LinkRequest.Add('taskNo', 'X100');
        LinkRequest.Add('entryNo', Ledger."Entry No.");
        LinkRequest.Add('lineNo', 10000);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", LinkRequest), 'Success');
        WIPRequest := Library.NewEconomicWIPRequest();
        Project.Get(WIPRequest.GetText('projectNo'));
        Project.Description := 'X Projects UI WIP';
        Project.Modify(true);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", WIPRequest), 'Success');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Post", WIPRequest), 'Success');
        Commit();
    end;
}
