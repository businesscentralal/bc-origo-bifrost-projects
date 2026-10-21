namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Verifies bounded calendar allocations using fresh resource, capacity and planning fixtures.</summary>
codeunit 97120 "Projects Allocation Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>Happy Path: Capacity And Project Split.</summary>
    [Test]
    procedure HappyPath_CapacityAndProjectSplit()
    var
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        ResourceNo: Code[20];
        ProjectNo: Code[20];
        OtherProjectNo: Code[20];
    begin
        Library.Initialize();
        ResourceNo := NewResource();
        ProjectNo := NewProject();
        OtherProjectNo := NewProject();
        SeedCapacity(ResourceNo, 20260105D, 8);
        SeedPlanning(ResourceNo, ProjectNo, 10000, 20260105D, 3, true, true);
        SeedPlanning(ResourceNo, OtherProjectNo, 10000, 20260105D, 2, true, true);
        SeedPlanning(ResourceNo, ProjectNo, 20000, 20260105D, 100, false, true);
        SeedPlanning(ResourceNo, ProjectNo, 30000, 20260105D, 200, true, false);
        Request := NewRequest(ResourceNo, 'day', '2026-01-05', '2026-01-05');
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Row := Response.GetArray('rows').GetObject(0);
        Assert.AreEqual(8, Row.GetDecimal('capacity'), 'Native capacity total');
        Assert.AreEqual(5, Row.GetDecimal('allocated'), 'Only scheduled open-project base quantities count');
        Assert.AreEqual(3, Row.GetDecimal('availability'), 'Capacity minus allocation');
        Assert.AreEqual(2, Row.GetArray('projects').Count(), 'Project allocation split');
        Request.Add('projectNo', ProjectNo);
        Response := Execute(Request);
        Row := Response.GetArray('rows').GetObject(0);
        Assert.AreEqual(3, Row.GetDecimal('allocated'), 'Project selector scopes allocation');
        Assert.AreEqual(8, Row.GetDecimal('capacity'), 'Project selector preserves resource capacity');
        Assert.AreEqual(1, Row.GetArray('projects').Count(), 'Other project excluded');
    end;

    /// <summary>Edge: No Capacity: Returns Zero.</summary>
    [Test]
    procedure Edge_NoCapacity_ReturnsZero()
    var
        Response: JsonObject;
        Row: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(NewRequest(NewResource(), 'day', '2026-01-05', '2026-01-05'));
        Library.AssertStatus(Response, 'Success');
        Row := Response.GetArray('rows').GetObject(0);
        Assert.AreEqual(0, Row.GetDecimal('capacity'), 'Missing capacity is zero');
        Assert.AreEqual(0, Row.GetDecimal('availability'), 'Empty allocation is zero');
        Assert.AreEqual(0, Row.GetArray('projects').Count(), 'No phantom projects');
    end;

    /// <summary>Invalid Period Type: Returns Actionable Error.</summary>
    [Test]
    procedure InvalidPeriodType_ReturnsActionableError()
    var
        Response: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(NewRequest(NewResource(), 'fortnight', '2026-01-01', '2026-01-31'));
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Unknown period enum');
        Assert.AreEqual('Use day, week, month, quarter or year.', Response.GetText('nextStep'), 'Exact nextStep');
    end;

    /// <summary>Period Limit: Accepts53 Rejects54.</summary>
    [Test]
    procedure PeriodLimit_Accepts53Rejects54()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Library.Initialize();
        Request := NewRequest(NewResource(), 'day', '2026-01-01', '2026-02-22');
        Response := Execute(Request);
        Assert.AreEqual(53, Response.GetArray('rows').Count(), '53 inclusive days are accepted');
        Request.Replace('toDate', '2026-02-23');
        Response := Execute(Request);
        Assert.AreEqual('LimitExceeded', Response.GetText('code'), '54 periods refused');
        Assert.AreEqual('Narrow the date range.', Response.GetText('nextStep'), 'Actionable range refusal');
        Assert.IsFalse(Response.Contains('rows'), 'No partial rows on refusal');
    end;

    /// <summary>Calendar Periods: Clip Inclusive Dates.</summary>
    [Test]
    procedure CalendarPeriods_ClipInclusiveDates()
    var
        Allocation: Codeunit "Projects Allocation ori";
        Response: JsonObject;
        Rows: JsonArray;
    begin
        Library.Initialize();
        Assert.AreEqual(20260111D, Allocation.PeriodEnd(20260107D, 'week'), 'Weeks end Sunday');
        Assert.AreEqual(20260228D, Allocation.PeriodEnd(20260201D, 'month'), 'Nonleap February');
        Assert.AreEqual(20240229D, Allocation.PeriodEnd(20240201D, 'month'), 'Leap February');
        Assert.AreEqual(20260331D, Allocation.PeriodEnd(20260201D, 'quarter'), 'Calendar quarter');
        Assert.AreEqual(20261231D, Allocation.PeriodEnd(20260201D, 'year'), 'Calendar year');
        Response := Execute(NewRequest(NewResource(), 'month', '2026-01-30', '2026-02-02'));
        Rows := Response.GetArray('rows');
        Assert.AreEqual(2, Rows.Count(), 'Cross-month partial periods');
        Assert.AreEqual('2026-01-30', Rows.GetObject(0).GetText('fromDate'), 'First period clipped');
        Assert.AreEqual('2026-01-31', Rows.GetObject(0).GetText('toDate'), 'January boundary');
        Assert.AreEqual('2026-02-02', Rows.GetObject(1).GetText('toDate'), 'Last period clipped');
    end;

    /// <summary>Input Refusals: Reject Unknown Missing And Wrong Types.</summary>
    [Test]
    procedure InputRefusals_RejectUnknownMissingAndWrongTypes()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Library.Initialize();
        Request := NewRequest(NewResource(), 'day', '2026-01-01', '2026-01-01');
        Request.Add('skip', 1);
        Response := Execute(Request);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'Unknown keys refused');
        Request.Remove('skip');
        Request.Remove('periodType');
        Response := Execute(Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Required periodType');
        Request.Add('periodType', 1);
        Response := Execute(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Wrong JSON type');
        Request.Replace('periodType', 'day');
        Request.Replace('fromDate', 'not-a-date');
        Response := Execute(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Invalid ISO date');
    end;

    /// <summary>Missing Explicit Resource: Is Not Empty Success.</summary>
    [Test]
    procedure MissingExplicitResource_IsNotEmptySuccess()
    var
        Response: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(NewRequest(NewNumber(), 'day', '2026-01-01', '2026-01-01'));
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Exact missing resource must refuse');
        Assert.AreEqual('resourceNo', Response.GetText('parameter'), 'Identifies exact missing selector');
    end;

    /// <summary>Conflicting Group: Refuses Resource From Another Group.</summary>
    [Test]
    procedure ConflictingGroup_RefusesResourceFromAnotherGroup()
    var
        ResourceGroup: Record "Resource Group";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Library.Initialize();
        ResourceGroup."No." := NewNumber();
        ResourceGroup.Insert(true);
        Request := NewRequest(NewResource(), 'day', '2026-01-01', '2026-01-01');
        Request.Add('resourceGroupNo', ResourceGroup."No.");
        Response := Execute(Request);
        Assert.AreEqual('ConflictingIdentifiers', Response.GetText('code'), 'Mismatched exact selectors');
    end;

    /// <summary>Reversed Dates: Return Invalid Parameter.</summary>
    [Test]
    procedure ReversedDates_ReturnInvalidParameter()
    var
        Response: JsonObject;
    begin
        Library.Initialize();
        Response := Execute(NewRequest(NewResource(), 'day', '2026-02-01', '2026-01-01'));
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Reversed range refused');
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Allocation: Codeunit "Projects Allocation ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.ResourceAllocation.Get";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Allocation.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure NewRequest(ResourceNo: Code[20]; PeriodType: Text; FirstDate: Text; LastDate: Text) Request: JsonObject
    begin
        Request.Add('resourceNo', ResourceNo);
        Request.Add('periodType', PeriodType);
        Request.Add('fromDate', FirstDate);
        Request.Add('toDate', LastDate);
    end;

    local procedure NewNumber(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure NewResource(): Code[20]
    var
        Resource: Record Resource;
    begin
        Resource."No." := NewNumber();
        Resource.Insert(true);
        exit(Resource."No.");
    end;

    local procedure NewProject(): Code[20]
    var
        Project: Record Job;
    begin
        Project."No." := NewNumber();
        Project.Insert(true);
        exit(Project."No.");
    end;

    local procedure SeedCapacity(ResourceNo: Code[20]; PostingDate: Date; CapacityValue: Decimal)
    var
        Capacity: Record "Res. Capacity Entry";
        EntryNo: Integer;
    begin
        Capacity.LockTable();
        if Capacity.FindLast() then
            EntryNo := Capacity."Entry No.";
        Capacity.Init();
        Capacity."Entry No." := EntryNo + 1;
        Capacity."Resource No." := ResourceNo;
        Capacity.Date := PostingDate;
        Capacity.Capacity := CapacityValue;
        Capacity.Insert(true);
    end;

    local procedure SeedPlanning(ResourceNo: Code[20]; ProjectNo: Code[20]; LineNo: Integer; PlanningDate: Date; BaseQuantity: Decimal; Schedule: Boolean; OpenProject: Boolean)
    var
        Planning: Record "Job Planning Line";
    begin
        Planning."Job No." := ProjectNo;
        Planning."Job Task No." := 'X100';
        Planning."Line No." := LineNo;
        Planning.Type := Planning.Type::Resource;
        Planning."No." := ResourceNo;
        Planning."Planning Date" := PlanningDate;
        Planning."Quantity (Base)" := BaseQuantity;
        Planning."Schedule Line" := Schedule;
        if OpenProject then
            Planning.Status := Planning.Status::Order
        else
            Planning.Status := Planning.Status::Quote;
        Planning.Insert(false);
    end;
}
