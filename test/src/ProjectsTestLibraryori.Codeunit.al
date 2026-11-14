namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using System.Security.User;
using Microsoft.Finance.Dimension;
using Microsoft.Projects.Project.WIP;
using Microsoft.Projects.Project.Ledger;

/// <summary>Owns isolated native unit-test data. These component tests do not assert feature licensing or shipping MCP acceptance.</summary>
codeunit 97102 "Projects Test Library ori"
{
    Access = Internal;
    /// <summary>Initializes only the owned test company's missing project setup.</summary>
    procedure Initialize()
    var
        JobsSetup: Record "Jobs Setup";
        Setup: Record "Projects Setup ori";
    begin
        if not JobsSetup.Get() then begin
            JobsSetup.Init();
            JobsSetup.Insert(true);
        end;
        AllowPostingAroundWorkDate();
        DeleteOwnedWIPDimensions();
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(true);
    end;
    local procedure AllowPostingAroundWorkDate()
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        UserSetup: Record "User Setup";
        TargetFrom: Date;
        TargetTo: Date;
    begin
        TargetFrom := CalcDate('<-1Y>', WorkDate());
        TargetTo := CalcDate('<1Y>', WorkDate());
        if Today() < TargetFrom then
            TargetFrom := CalcDate('<-1Y>', Today());
        if Today() > TargetTo then
            TargetTo := CalcDate('<1Y>', Today());
        if UserSetup.Get(UserId()) and UserSetupGovernsPostingDates(UserSetup) then begin
            if PostingWindowExcludes(
                UserSetup."Allow Posting From", UserSetup."Allow Posting To",
                UserSetup."Allow Posting From DateFormula", UserSetup."Allow Posting To DateFormula", WorkDate())
            then
                SetUserPostingWindow(UserSetup, TargetFrom, TargetTo);
            exit;
        end;
        GeneralLedgerSetup.Get();
        if PostingWindowExcludes(
            GeneralLedgerSetup."Allow Posting From", GeneralLedgerSetup."Allow Posting To",
            GeneralLedgerSetup."Allow Posting From DateFormula", GeneralLedgerSetup."Allow Posting To DateFormula", WorkDate())
        then
            SetGeneralLedgerPostingWindow(GeneralLedgerSetup, TargetFrom, TargetTo);
    end;

    local procedure UserSetupGovernsPostingDates(UserSetup: Record "User Setup"): Boolean
    begin
        exit((UserSetup."Allow Posting From" <> 0D) or (UserSetup."Allow Posting To" <> 0D) or
            (Format(UserSetup."Allow Posting From DateFormula") <> '') or (Format(UserSetup."Allow Posting To DateFormula") <> ''));
    end;

    local procedure PostingWindowExcludes(AllowFrom: Date; AllowTo: Date; FromFormula: DateFormula; ToFormula: DateFormula; DateToTest: Date): Boolean
    var
        EffectiveFrom: Date;
        EffectiveTo: Date;
    begin
        EffectiveFrom := AllowFrom;
        EffectiveTo := AllowTo;
        if Format(FromFormula) <> '' then
            EffectiveFrom := CalcDate(FromFormula, Today());
        if Format(ToFormula) <> '' then
            EffectiveTo := CalcDate(ToFormula, Today());
        if EffectiveTo = 0D then
            EffectiveTo := DMY2Date(31, 12, 9999);
        exit(not (DateToTest in [EffectiveFrom .. EffectiveTo]));
    end;

    local procedure SetUserPostingWindow(var UserSetup: Record "User Setup"; TargetFrom: Date; TargetTo: Date)
    begin
        Evaluate(UserSetup."Allow Posting From DateFormula", '');
        Evaluate(UserSetup."Allow Posting To DateFormula", '');
        RaisePostingToBeforeLoweringFrom(UserSetup."Allow Posting From", UserSetup."Allow Posting To", TargetFrom, TargetTo);
        if (UserSetup."Allow Posting From" <> 0D) and (UserSetup."Allow Posting From" > TargetFrom) then
            UserSetup.Validate("Allow Posting From", TargetFrom);
        if (UserSetup."Allow Posting To" <> 0D) and (UserSetup."Allow Posting To" < TargetTo) then
            UserSetup.Validate("Allow Posting To", TargetTo);
        UserSetup.Modify(true);
    end;

    local procedure SetGeneralLedgerPostingWindow(var GeneralLedgerSetup: Record "General Ledger Setup"; TargetFrom: Date; TargetTo: Date)
    begin
        Evaluate(GeneralLedgerSetup."Allow Posting From DateFormula", '');
        Evaluate(GeneralLedgerSetup."Allow Posting To DateFormula", '');
        RaisePostingToBeforeLoweringFrom(GeneralLedgerSetup."Allow Posting From", GeneralLedgerSetup."Allow Posting To", TargetFrom, TargetTo);
        if (GeneralLedgerSetup."Allow Posting From" <> 0D) and (GeneralLedgerSetup."Allow Posting From" > TargetFrom) then
            GeneralLedgerSetup.Validate("Allow Posting From", TargetFrom);
        if (GeneralLedgerSetup."Allow Posting To" <> 0D) and (GeneralLedgerSetup."Allow Posting To" < TargetTo) then
            GeneralLedgerSetup.Validate("Allow Posting To", TargetTo);
        GeneralLedgerSetup.Modify(true);
    end;

    local procedure RaisePostingToBeforeLoweringFrom(AllowFrom: Date; var AllowTo: Date; TargetFrom: Date; TargetTo: Date)
    var
        BridgeTo: Date;
    begin
        if (AllowTo = 0D) or (AllowTo >= TargetFrom) then
            exit;
        BridgeTo := TargetTo;
        if (AllowFrom <> 0D) and (AllowFrom > BridgeTo) then
            BridgeTo := AllowFrom;
        AllowTo := BridgeTo;
    end;

    /// <summary>Creates a fresh customer and project number for every test.</summary>
    procedure NewProjectRequest() Request: JsonObject
    var
        Customer: Record Customer;
        ProjectNo: Code[20];
    begin
        Initialize();
        ProjectNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(ProjectNo));
        Customer.Init();
        Customer."No." := ProjectNo;
        Customer.Name := 'X Projects unit test';
        Customer.Insert(true);
        Request.Add('projectNo', ProjectNo);
        Request.Add('billToCustomerNo', Customer."No.");
        Request.Add('description', 'X Projects unit test');
    end;
    /// <summary>Runs the native component after validation without initializing licence or backend data.</summary>
    procedure ExecuteNative(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Dispatch: Codeunit "Projects Write ori";
        Kind: Text;
        Operation: Text;
        TypeName: Text;
        Names: List of [Text];
        Ordinals: List of [Integer];
        Parts: List of [Text];
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        TypeName := Names.Get(Ordinals.IndexOf(MessageType.AsInteger()));
        Parts := TypeName.Split('.');
        Kind := Parts.Get(2);
        Operation := Parts.Get(3);
        Commit();
        Dispatch.Execute(TempArgument, Kind, Operation);
        Response := TempArgument.GetResponseJson();
    end;
    /// <summary>Executes the native component inside the caller's transaction without a Commit.</summary>
    procedure ExecuteNativeInTransaction(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Dispatch: Codeunit "Projects Write ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Dispatch.Execute(TempArgument, 'Project', 'Create');
        Response := TempArgument.GetResponseJson();
    end;

    /// <summary>Requires the expected status from the actual JSON response.</summary>
    procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Assert: Codeunit "Library Assert";
    begin
        Assert.AreEqual(Expected, Response.GetText('status'), 'Unexpected native component response: ' + Format(Response));
    end;
    /// <summary>Creates every business master used by a planning-line test; no demo item/resource/account is reused.</summary>
    procedure SeedPlanningMaster(CustomerNo: Code[20]; Kind: Text): Code[20]
    var
        Customer: Record Customer;
        GenBusGroup: Record "Gen. Business Posting Group";
        GenProdGroup: Record "Gen. Product Posting Group";
        PostingSetup: Record "General Posting Setup";
        UnitOfMeasure: Record "Unit of Measure";
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        Account: Record "G/L Account";
        CodeValue: Code[20];
    begin
        CodeValue := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(CodeValue));
        GenBusGroup.Init();
        GenBusGroup.Code := CodeValue;
        GenBusGroup.Description := 'X Projects native test';
        GenBusGroup.Insert(true);
        GenProdGroup.Init();
        GenProdGroup.Code := CodeValue;
        GenProdGroup.Description := 'X Projects native test';
        GenProdGroup.Insert(true);
        PostingSetup.Init();
        PostingSetup."Gen. Bus. Posting Group" := CodeValue;
        PostingSetup."Gen. Prod. Posting Group" := CodeValue;
        PostingSetup.Insert(true);
        Customer.Get(CustomerNo);
        Customer.Validate("Gen. Bus. Posting Group", CodeValue);
        Customer.Modify(true);
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := CopyStr(CodeValue, 1, MaxStrLen(UnitOfMeasure.Code));
        UnitOfMeasure.Description := 'X Projects unit';
        UnitOfMeasure.Insert(true);
        case Kind of
            'Item':
                begin
                    Item.Init();
                    Item."No." := CodeValue;
                    Item.Description := 'X Projects item';
                    Item.Type := Item.Type::"Non-Inventory";
                    Item."Gen. Prod. Posting Group" := CodeValue;
                    Item."Base Unit of Measure" := UnitOfMeasure.Code;
                    Item.Insert(true);
                    ItemUnit.Init();
                    ItemUnit."Item No." := Item."No.";
                    ItemUnit.Code := UnitOfMeasure.Code;
                    ItemUnit."Qty. per Unit of Measure" := 1;
                    ItemUnit.Insert(true);
                end;
            'Resource':
                begin
                    Resource.Init();
                    Resource."No." := CodeValue;
                    Resource.Name := 'X Projects resource';
                    Resource."Gen. Prod. Posting Group" := CodeValue;
                    Resource."Base Unit of Measure" := UnitOfMeasure.Code;
                    Resource.Insert(true);
                    ResourceUnit.Init();
                    ResourceUnit."Resource No." := Resource."No.";
                    ResourceUnit.Code := UnitOfMeasure.Code;
                    ResourceUnit."Qty. per Unit of Measure" := 1;
                    ResourceUnit.Insert(true);
                end;
            'G/L Account':
                begin
                    Account.Init();
                    Account."No." := CodeValue;
                    Account.Name := 'X Projects account';
                    Account."Account Type" := Account."Account Type"::Posting;
                    Account."Direct Posting" := true;
                    Account."Gen. Bus. Posting Group" := CodeValue;
                    Account."Gen. Prod. Posting Group" := CodeValue;
                    Account.Insert(true);
                end;
        end;
        exit(CodeValue);
    end;

    /// <summary>Creates a project and posting task, then returns a complete self-seeded planning-line request.</summary>
    procedure NewPlanningRequest(Kind: Text) PlanningRequest: JsonObject
    var
        ProjectRequest: JsonObject;
        TaskRequest: JsonObject;
        MasterNo: Code[20];
    begin
        ProjectRequest := NewProjectRequest();
        MasterNo := SeedPlanningMaster(CopyStr(ProjectRequest.GetText('billToCustomerNo'), 1, 20), Kind);
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Project.Create", ProjectRequest), 'Success');
        TaskRequest.Add('projectNo', ProjectRequest.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'X100');
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        PlanningRequest.Add('projectNo', ProjectRequest.GetText('projectNo'));
        PlanningRequest.Add('taskNo', 'X100');
        PlanningRequest.Add('lineNo', 10000);
        PlanningRequest.Add('type', Kind);
        PlanningRequest.Add('no', MasterNo);
        PlanningRequest.Add('lineType', 'Both Budget and Billable');
        PlanningRequest.Add('planningDate', '2026-10-16');
        PlanningRequest.Add('quantity', 3);
        PlanningRequest.Add('unitCost', 7);
        PlanningRequest.Add('unitPrice', 11);
    end;

    /// <summary>Creates isolated economic WIP data with owned posting accounts and required dimensions; never changes licence state.</summary>
    procedure NewEconomicWIPRequest() Request: JsonObject
    begin
        Request := NewEconomicWIPRequest(true);
    end;

    /// <summary>Creates isolated economic WIP data. The prompt flag is false for non-test callers that cannot answer the native dimension confirmation.</summary>
    procedure NewEconomicWIPRequest(ExpectDimensionPrompt: Boolean) Request: JsonObject
    var
        Project: Record Job;
        Task: Record "Job Task";
        Method: Record "Job WIP Method";
        Group: Record "Job Posting Group";
        Ledger: Record "Job Ledger Entry";
        Account: Record "G/L Account";
        Account2: Record "G/L Account";
        GLSetup: Record "General Ledger Setup";
        ProjectRequest: JsonObject;
        TaskRequest: JsonObject;
        CodeValue: Code[20];
    begin
        ProjectRequest := NewProjectRequest();
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Project.Create", ProjectRequest), 'Success');
        CodeValue := CopyStr(ProjectRequest.GetText('projectNo'), 1, 20);
        Method.Code := CodeValue;
        Method.Description := 'X native economic WIP';
        Method.Valid := true;
        Method."Recognized Costs" := Method."Recognized Costs"::"Usage (Total Cost)";
        Method."Recognized Sales" := Method."Recognized Sales"::"Usage (Total Price)";
        Method.Insert(true);
        Account."No." := CodeValue;
        Account.Name := 'X WIP expense';
        Account.Insert(true);
        Account2."No." := CopyStr('Y' + CodeValue, 1, 20);
        Account2.Name := 'X WIP balance';
        Account2.Insert(true);
        Group.Code := CodeValue;
        Group."WIP Costs Account" := Account2."No.";
        Group."WIP Accrued Costs Account" := Account2."No.";
        Group."Job Costs Applied Account" := Account."No.";
        Group."Job Costs Adjustment Account" := Account."No.";
        // Preserve distinct applied/recognized costs for the report nonzero WIP regression.
        Group."Recognized Costs Account" := Account2."No.";
        Group."Recognized Sales Account" := Account."No.";
        Group."Job Sales Applied Account" := Account."No.";
        Group."Job Sales Adjustment Account" := Account."No.";
        Group."WIP Accrued Sales Account" := Account2."No.";
        Group."WIP Invoiced Sales Account" := Account2."No.";
        Group.Insert(true);
        Project.Get(CodeValue);
        Project.Validate("WIP Method", Method.Code);
        Project.Validate("Job Posting Group", Group.Code);
        Project."WIP Posting Method" := Project."WIP Posting Method"::"Per Job";
        Project.Modify(true);
        TaskRequest.Add('projectNo', CodeValue);
        TaskRequest.Add('taskNo', 'X100');
        AssertStatus(ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        Task.Get(CodeValue, 'X100');
        Task."WIP-Total" := Task."WIP-Total"::Total;
        Task.Modify(true);
        SeedRequiredDimensions(CodeValue, 'X100', ExpectDimensionPrompt);
        if Ledger.FindLast() then;
        Ledger."Entry No." += 1;
        Ledger.Init();
        Ledger."Job No." := CodeValue;
        Ledger."Job Task No." := 'X100';
        Ledger."Entry Type" := Ledger."Entry Type"::Usage;
        Ledger.Type := Ledger.Type::Resource;
        Ledger."Posting Date" := DMY2Date(16, 10, 2026);
        Ledger.Quantity := 3;
        Ledger."Total Cost (LCY)" := 21;
        Ledger."Total Price (LCY)" := 42;
        Ledger.Insert(true);
        GLSetup.Get();
        GLSetup."Allow Posting From" := DMY2Date(1, 1, 2026);
        GLSetup."Allow Posting To" := DMY2Date(31, 12, 2026);
        GLSetup.Modify(true);
        Request.Add('projectNo', CodeValue);
        Request.Add('postingDate', '2026-10-16');
        Request.Add('documentNo', CodeValue);
    end;

    /// <summary>Removes blank-number Job dimensions created by this library and commits that delete.</summary>
    procedure RemoveOwnedWIPDimensions()
    begin
        if DeleteOwnedWIPDimensions() then
            Commit();
    end;

    local procedure SeedRequiredDimensions(ProjectNo: Code[20]; TaskNo: Code[20]; ExpectDimensionPrompt: Boolean)
    var
        Required: Record "Default Dimension";
        OwnedDefault: Record "Default Dimension";
        Value: Record "Dimension Value";
        TaskDimension: Record "Job Task Dimension";
    begin
        // Respect native mandatory-dimension setup without borrowing demo values or weakening its rules.
        Required.SetRange("Table ID", Database::Job);
        Required.SetRange("No.", '');
        EnsureOwnedJobDimension(ProjectNo, ExpectDimensionPrompt);
        if Required.FindSet() then
            repeat
                if Required."Value Posting" in [Required."Value Posting"::"Code Mandatory", Required."Value Posting"::"Same Code"] then begin
                    if not Value.Get(Required."Dimension Code", ProjectNo) then begin
                        Value.Init();
                        Value.Validate("Dimension Code", Required."Dimension Code");
                        Value.Validate(Code, ProjectNo);
                        Value.Name := 'X owned WIP posting dimension';
                        Value.Insert(true);
                    end;
                    // Configure this owned test company's native constraint with self-created values.
                    // Keep Same Code / Code Mandatory unchanged, and narrow an existing allowed filter to this exact value.
                    if Required."Value Posting" = Required."Value Posting"::"Same Code" then
                        Required.Validate("Dimension Value Code", Value.Code);
                    if Required."Allowed Values Filter" <> '' then
                        Required.Validate("Allowed Values Filter", Value.Code);
                    Required.Modify(true);
                    OwnedDefault.Init();
                    OwnedDefault.Validate("Table ID", Database::Job);
                    OwnedDefault.Validate("No.", ProjectNo);
                    OwnedDefault.Validate("Dimension Code", Required."Dimension Code");
                    OwnedDefault.Validate("Dimension Value Code", Value.Code);
                    OwnedDefault.Validate("Value Posting", Required."Value Posting");
                    OwnedDefault.Insert(true);
                    if TaskDimension.Get(ProjectNo, TaskNo, Required."Dimension Code") then begin
                        TaskDimension.Validate("Dimension Value Code", Value.Code);
                        TaskDimension.Modify(true);
                    end else begin
                        TaskDimension.Init();
                        TaskDimension.Validate("Job No.", ProjectNo);
                        TaskDimension.Validate("Job Task No.", TaskNo);
                        TaskDimension.Validate("Dimension Code", Required."Dimension Code");
                        TaskDimension.Validate("Dimension Value Code", Value.Code);
                        TaskDimension.Insert(true);
                    end;
                end;
            until Required.Next() = 0;
    end;

    local procedure EnsureOwnedJobDimension(ProjectNo: Code[20]; ExpectDimensionPrompt: Boolean)
    var
        Required: Record "Default Dimension";
        Dimension: Record Dimension;
        Value: Record "Dimension Value";
        DimCode: Code[20];
        ValueCode: Code[20];
    begin
        // Companies that already enforce a blank-number Job dimension keep that rule. This only fills the gap.
        Required.SetRange("Table ID", Database::Job);
        Required.SetRange("No.", '');
        Required.SetFilter("Value Posting", '%1|%2', Required."Value Posting"::"Code Mandatory", Required."Value Posting"::"Same Code");
        if not Required.IsEmpty() then
            exit;
        DimCode := CopyStr('XWIP' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(DimCode));
        Dimension.Init();
        Dimension.Validate(Code, DimCode);
        Dimension.Name := 'X owned WIP dimension';
        Dimension.Insert(true);
        ValueCode := ProjectNo;
        if ExpectDimensionPrompt then
            ValueCode := 'XSEED';
        Value.Init();
        Value.Validate("Dimension Code", DimCode);
        Value.Validate(Code, ValueCode);
        Value.Name := 'X owned WIP posting dimension';
        Value.Insert(true);
        Required.Init();
        Required.Validate("Table ID", Database::Job);
        Required.Validate("No.", '');
        Required.Validate("Dimension Code", DimCode);
        Required.Validate("Value Posting", Required."Value Posting"::"Code Mandatory");
        Required.Insert(true);
        Required.Validate("Allowed Values Filter", ValueCode);
        Required.Modify(true);
    end;

    local procedure DeleteOwnedWIPDimensions(): Boolean
    var
        Dimension: Record Dimension;
        DefaultDimension: Record "Default Dimension";
        DimValuePerAccount: Record "Dim. Value per Account";
        TaskDimension: Record "Job Task Dimension";
        Removed: Boolean;
    begin
        Dimension.SetFilter(Code, 'XWIP*');
        if Dimension.FindSet() then
            repeat
                TaskDimension.SetRange("Dimension Code", Dimension.Code);
                if not TaskDimension.IsEmpty() then
                    TaskDimension.DeleteAll(true);
                DimValuePerAccount.SetRange("Dimension Code", Dimension.Code);
                if not DimValuePerAccount.IsEmpty() then
                    DimValuePerAccount.DeleteAll(true);
                DefaultDimension.SetRange("Dimension Code", Dimension.Code);
                if not DefaultDimension.IsEmpty() then begin
                    DefaultDimension.DeleteAll(true);
                    Removed := true;
                end;
                // Posted WIP keeps the dimension value in a dimension set, so the value and dimension stay.
            until Dimension.Next() = 0;
        exit(Removed);
    end;

}
