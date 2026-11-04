namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;
using Microsoft.Projects.Project.WIP;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.Dimension;

/// <summary>Issue #5 read/calculation component tests; nonzero WIP calculation and posting acceptance remain pending.</summary>
codeunit 97106 "Projects WIP Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    [Test]
    procedure Scenario_AC01_GetOwnEntries_FiltersOtherProject()
    var
        WIPEntry: Record "Job WIP Entry";
        GLEntry: Record "Job WIP G/L Entry";
        Request: JsonObject;
        OtherRequest: JsonObject;
        ReadRequest: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
    begin
        // Story #5, AC01 | Time: fixed2026-10-16 fixture dates | Risk: synthetic owned read fixtures, not a calculation/posting or licensing pass
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        OtherRequest := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", OtherRequest), 'Success');
        SeedEntries(CopyStr(Request.GetText('projectNo'), 1, 20), 17);
        SeedEntries(CopyStr(OtherRequest.GetText('projectNo'), 1, 20), 99);
        ReadRequest.Add('projectNo', Request.GetText('projectNo'));
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Get", ReadRequest);
        Library.AssertStatus(Response, 'Success');
        Entries := Response.GetArray('entries');
        Assert.AreEqual(1, Entries.Count(), 'WIP query must not read the other owned project');
        Assert.AreEqual(17, Entries.GetObject(0).GetDecimal('amount'), 'WIP amount must match the owned fixture');
        Entries := Response.GetArray('glEntries');
        Assert.AreEqual(1, Entries.Count(), 'Posted WIP query must not read the other project');
        Assert.AreEqual(17, Entries.GetObject(0).GetDecimal('amount'), 'Posted WIP amount must match');
        WIPEntry.SetRange("Job No.", Request.GetText('projectNo'));
        GLEntry.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.AreEqual(1, WIPEntry.Count(), 'Get must not consume WIP entries');
        Assert.AreEqual(1, GLEntry.Count(), 'Get must not change posted WIP entries');
    end;

    [Test]
    procedure Scenario_AC01_EmptyProjectCalculation_UpdatesNativeDate()
    var
        Project: Record Job;
        Method: Record "Job WIP Method";
        Request: JsonObject;
        CalculateRequest: JsonObject;
        Response: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #5, AC01 | Time: explicit2026-10-16 posting date | Risk: empty project only; nonzero economic WIP remains unverified
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        MethodCode := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(MethodCode));
        Method.Init();
        Method.Code := MethodCode;
        Method.Description := 'X Projects WIP calculation';
        Method.Valid := true;
        Method.Insert(true);
        Project.Get(Request.GetText('projectNo'));
        Project.Validate("WIP Method", Method.Code);
        Project.Modify(true);
        CalculateRequest.Add('projectNo', Request.GetText('projectNo'));
        CalculateRequest.Add('postingDate', '2026-10-16');
        CalculateRequest.Add('documentNo', 'XCALC');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", CalculateRequest);
        Library.AssertStatus(Response, 'Success');
        Project.Get(Request.GetText('projectNo'));
        Assert.AreEqual(20261016D, Project."WIP Posting Date", 'Native calculation must use the explicit date');
        Assert.AreEqual(0, Response.GetArray('entries').Count(), 'Empty-project baseline must report zero calculated entries honestly');
    end;

    [Test]
    procedure Scenario_AC01_MissingCalculationOptions_CollectBoth()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #5, AC01 | Time: no date dependency | Risk: None
        Library.Initialize();
        Request.Add('projectNo', 'XNOTFOUND');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request);
        Assert.AreEqual('MultipleErrors', Response.GetText('code'), 'Date and document number are both required before native writes');
        Assert.AreEqual(2, Response.GetArray('errors').Count(), 'Both missing options must be identified');
    end;

    [Test]
    procedure Scenario_AC01_MissingWIPMethod_ReturnsNativeError()
    var
        Project: Record Job;
        Request: JsonObject;
        CalculateRequest: JsonObject;
        Response: JsonObject;
    begin
        // Story #5, AC01 | Time: explicit2026-10-16 date | Risk: no native WIP method bypass
        Request := Library.NewProjectRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request), 'Success');
        Project.Get(Request.GetText('projectNo'));
        Project.Validate("WIP Method", '');
        Project.Modify(true);
        CalculateRequest.Add('projectNo', Request.GetText('projectNo'));
        CalculateRequest.Add('postingDate', '2026-10-16');
        CalculateRequest.Add('documentNo', 'XCALC');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", CalculateRequest);
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Native missing-method validation must surface');
    end;

    [Test]
    [HandlerFunctions('DeclineGlobalDimensionFilterUpdate')]
    procedure Scenario_AC01_NonzeroUsage_CalculatesEconomicWIP()
    var
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
        Entry: JsonToken;
        Nonzero: Boolean;
    begin
        // Story #5, AC01 | Time: explicit 2026-10-16 | Risk: isolated native component, no licensing proof.
        Request := Library.NewEconomicWIPRequest();
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request);
        Library.AssertStatus(Response, 'Success');
        Entries := Response.GetArray('entries');
        Assert.IsTrue(Entries.Count() > 0, 'Native engine must calculate economic WIP');
        foreach Entry in Entries do
            Nonzero := Nonzero or (Entry.AsObject().GetDecimal('amount') <> 0);
        Assert.IsTrue(Nonzero, 'At least one calculated WIP amount must be nonzero');
    end;

    [Test]
    [HandlerFunctions('DeclineGlobalDimensionFilterUpdate')]
    procedure Scenario_AC01_CalculatedWIP_PostsNativeGLEntries()
    var
        GLEntry: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
    begin
        // Story #5, AC01 | Time: explicit 2026-10-16 | Risk: writes only owned ephemeral native company; not a shipping MCP pass.
        Request := Library.NewEconomicWIPRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request), 'Success');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Post", Request);
        Library.AssertStatus(Response, 'Success');
        Entries := Response.GetArray('glEntries');
        Assert.IsTrue(Entries.Count() > 0, 'Posting produces WIP G/L entries');
        Assert.IsTrue(Entries.GetObject(0).GetInteger('glEntryNo') > 0, 'WIP references a real G/L entry');
        GLEntry.SetRange("Document No.", Request.GetText('documentNo'));
        Assert.IsTrue(GLEntry.Count() > 0, 'Native posting must create real financial entries');
    end;

    [Test]
    [HandlerFunctions('DeclineGlobalDimensionFilterUpdate')]
    procedure Scenario_AC01_MissingDimensions_RefusesNativePosting()
    var
        WIPEntry: Record "Job WIP Entry";
        GLEntry: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #5, AC01 | Time: explicit 2026-10-16 | Risk: mandatory dimensions must remain enforced, no weakened native gate.
        Request := Library.NewEconomicWIPRequest();
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.WIP.Calculate", Request), 'Success');
        WIPEntry.SetRange("Job No.", Request.GetText('projectNo'));
        WIPEntry.ModifyAll("Dimension Set ID", 0, true);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.WIP.Post", Request);
        Assert.AreEqual('BusinessCentralError', Response.GetText('code'), 'Native mandatory-dimension posting refusal');
        Assert.IsTrue(Response.GetText('error').ToLower().Contains('dimension'), 'Native dimension error must be surfaced');
        GLEntry.SetRange("Document No.", Request.GetText('documentNo'));
        Assert.AreEqual(0, GLEntry.Count(), 'Rejected posting must not create financial entries');
    end;

    [ConfirmHandler]
    procedure DeclineGlobalDimensionFilterUpdate(Question: Text[1024]; var Reply: Boolean)
    begin
        if Question.Contains('Allowed Values Filter') then
            Assert.IsTrue(Question.Contains('dimension value X'), 'Only the unique owned dimension value is involved: ' + Question)
        else begin
            Assert.IsTrue(Question.Contains('You have changed a dimension.'), 'Unexpected native confirmation: ' + Question);
            Assert.IsTrue(Question.Contains('Do you want to update the lines?'), 'Unexpected native confirmation: ' + Question);
        end;
        // The fixture explicitly sets its own task dimensions; never broaden global filters or update unrelated lines.
        Reply := false;
    end;

    local procedure SeedEntries(ProjectNo: Code[20]; Amount: Decimal)
    var
        WIPEntry: Record "Job WIP Entry";
        GLEntry: Record "Job WIP G/L Entry";
        WIPNo: Integer;
        GLNo: Integer;
    begin
        if WIPEntry.FindLast() then
            WIPNo := WIPEntry."Entry No.";
        WIPEntry.Init();
        WIPEntry."Entry No." := WIPNo + 1;
        WIPEntry."Job No." := ProjectNo;
        WIPEntry."Document No." := 'XREAD';
        WIPEntry."WIP Posting Date" := 20261016D;
        WIPEntry."WIP Entry Amount" := Amount;
        WIPEntry.Insert(true);
        if GLEntry.FindLast() then
            GLNo := GLEntry."Entry No.";
        GLEntry.Init();
        GLEntry."Entry No." := GLNo + 1;
        GLEntry."Job No." := ProjectNo;
        GLEntry."Document No." := 'XREAD';
        GLEntry."Posting Date" := 20261016D;
        GLEntry."WIP Entry Amount" := Amount;
        GLEntry.Insert(true);
    end;
}
