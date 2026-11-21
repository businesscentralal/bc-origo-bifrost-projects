namespace Origo.Bifrost.Projects.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Creates and removes only isolated task-copy fixtures in the owned test tenant.</summary>
codeunit 97177 "Proj. Task Copy Fixture ori"
{
    Access = Internal;

    /// <summary>Seeds two projects, an out-of-range task, budget and billable lines and task dimensions.</summary>
    procedure Seed() Manifest: JsonObject
    var
        Task: Record "Job Task";
        Project: Record Job;
        Dimension: Record Dimension;
        Value: Record "Dimension Value";
        TaskDimension: Record "Job Task Dimension";
        Library: Codeunit "Projects Test Library ori";
        Plan: JsonObject;
        Target: JsonObject;
        SourceNo: Code[20];
        TargetNo: Code[20];
        DimensionCode: Code[20];
    begin
        Plan := Library.NewPlanningRequest('Resource');
        SourceNo := CopyStr(Plan.GetText('projectNo'), 1, 20);
        Task.Get(SourceNo, 'X100');
        Task.Rename(SourceNo, '1000');
        Plan.Replace('taskNo', '1000');
        Plan.Replace('lineType', 'Budget');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Plan), 'Success');
        Plan.Replace('lineNo', 20000);
        Plan.Replace('lineType', 'Billable');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Plan), 'Success');
        AddTask(SourceNo, '1999');
        AddTask(SourceNo, '2000');
        Target := Library.NewProjectRequest();
        TargetNo := CopyStr(Target.GetText('projectNo'), 1, 20);
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Project.Create", Target), 'Success');
        Project.Get(TargetNo);
        Project.Status := Project.Status::Open;
        Project.Modify(true);
        AddTask(TargetNo, 'XKEEP');
        DimensionCode := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Dimension.Code := DimensionCode;
        Dimension.Name := 'X Task copy dimension';
        Dimension.Insert(true);
        Value."Dimension Code" := DimensionCode;
        Value.Code := 'XVALUE';
        Value.Insert(true);
        TaskDimension."Job No." := SourceNo;
        TaskDimension."Job Task No." := '1000';
        TaskDimension."Dimension Code" := DimensionCode;
        TaskDimension."Dimension Value Code" := 'XVALUE';
        TaskDimension.Insert(true);
        Manifest.Add('status', 'Success');
        Manifest.Add('sourceProjectNo', SourceNo);
        Manifest.Add('targetProjectNo', TargetNo);
        Manifest.Add('resourceNo', Plan.GetText('no'));
        Manifest.Add('dimensionCode', DimensionCode);
    end;

    /// <summary>Adds one self-owned posting task.</summary>
    procedure AddTask(ProjectNo: Code[20]; TaskNo: Code[20])
    var
        Task: Record "Job Task";
    begin
        Task.Init();
        Task."Job No." := ProjectNo;
        Task."Job Task No." := TaskNo;
        Task.Description := 'X Task copy test';
        Task."Job Task Type" := Task."Job Task Type"::Posting;
        Task.Insert(true);
    end;

    /// <summary>Seeds posted-entry input for the native ledger-to-planning conversion.</summary>
    procedure SeedLedger(Manifest: JsonObject; Sale: Boolean)
    var
        Entry: Record "Job Ledger Entry";
        Resource: Record Resource;
    begin
        Resource.Get(Manifest.GetText('resourceNo'));
        Entry.LockTable();
        if Entry.FindLast() then;
        Entry."Entry No." += 1;
        Entry.Init();
        Entry."Job No." := CopyStr(Manifest.GetText('sourceProjectNo'), 1, 20);
        Entry."Job Task No." := '1000';
        Entry.Type := Entry.Type::Resource;
        Entry."Entry Type" := Entry."Entry Type"::Usage;
        Entry.Quantity := 3;
        if Sale then begin
            Entry."Entry Type" := Entry."Entry Type"::Sale;
            Entry.Quantity := -3;
        end;
        Entry."No." := Resource."No.";
        Entry.Description := 'X Native ledger conversion';
        Entry."Posting Date" := DMY2Date(16, 10, 2026);
        Entry."Unit of Measure Code" := Resource."Base Unit of Measure";
        Entry."Qty. per Unit of Measure" := 1;
        Entry."Unit Cost" := 7;
        Entry."Unit Cost (LCY)" := 7;
        Entry."Unit Price" := 11;
        Entry."Unit Price (LCY)" := 11;
        Entry."Total Cost" := 21;
        Entry."Total Cost (LCY)" := 21;
        Entry."Total Price" := 33;
        Entry."Total Price (LCY)" := 33;
        Entry.Insert(true);
    end;

    /// <summary>Builds the selected inclusive task-range request.</summary>
    procedure Request(Manifest: JsonObject) Result: JsonObject
    begin
        Result.Add('sourceProjectNo', Manifest.GetText('sourceProjectNo'));
        Result.Add('targetProjectNo', Manifest.GetText('targetProjectNo'));
        Result.Add('fromTaskNo', '1000');
        Result.Add('toTaskNo', '1999');
        Result.Add('expectedCount', 2);
    end;

    /// <summary>Removes the exact self-created records named by the manifest; never registered as a delete operation.</summary>
    procedure Cleanup(Manifest: JsonObject)
    var
        Resource: Record Resource;
        ResourceUnit: Record "Resource Unit of Measure";
        Unit: Record "Unit of Measure";
        BusinessGroup: Record "Gen. Business Posting Group";
        ProductGroup: Record "Gen. Product Posting Group";
        PostingSetup: Record "General Posting Setup";
        Dimension: Record Dimension;
        Value: Record "Dimension Value";
        ResourceNo: Code[20];
        DimensionCode: Code[20];
    begin
        if Manifest.Contains('extraProjectNo') then
            DeleteProject(CopyStr(Manifest.GetText('extraProjectNo'), 1, 20));
        DeleteProject(CopyStr(Manifest.GetText('targetProjectNo'), 1, 20));
        DeleteProject(CopyStr(Manifest.GetText('sourceProjectNo'), 1, 20));
        ResourceNo := CopyStr(Manifest.GetText('resourceNo'), 1, 20);
        Resource.Get(ResourceNo);
        Resource.TestField(Name, 'X Projects resource');
        ResourceUnit.SetRange("Resource No.", ResourceNo);
        ResourceUnit.DeleteAll(false);
        if Unit.Get(Resource."Base Unit of Measure") then
            Unit.Delete(false);
        Resource.Delete(false);
        PostingSetup.SetRange("Gen. Bus. Posting Group", ResourceNo);
        PostingSetup.SetRange("Gen. Prod. Posting Group", ResourceNo);
        PostingSetup.DeleteAll(false);
        if BusinessGroup.Get(ResourceNo) then
            BusinessGroup.Delete(false);
        if ProductGroup.Get(ResourceNo) then
            ProductGroup.Delete(false);
        DimensionCode := CopyStr(Manifest.GetText('dimensionCode'), 1, 20);
        Value.SetRange("Dimension Code", DimensionCode);
        Value.DeleteAll(false);
        if Dimension.Get(DimensionCode) then
            Dimension.Delete(false);
        Commit();
    end;

    local procedure DeleteProject(ProjectNo: Code[20])
    var
        Project: Record Job;
        Task: Record "Job Task";
        Line: Record "Job Planning Line";
        TaskDimension: Record "Job Task Dimension";
        Customer: Record Customer;
        Entry: Record "Job Ledger Entry";
    begin
        Project.Get(ProjectNo);
        Project.TestField(Description, 'X Projects unit test');
        Line.SetRange("Job No.", ProjectNo);
        Line.DeleteAll(false);
        TaskDimension.SetRange("Job No.", ProjectNo);
        TaskDimension.DeleteAll(false);
        Task.SetRange("Job No.", ProjectNo);
        Task.DeleteAll(false);
        Entry.SetRange("Job No.", ProjectNo);
        Entry.DeleteAll(false);
        Project.Delete(false);
        if Customer.Get(ProjectNo) then
            Customer.Delete(false);
    end;
}
