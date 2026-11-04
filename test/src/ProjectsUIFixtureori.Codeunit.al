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

    /// <summary>Seeds one isolated queue-test WIP project and one unlinked usage entry in the owned test company. Never accepts consent or changes licensing.</summary>
    procedure SeedMcpFixture(Lcid: Integer)
    var
        Project: Record Job;
        Planning: Record "Job Planning Line";
        Ledger: Record "Job Ledger Entry";
        Library: Codeunit "Projects Test Library ori";
        Request: JsonObject;
        Marker: Text[100];
        DocumentNo: Code[20];
        EntryNo: Integer;
        LanguageErr: Label 'Only the assigned verification languages are supported.', Comment = 'is-IS=Aðeins úthlutuð prófunartungumál eru studd.';
        PartialErr: Label 'Partial MCP fixture exists. Inspect actual owned state before recovery.', Comment = 'is-IS=MCP-prófunargögn eru til að hluta. Skoðaðu raunveruleg eigin gögn áður en vinnu er haldið áfram.';
    begin
        if not (Lcid in [1033, 1039]) then
            Error(LanguageErr);
        Marker := CopyStr('X Projects MCP WIP ' + Format(Lcid, 0, 9), 1, MaxStrLen(Marker));
        DocumentNo := CopyStr('XMCP' + Format(Lcid, 0, 9) + 'USAGE', 1, MaxStrLen(DocumentNo));
        if McpFixtureExists(Lcid) then
            exit;
        Project.SetRange(Description, Marker);
        Ledger.SetRange("Document No.", DocumentNo);
        if not Project.IsEmpty() or not Ledger.IsEmpty() then
            Error(PartialErr);
        Planning.Get('XW4-PROJECT-UI', 'X100', 10000);
        Request := Library.NewEconomicWIPRequest();
        Ledger.Reset();
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Document No." := DocumentNo;
        Ledger."Job No." := Planning."Job No.";
        Ledger."Job Task No." := Planning."Job Task No.";
        Ledger."Entry Type" := Ledger."Entry Type"::Usage;
        Ledger.Type := Ledger.Type::Resource;
        Ledger."No." := Planning."No.";
        Ledger."Unit of Measure Code" := Planning."Unit of Measure Code";
        Ledger."Qty. per Unit of Measure" := Planning."Qty. per Unit of Measure";
        Ledger.Quantity := 1;
        Ledger."Quantity (Base)" := Planning."Qty. per Unit of Measure";
        Ledger."Posting Date" := DMY2Date(16, 10, 2026);
        Ledger."Total Cost" := 7;
        Ledger."Total Cost (LCY)" := 7;
        Ledger."Total Price" := 14;
        Ledger."Total Price (LCY)" := 14;
        Ledger.Insert(true);
        Project.Get(Request.GetText('projectNo'));
        Project.Description := Marker;
        Project.Modify(true);
        Commit();
    end;

    /// <summary>Prevents repeated seeding; the retained owner also inspects actual rows after an uncertain result.</summary>
    procedure McpFixtureExists(Lcid: Integer): Boolean
    var
        Project: Record Job;
        Ledger: Record "Job Ledger Entry";
    begin
        Project.SetRange(Description, 'X Projects MCP WIP ' + Format(Lcid, 0, 9));
        Ledger.SetRange("Document No.", 'XMCP' + Format(Lcid, 0, 9) + 'USAGE');
        exit(not Project.IsEmpty() and not Ledger.IsEmpty());
    end;
}
