namespace Origo.Bifrost.Projects.Test;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
using System.TestLibraries.Utilities;
/// <summary>Native statistics match standard BC amounts and preserve project/task isolation.</summary>
codeunit 97108 "Projects Statistics Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_AllTypes_ReturnsNativeTotals()
    var
        Request: JsonObject;
        Response: JsonObject;
        Statistics: JsonObject;
        Budget: JsonObject;
        Actual: JsonObject;
        Billable: JsonObject;
        Invoiced: JsonObject;
        No: Code[20];
    begin
        // Story #6, AC01 | Time: fixture 2026-10-16 | Risk: owned component fixtures, no shipping licence proof.
        No := NewStatisticsProject();
        SeedAmounts(No, 'X100', 10000, "Job Planning Line Type"::Resource, 7, 14);
        SeedAmounts(No, 'X100', 20000, "Job Planning Line Type"::Item, 11, 22);
        SeedAmounts(No, 'X100', 30000, "Job Planning Line Type"::"G/L Account", 13, 26);
        Request.Add('projectNo', No);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Statistics.Get", Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual('LCY', Response.GetText('currency'), 'Amounts explicitly identify LCY');
        Statistics := Response.GetObject('statistics');
        Budget := Statistics.GetObject('budget');
        Actual := Statistics.GetObject('actual');
        Billable := Statistics.GetObject('billable');
        Invoiced := Statistics.GetObject('invoiced');
        Assert.AreEqual(31, Budget.GetObject('total').GetDecimal('cost'), 'Budget sums all three native types');
        Assert.AreEqual(62, Budget.GetObject('total').GetDecimal('price'), 'Budget price');
        Assert.AreEqual(31, Actual.GetObject('total').GetDecimal('cost'), 'Actual native usage cost');
        Assert.AreEqual(62, Actual.GetObject('total').GetDecimal('price'), 'Actual uses native line amount');
        Assert.AreEqual(31, Billable.GetObject('total').GetDecimal('cost'), 'Both lines count as billable');
        Assert.AreEqual(62, Invoiced.GetObject('total').GetDecimal('price'), 'Native sales sign is normalized');
        Assert.AreEqual(7, Budget.GetObject('resource').GetDecimal('cost'), 'Resource split');
        Assert.AreEqual(11, Budget.GetObject('item').GetDecimal('cost'), 'Item split');
        Assert.AreEqual(13, Budget.GetObject('glAccount').GetDecimal('cost'), 'G/L split');
    end;

    [Test]
    procedure Scenario_AC01_TaskBreakdown_IsolatesProjectsAndTasks()
    var
        Task: Record "Job Task";
        Request: JsonObject;
        Response: JsonObject;
        Tasks: JsonArray;
        No: Code[20];
        OtherNo: Code[20];
    begin
        // Story #6, AC01 | Time: fixture date fixed | Risk: total tasks must not double count.
        No := NewStatisticsProject();
        OtherNo := NewStatisticsProject();
        SeedAmounts(No, 'X100', 10000, "Job Planning Line Type"::Resource, 7, 14);
        SeedAmounts(OtherNo, 'X100', 10000, "Job Planning Line Type"::Resource, 999, 1998);
        Task.Init();
        Task."Job No." := No;
        Task."Job Task No." := 'XTOTAL';
        Task."Job Task Type" := Task."Job Task Type"::Total;
        Task.Totaling := 'X100';
        Task.Insert(true);
        Request.Add('projectNo', No);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.BudgetVsActual.Get", Request);
        Library.AssertStatus(Response, 'Success');
        Tasks := Response.GetArray('tasks');
        Assert.AreEqual(1, Tasks.Count(), 'Only posting tasks returned');
        Assert.AreEqual('X100', Tasks.GetObject(0).GetText('taskNo'), 'Own task key');
        Assert.AreEqual(7, Tasks.GetObject(0).GetObject('statistics').GetObject('actual').GetObject('total').GetDecimal('cost'), 'Other project excluded');
        Request.Add('taskNo', 'X100');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.BudgetVsActual.Get", Request);
        Assert.AreEqual(1, Response.GetArray('tasks').Count(), 'Exact task filter');
    end;

    [Test]
    procedure Scenario_AC01_EmptyAndMissingProject_StableResponses()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #6, AC01 | Time: no dependency | Risk: empty results differ from missing project.
        Request.Add('projectNo', NewStatisticsProject());
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Statistics.Get", Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetObject('statistics').GetObject('actual').GetObject('total').GetDecimal('cost'), 'Empty project returns zero');
        Request.Replace('projectNo', 'X-NO-SUCH-PROJECT');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Statistics.Get", Request);
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Missing native project error surfaced');
        Clear(Request);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Statistics.Get", Request);
        Assert.AreEqual('MissingParameter', Response.GetArray('errors').GetObject(0).GetText('code'), 'Missing project key validated');
    end;

    local procedure NewStatisticsProject(): Code[20]
    var
        Request: JsonObject;
        TaskRequest: JsonObject;
    begin
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        TaskRequest.Add('projectNo', Request.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'X100');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        exit(CopyStr(Request.GetText('projectNo'), 1, 20));
    end;

    local procedure SeedAmounts(ProjectNo: Code[20]; TaskNo: Code[20]; LineNo: Integer; Type: Enum "Job Planning Line Type"; Cost: Decimal; Price: Decimal)
    var
        Plan: Record "Job Planning Line";
        Ledger: Record "Job Ledger Entry";
        EntryNo: Integer;
    begin
        Plan.Init();
        Plan."Job No." := ProjectNo;
        Plan."Job Task No." := TaskNo;
        Plan."Line No." := LineNo;
        Plan.Type := Type;
        Plan.Validate("Line Type", Plan."Line Type"::"Both Budget and Billable");
        Plan."Total Cost (LCY)" := Cost;
        Plan."Line Amount (LCY)" := Price;
        Plan.Insert(true);
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Job No." := ProjectNo;
        Ledger."Job Task No." := TaskNo;
        Ledger."Entry Type" := Ledger."Entry Type"::Usage;
        Ledger.Type := Type;
        Ledger."Total Cost (LCY)" := Cost;
        Ledger."Line Amount (LCY)" := Price;
        Ledger.Insert(true);
        Ledger."Entry No." += 1;
        Ledger."Entry Type" := Ledger."Entry Type"::Sale;
        Ledger."Total Cost (LCY)" := -Cost;
        Ledger."Line Amount (LCY)" := -Price;
        Ledger.Insert(true);
    end;
}
