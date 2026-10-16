namespace Origo.Bifrost.Projects.Test;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
/// <summary>Explicit native-component Web Client fixture seeder, invoked only in the worker-owned verification container. This is not shipping licensing or MCP proof.</summary>
codeunit 97110 "Projects UI Fixture ori"
{
    Access = Internal;
    trigger OnRun()
    var
        Project: Record Job;
        Library: Codeunit "Projects Test Library ori";
        Request: JsonObject;
        CopyRequest: JsonObject;
        StatusRequest: JsonObject;
        WIPRequest: JsonObject;
        MasterNo: Code[20];
        Planning: JsonObject;
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
        WIPRequest := Library.NewEconomicWIPRequest();
        Project.Get(WIPRequest.GetText('projectNo'));
        Project.Description := 'X Projects UI WIP';
        Project.Modify(true);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", WIPRequest), 'Success');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Post", WIPRequest), 'Success');
        Commit();
    end;
}
