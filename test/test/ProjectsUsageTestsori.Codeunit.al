namespace Origo.Bifrost.Projects.Test;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Ledger;
using System.TestLibraries.Utilities;
/// <summary>Owned native usage fixtures prove linking, transfer, remaining quantities and validation isolation.</summary>
codeunit 97109 "Projects Usage Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_ExistingPlanning_LinkReducesRemaining()
    var
        Planning: Record "Job Planning Line";
        Link: Record "Job Usage Link";
        Request: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
    begin
        // Story #8, AC01 | Time: explicit2026-10-16 | Risk: isolated native component, not shipping acceptance.
        Request := NewUsageRequest(EntryNo);
        Request.Add('entryNo', EntryNo);
        Request.Add('lineNo', 10000);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Library.AssertStatus(Response, 'Success');
        Planning.Get(Request.GetText('projectNo'), 'X100', 10000);
        Assert.AreEqual(2, Planning."Remaining Qty.", 'Native link consumes exactly one of three units');
        Assert.AreEqual(1, Planning."Qty. Posted", 'Native posted quantity');
        Assert.IsTrue(Link.Get(Planning."Job No.", 'X100', 10000, EntryNo), 'Native usage association created');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Duplicate usage must not consume quantity twice');
        Planning.Get(Request.GetText('projectNo'), 'X100', 10000);
        Assert.AreEqual(2, Planning."Remaining Qty.", 'Duplicate failure leaves quantity intact');
    end;

    [Test]
    procedure Scenario_AC01_CreateFromUsage_ReturnsNativePlanning()
    var
        Planning: Record "Job Planning Line";
        Request: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
    begin
        // Story #8, AC01 | Time: explicit2026-10-16 | Risk: native transfer owns amounts and line numbering.
        Request := NewUsageRequest(EntryNo);
        Request.Add('entryNo', EntryNo);
        Request.Add('createPlanningLine', true);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Library.AssertStatus(Response, 'Success');
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        Planning.SetRange("Job Task No.", 'X100');
        Planning.SetRange("Job Ledger Entry No.", EntryNo);
        Assert.IsTrue(Planning.FindFirst(), 'Native transfer creates a planning line from usage');
        Assert.AreEqual(1, Planning.Quantity, 'Created quantity equals usage');
        Assert.AreEqual(7, Planning."Total Cost", 'Created native cost retains usage cost');
    end;

    [Test]
    procedure Scenario_AC01_Get_IsReadOnlyAndTaskScoped()
    var
        Request: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
    begin
        // Story #8, AC01 | Time: explicit2026-10-16 | Risk: read must not consume usage.
        Request := NewUsageRequest(EntryNo);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Get", Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('links').Count(), 'No unrequested linkage');
        Assert.AreEqual(1, Response.GetArray('planningLines').Count(), 'Only requested task planning lines');
        Assert.AreEqual(3, Response.GetArray('planningLines').GetObject(0).GetDecimal('remainingQuantity'), 'Get preserves remaining quantity');
    end;

    [Test]
    procedure Scenario_AC01_ForeignEntryOrDisabledUsage_Rejects()
    var
        Project: Record Job;
        Request: JsonObject;
        OtherRequest: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
        OtherEntryNo: Integer;
    begin
        // Story #8, AC01 | Time: explicit2026-10-16 | Risk: exact project ownership enforced before linking.
        Request := NewUsageRequest(EntryNo);
        OtherRequest := NewUsageRequest(OtherEntryNo);
        Request.Add('entryNo', OtherEntryNo);
        Request.Add('lineNo', 10000);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Foreign project usage rejected');
        Project.Get(Request.GetText('projectNo'));
        Project."Apply Usage Link" := false;
        Project.Modify(true);
        Request.Replace('entryNo', EntryNo);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Disabled native project usage link rejected');
        Request.Replace('entryNo', 'bad');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Usage.Link", Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Typed input validation precedes writes');
    end;

    local procedure NewUsageRequest(var EntryNo: Integer) Request: JsonObject
    var
        Project: Record Job;
        Planning: Record "Job Planning Line";
        Ledger: Record "Job Ledger Entry";
        PlanningRequest: JsonObject;
    begin
        PlanningRequest := Library.NewPlanningRequest('Resource');
        Project.Get(PlanningRequest.GetText('projectNo'));
        Project.Validate("Apply Usage Link", true);
        Project.Modify(true);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanningRequest), 'Success');
        Planning.Get(PlanningRequest.GetText('projectNo'), 'X100', 10000);
        Planning.Validate("Usage Link", true);
        Planning.Modify(true);
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        EntryNo += 1;
        Ledger.Init();
        Ledger."Entry No." := EntryNo;
        Ledger."Job No." := Project."No.";
        Ledger."Job Task No." := 'X100';
        Ledger."Entry Type" := Ledger."Entry Type"::Usage;
        Ledger.Type := Ledger.Type::Resource;
        Ledger."No." := Planning."No.";
        Ledger."Unit of Measure Code" := Planning."Unit of Measure Code";
        Ledger."Qty. per Unit of Measure" := 1;
        Ledger.Quantity := 1;
        Ledger."Quantity (Base)" := 1;
        Ledger."Posting Date" := DMY2Date(16, 10, 2026);
        Ledger."Unit Cost" := 7;
        Ledger."Unit Cost (LCY)" := 7;
        Ledger."Total Cost" := 7;
        Ledger."Total Cost (LCY)" := 7;
        Ledger."Line Amount" := 14;
        Ledger."Line Amount (LCY)" := 14;
        Ledger.Insert(true);
        Request.Add('projectNo', Project."No.");
        Request.Add('taskNo', 'X100');
    end;
}
