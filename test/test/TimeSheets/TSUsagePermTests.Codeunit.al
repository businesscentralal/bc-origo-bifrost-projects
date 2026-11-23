namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Tracking;
using Microsoft.Finance.Dimension;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Permission tests for the Projects.Usage.* message types (projects#52, AC11).</summary>
codeunit 97154 "TS Usage Perm Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        GrantTok: Label '%1 %2 %3', Locked = true, Comment = '%1 = object type, %2 = object ID, %3 = granted levels';
        OperationAvailableMsg: Label 'Operation %1 must be available.', Locked = true, Comment = '%1 = usage operation number';
        UsageNextStepTxt: Label 'Assign BIFROST Read ori and PROJ FIELD TECH ori for your own usage, or BIFROST Full ori and PROJ USAGE ori for back-office actions.', Locked = true;
        UsageNextStepIsTxt: Label 'Úthlutaðu BIFROST Read ori og PROJ FIELD TECH ori fyrir eigin notkun eða BIFROST Full ori og PROJ USAGE ori fyrir bakvinnsluaðgerðir.', Locked = true;

    [Test]
    procedure ReadRole_CanList_CannotRegister()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // #65: the Base App time sheet reads come from PROJ USAGE ori, assigned together with BIFROST Read ori.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ USAGE ori');
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
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        DefaultDimension: Record "Default Dimension";
        DimensionEntry: Record "Dimension Set Entry";
        Header: Record "Time Sheet Header";
        SheetLine: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        Item: Record Item;
        Job: Record Job;
        Task: Record "Job Task";
        JobTemplate: Record "Job Journal Template";
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
        // A fresh item dimension forces native dimension-set creation under the reduced role.
        Dimension.Code := CopyStr('XU52D' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Dimension.Code));
        Dimension.Insert(true);
        DimensionValue."Dimension Code" := Dimension.Code;
        DimensionValue.Code := 'XVALUE';
        DimensionValue.Insert(true);
        DefaultDimension."Table ID" := Database::Item;
        DefaultDimension."No." := Item."No.";
        DefaultDimension."Dimension Code" := Dimension.Code;
        DefaultDimension."Dimension Value Code" := DimensionValue.Code;
        DefaultDimension.Insert(true);
        LibraryJob.CreateJobJournalTemplate(JobTemplate);
        LibraryJob.CreateJobJournalBatch(JobTemplate.Name, Batch);
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
        Request.Add('jobTemplate', JobTemplate.Name);
        Request.Add('jobBatch', Batch.Name);
        if CanWriteLine then
            Lower.PushPermissionSetWithoutDefaults('TSUsageJobLine ori')
        else
            Lower.PushPermissionSetWithoutDefaults('TSUsageJobNoLine ori');
        Assert.AreEqual(CanWriteLine, JournalLine.WritePermission(), 'Job line permission is the deciding gate.');
        Assert.AreEqual(not CanWriteLine, JobTemplate.WritePermission(), 'Opposite template-write permission exposes the regression.');
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
            Assert.IsTrue(DimensionEntry.Get(JournalLine."Dimension Set ID", Dimension.Code), 'Native item dimension is carried to the journal.');
            Assert.AreEqual(DimensionValue.Code, DimensionEntry."Dimension Value Code", 'Correct dimension value.');
        end else begin
            Response.Get('code', Token);
            Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal must be the explicit permission gate.');
            Response.Get('nextStep', Token);
            Assert.IsTrue(Token.AsValue().AsText().Contains('journal permissions'), 'Actionable next step.');
            Assert.AreEqual(Usage.Status::Approved, Usage.Status, 'Unchanged.');
            JournalLine.SetRange("Journal Template Name", JobTemplate.Name);
            JournalLine.SetRange("Journal Batch Name", Batch.Name);
            Assert.IsTrue(JournalLine.IsEmpty(), 'No journal line created.');
        end;
    end;

    /// <summary>#65 (Architect 6980138913): PROJ USAGE ori is assignable and holds exactly the 16 Base App grants the usage extensions had, at the same levels.</summary>
    [Test]
    procedure Scenario_65_UsageSet_HoldsMovedGrantsAtSameLevels()
    var
        MetadataPermissionSet: Record "Metadata Permission Set";
        MetadataPermission: Record "Metadata Permission";
        Assert: Codeunit "Library Assert";
        Expected: List of [Text];
        Actual: Text;
    begin
        // [GIVEN] The Base App grants Projects Usage Full ori and Projects Usage Read ori had before #65.
        AddExpectedUsageGrants(Expected);
        // [WHEN] The platform metadata of the new set is read.
        MetadataPermissionSet.SetRange("App ID", ProjectsAppId());
        MetadataPermissionSet.SetRange("Role ID", 'PROJ USAGE ori');
        Assert.IsTrue(MetadataPermissionSet.FindFirst(), 'PROJ USAGE ori must exist in the Projects app.');
        Assert.IsTrue(MetadataPermissionSet.Assignable, 'PROJ USAGE ori must be assignable.');
        MetadataPermission.SetRange("App ID", ProjectsAppId());
        MetadataPermission.SetRange("Role ID", 'PROJ USAGE ori');
        // [THEN] Every grant is one of the moved grants at the same level, and none is missing.
        Assert.AreEqual(Expected.Count(), MetadataPermission.Count(), 'PROJ USAGE ori holds exactly the moved grants.');
        MetadataPermission.FindSet();
        repeat
            Actual := FormatGrant(MetadataPermission);
            Assert.IsTrue(Expected.Contains(Actual), 'Unexpected or widened grant: ' + Actual);
        until MetadataPermission.Next() = 0;
    end;

    /// <summary>#65: the effective Foundation roles no longer hold the moved usage journal and time sheet grants.</summary>
    [Test]
    procedure Scenario_65_FoundationRoles_HoldNoMovedUsageTableData()
    var
        ExpandedPermission: Record "Expanded Permission";
        Assert: Codeunit "Library Assert";
    begin
        // [GIVEN] The journal line tables the usage transfer writes.
        ExpandedPermission.SetRange("Object Type", ExpandedPermission."Object Type"::"Table Data");
        ExpandedPermission.SetFilter("Object ID", '%1|%2|%3', Database::"Item Journal Line", Database::"Res. Journal Line", Database::"Job Journal Line");
        // [WHEN] The effective grants of BIFROST Full ori (with every extension merged) are read.
        ExpandedPermission.SetRange("Role ID", 'BIFROST Full ori');
        // [THEN] None remains in the extended Foundation Full role.
        Assert.RecordIsEmpty(ExpandedPermission);
        // [THEN] The extended Foundation Read role holds no time sheet grant.
        ExpandedPermission.SetFilter("Object ID", '%1|%2', Database::"Time Sheet Header", Database::"Time Sheet Line");
        ExpandedPermission.SetRange("Role ID", 'BIFROST Read ori');
        Assert.RecordIsEmpty(ExpandedPermission);
    end;

    /// <summary>#65: BIFROST Full ori alone is refused with a next step naming PROJ USAGE ori, in English and Icelandic.</summary>
    [Test]
    procedure Scenario_65_FullWithoutUsageSet_RefusedNamesProjUsage()
    var
        TempArgument: Record "Message Argument ori" temporary;
        TempIcelandicArgument: Record "Message Argument ori" temporary;
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A caller with only the extended Foundation Full role.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        // [THEN] No usage type is available.
        Assert.IsFalse(Mgt.CanUse(1), 'BIFROST Full ori alone cannot register.');
        Assert.IsFalse(Mgt.CanUse(5), 'BIFROST Full ori alone cannot transfer.');
        Assert.IsFalse(Mgt.CanUse(7), 'BIFROST Full ori alone cannot list.');
        // [WHEN] Register is executed in English and in Icelandic.
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        Mgt.Execute(TempArgument, 1);
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Refusal code.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'English next step: ' + TempArgument.GetResponseText());
        Assert.AreEqual(UsageNextStepTxt, Token.AsValue().AsText(), 'English next step names both sets.');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        TempIcelandicArgument.ID := CreateGuid();
        TempIcelandicArgument.Insert(true);
        Mgt.Execute(TempIcelandicArgument, 1);
        GlobalLanguage(PreviousLanguage);
        Response := TempIcelandicArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('nextStep', Token), 'Icelandic next step: ' + TempIcelandicArgument.GetResponseText());
        // [THEN] The localized next step names both sets.
        Assert.AreEqual(UsageNextStepIsTxt, Token.AsValue().AsText(), 'Icelandic next step names both sets.');
    end;

    /// <summary>#65: BIFROST Full ori together with PROJ USAGE ori enables every usage type again.</summary>
    [Test]
    procedure Scenario_65_FullAndUsageSet_EnablesUsageTypes()
    var
        Mgt: Codeunit "TS Usage Mgt ori";
        Lower: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";
        Operation: Integer;
    begin
        // [GIVEN] A caller with BIFROST Full ori and PROJ USAGE ori.
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Lower.AddPermissionSet('PROJ USAGE ori');
        // [THEN] Register, Submit, Approve, Reject, Transfer, Reverse and List are available.
        for Operation := 1 to 7 do
            Assert.IsTrue(Mgt.CanUse(Operation), StrSubstNo(OperationAvailableMsg, Operation));
    end;

    local procedure ProjectsAppId(): Guid
    begin
        exit('c847bab7-2525-4ff5-93c4-15512b3be1e5');
    end;

    local procedure FormatGrant(MetadataPermission: Record "Metadata Permission"): Text
    var
        ObjectType: Integer;
        Levels: Text;
    begin
        ObjectType := MetadataPermission."Object Type";
        if MetadataPermission."Read Permission" = MetadataPermission."Read Permission"::Yes then
            Levels += 'R';
        if MetadataPermission."Insert Permission" = MetadataPermission."Insert Permission"::Yes then
            Levels += 'I';
        if MetadataPermission."Modify Permission" = MetadataPermission."Modify Permission"::Yes then
            Levels += 'M';
        if MetadataPermission."Delete Permission" = MetadataPermission."Delete Permission"::Yes then
            Levels += 'D';
        if MetadataPermission."Execute Permission" = MetadataPermission."Execute Permission"::Yes then
            Levels += 'X';
        exit(StrSubstNo(GrantTok, ObjectType, MetadataPermission."Object ID", Levels));
    end;

    local procedure AddGrant(var Expected: List of [Text]; ObjectId: Integer; Levels: Text)
    var
        MetadataPermission: Record "Metadata Permission";
        TableData: Integer;
    begin
        TableData := MetadataPermission."Object Type"::"Table Data";
        Expected.Add(StrSubstNo(GrantTok, TableData, ObjectId, Levels));
    end;

    local procedure AddExpectedUsageGrants(var Expected: List of [Text])
    begin
        AddGrant(Expected, Database::"Time Sheet Header", 'R');
        AddGrant(Expected, Database::"Time Sheet Line", 'R');
        AddGrant(Expected, Database::Item, 'R');
        AddGrant(Expected, Database::Resource, 'R');
        AddGrant(Expected, Database::"Item Journal Template", 'R');
        AddGrant(Expected, Database::"Item Journal Batch", 'R');
        AddGrant(Expected, Database::"Item Journal Line", 'RIMD');
        AddGrant(Expected, Database::"Res. Journal Template", 'R');
        AddGrant(Expected, Database::"Res. Journal Batch", 'R');
        AddGrant(Expected, Database::"Res. Journal Line", 'RIMD');
        AddGrant(Expected, Database::"Job Journal Template", 'R');
        AddGrant(Expected, Database::"Job Journal Batch", 'R');
        AddGrant(Expected, Database::"Job Journal Line", 'RIMD');
        AddGrant(Expected, Database::"Item Ledger Entry", 'R');
        AddGrant(Expected, Database::"Res. Ledger Entry", 'R');
        AddGrant(Expected, Database::"Job Ledger Entry", 'R');
        // #84: Transfer writes the item tracking entry of a lot or serial usage line.
        AddGrant(Expected, Database::"Reservation Entry", 'RIMD');
        AddGrant(Expected, Database::"Item Tracking Code", 'R');
    end;
}
