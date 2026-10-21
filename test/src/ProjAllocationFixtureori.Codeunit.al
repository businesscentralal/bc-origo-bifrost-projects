namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Seeds and removes only its own nonfinancial allocation fixtures; shipping licensing and MCP execution remain separate.</summary>
codeunit 97128 "Proj Allocation Fixture ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        ProjectNo: Code[20];
        ResourceNo: Code[20];
        UnitCode: Code[10];
        CapacityEntryNo: Integer;
        ProjectCreated: Boolean;
        ResourceCreated: Boolean;
        CustomerCreated: Boolean;
        CapacityCreated: Boolean;
        GroupCreated: Boolean;
        OtherGroupCreated: Boolean;
        SeedSucceeded: Boolean;
        OwnedOnlyLbl: Label 'Use the worker-owned CRONUS verification company only.', Comment = 'is-IS=Notaðu aðeins eigið CRONUS-sannprófunarfyrirtæki starfsmanns.';
        LastError: Text;

    /// <summary>Creates unique customer/resource/setup/project/planning/capacity records without posting or modifying licence state.</summary>
    procedure Seed(): Text
    var
        Capacity: Record "Res. Capacity Entry";
        Group: Record "Resource Group";
        Resource: Record Resource;
        Library: Codeunit "Projects Test Library ori";
        Request: JsonObject;
        Planning: JsonObject;
        Task: JsonObject;
        Tasks: JsonArray;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        if not CompanyName().StartsWith('CRONUS') then
            Error(OwnedOnlyLbl);
        // Retain the original manifest; never replay an already-started seed operation.
        if ProjectNo <> '' then
            exit(State());
        Request := Library.NewProjectRequest();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        CustomerCreated := true;
        ResourceNo := Library.SeedPlanningMaster(ProjectNo, 'Resource');
        ResourceCreated := true;
        Group."No." := ResourceNo;
        Group.Name := 'Owned allocation fixture group';
        Group.Insert(true);
        GroupCreated := true;
        Group.Init();
        Group."No." := ProjectNo;
        Group.Name := 'Owned other allocation fixture group';
        Group.Insert(true);
        OtherGroupCreated := true;
        Resource.Get(ResourceNo);
        Resource.Validate("Resource Group No.", ResourceNo);
        Resource.Modify(true);
        UnitCode := CopyStr(ResourceNo, 1, MaxStrLen(UnitCode));
        Request.Replace('description', 'Owned allocation MCP fixture');
        Request.Add('startingDate', '2026-01-01');
        Request.Add('endingDate', '2026-01-31');
        Planning.Add('lineNo', 10000);
        Planning.Add('type', 'Resource');
        Planning.Add('no', ResourceNo);
        Planning.Add('lineType', 'Budget');
        Planning.Add('planningDate', '2026-01-05');
        Planning.Add('quantity', 3);
        Planning.Add('unitCost', 7);
        Planning.Add('unitPrice', 14);
        Lines.Add(Planning);
        Task.Add('taskNo', 'X100');
        Task.Add('description', 'Owned allocation fixture task');
        Task.Add('planningLines', Lines);
        Tasks.Add(Task);
        Request.Add('tasks', Tasks);
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Request);
        if Response.GetText('status') <> 'Success' then begin
            Response.WriteTo(LastError);
            exit(State());
        end;
        ProjectCreated := true;
        Clear(Request);
        Request.Add('projectNo', ProjectNo);
        Request.Add('status', 'Open');
        Response := Library.ExecuteNative("Message Type ori"::"Projects.Project.SetStatus", Request);
        if Response.GetText('status') <> 'Success' then begin
            Response.WriteTo(LastError);
            exit(State());
        end;
        Capacity.LockTable();
        if Capacity.FindLast() then
            CapacityEntryNo := Capacity."Entry No.";
        CapacityEntryNo += 1;
        Capacity.Init();
        Capacity."Entry No." := CapacityEntryNo;
        Capacity.Validate("Resource No.", ResourceNo);
        Capacity.Validate(Date, 20260105D);
        Capacity.Validate(Capacity, 8);
        Capacity.Insert(true);
        CapacityCreated := true;
        SeedSucceeded := true;
        exit(State());
    end;

    /// <summary>Removes only records whose successful creation this fixture instance recorded.</summary>
    procedure Cleanup(): Text
    var
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Customer: Record Customer;
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        Group: Record "Resource Group";
        Capacity: Record "Res. Capacity Entry";
        UnitOfMeasure: Record "Unit of Measure";
        BusinessGroup: Record "Gen. Business Posting Group";
        ProductGroup: Record "Gen. Product Posting Group";
        PostingSetup: Record "General Posting Setup";
    begin
        if not CompanyName().StartsWith('CRONUS') then
            Error(OwnedOnlyLbl);
        if ProjectNo = '' then
            exit(State());
        if CapacityCreated and (CapacityEntryNo <> 0) then
            if Capacity.Get(CapacityEntryNo) then
                if Capacity."Resource No." = ResourceNo then
                    Capacity.Delete(true);
        if ProjectCreated then begin
            Planning.SetRange("Job No.", ProjectNo);
            Planning.DeleteAll(false);
            Task.SetRange("Job No.", ProjectNo);
            Task.DeleteAll(false);
            if Project.Get(ProjectNo) then
                Project.Delete(false);
        end;
        if CustomerCreated then
            if Customer.Get(ProjectNo) then
                Customer.Delete(false);
        if ResourceCreated then begin
            ResourceUnit.SetRange("Resource No.", ResourceNo);
            ResourceUnit.DeleteAll(false);
            if Resource.Get(ResourceNo) then
                Resource.Delete(false);
            if PostingSetup.Get(ResourceNo, ResourceNo) then
                PostingSetup.Delete(false);
            if BusinessGroup.Get(ResourceNo) then
                BusinessGroup.Delete(false);
            if ProductGroup.Get(ResourceNo) then
                ProductGroup.Delete(false);
            if UnitOfMeasure.Get(UnitCode) then
                UnitOfMeasure.Delete(false);
        end;
        if GroupCreated then
            if Group.Get(ResourceNo) then
                Group.Delete(false);
        if OtherGroupCreated then
            if Group.Get(ProjectNo) then
                Group.Delete(false);
        SeedSucceeded := false;
        exit(State());
    end;

    /// <summary>Reports real owned keys and remaining row count for independent queue checks and verified cleanup.</summary>
    procedure State(): Text
    var
        Result: JsonObject;
        ResultText: Text;
    begin
        Result.Add('projectNo', ProjectNo);
        Result.Add('resourceNo', ResourceNo);
        Result.Add('resourceGroupNo', ResourceNo);
        Result.Add('otherResourceGroupNo', ProjectNo);
        Result.Add('unitOfMeasureCode', UnitCode);
        Result.Add('capacityEntryNo', CapacityEntryNo);
        Result.Add('taskNo', 'X100');
        Result.Add('planningLineNo', 10000);
        Result.Add('fromDate', '2026-01-05');
        Result.Add('toDate', '2026-01-05');
        Result.Add('expectedCapacity', 8);
        Result.Add('expectedAllocated', 3);
        Result.Add('expectedAvailability', 5);
        Result.Add('seedSucceeded', SeedSucceeded);
        Result.Add('remainingOwnedRecords', Remaining());
        if LastError <> '' then
            Result.Add('seedError', LastError);
        Result.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure Remaining() Result: Integer
    var
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Customer: Record Customer;
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        Group: Record "Resource Group";
        Capacity: Record "Res. Capacity Entry";
        UnitOfMeasure: Record "Unit of Measure";
        BusinessGroup: Record "Gen. Business Posting Group";
        ProductGroup: Record "Gen. Product Posting Group";
        PostingSetup: Record "General Posting Setup";
    begin
        Project.ReadIsolation := IsolationLevel::ReadCommitted;
        Task.ReadIsolation := IsolationLevel::ReadCommitted;
        Planning.ReadIsolation := IsolationLevel::ReadCommitted;
        Customer.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        ResourceUnit.ReadIsolation := IsolationLevel::ReadCommitted;
        Group.ReadIsolation := IsolationLevel::ReadCommitted;
        Capacity.ReadIsolation := IsolationLevel::ReadCommitted;
        UnitOfMeasure.ReadIsolation := IsolationLevel::ReadCommitted;
        BusinessGroup.ReadIsolation := IsolationLevel::ReadCommitted;
        ProductGroup.ReadIsolation := IsolationLevel::ReadCommitted;
        PostingSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        if ProjectNo = '' then
            exit(0);
        if ProjectCreated then begin
            if Project.Get(ProjectNo) then
                Result += 1;
            Task.SetRange("Job No.", ProjectNo);
            Result += Task.Count();
            Planning.SetRange("Job No.", ProjectNo);
            Result += Planning.Count();
        end;
        if CustomerCreated then
            if Customer.Get(ProjectNo) then
                Result += 1;
        if ResourceCreated then begin
            if Resource.Get(ResourceNo) then
                Result += 1;
            ResourceUnit.SetRange("Resource No.", ResourceNo);
            Result += ResourceUnit.Count();
            if CapacityCreated and (CapacityEntryNo <> 0) then
                if Capacity.Get(CapacityEntryNo) then
                    if Capacity."Resource No." = ResourceNo then
                        Result += 1;
            if UnitOfMeasure.Get(UnitCode) then
                Result += 1;
            if BusinessGroup.Get(ResourceNo) then
                Result += 1;
            if ProductGroup.Get(ResourceNo) then
                Result += 1;
            if PostingSetup.Get(ResourceNo, ResourceNo) then
                Result += 1;
        end;
        if GroupCreated then
            if Group.Get(ResourceNo) then
                Result += 1;
        if OtherGroupCreated then
            if Group.Get(ProjectNo) then
                Result += 1;
        exit(Result);
    end;
}
