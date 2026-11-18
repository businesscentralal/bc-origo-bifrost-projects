namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Ledger;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Story 51: verifies capacity, time-sheet hours, usage and the read-only contract.</summary>
codeunit 97161 "Projects Capacity Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>All quantity sources are independently filtered and remain unchanged.</summary>
    [Test]
    procedure Scenario_AC01_AC02_Quantities_FilteredAndReadOnly()
    var
        Resource: Record Resource;
        Capacity: Record "Res. Capacity Entry";
        Detail: Record "Time Sheet Detail";
        Archive: Record "Time Sheet Detail Archive";
        Usage: Record "Res. Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        BeforeCounts: Text;
        BeforeResource: DateTime;
        ResourceNo: Code[20];
        OtherNo: Code[20];
    begin
        // Story #51, AC01/AC02 | Time: fixed work/posting dates; Today/WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] Owned data in and outside the selected resource and date range.
        ResourceNo := NewResource('');
        OtherNo := NewResource('');
        SeedCapacity(ResourceNo, 20260105D, 8);
        SeedCapacity(ResourceNo, 20260106D, 100);
        SeedCapacity(OtherNo, 20260105D, 200);
        SeedTime(ResourceNo, 20260105D, 3, false);
        SeedTime(ResourceNo, 20260105D, 2, true);
        SeedTime(ResourceNo, 20260106D, 100, false);
        SeedTime(OtherNo, 20260105D, 200, true);
        SeedUsage(ResourceNo, 20260105D, 6, false);
        SeedUsage(ResourceNo, 20260105D, -1, false);
        SeedUsage(ResourceNo, 20260105D, 100, true);
        SeedUsage(ResourceNo, 20260106D, 100, false);
        SeedUsage(OtherNo, 20260105D, 200, false);
        BeforeCounts := StrSubstNo('%1/%2/%3/%4', Capacity.Count(), Detail.Count(), Archive.Count(), Usage.Count());
        Resource.Get(ResourceNo);
        BeforeResource := Resource.SystemModifiedAt;
        Request := NewRequest(ResourceNo, 'day', '2026-01-05', '2026-01-05');
        // [WHEN] The same request is repeated.
        Response := Execute(Request);
        Row := Response.GetArray('rows').GetObject(0);
        // [THEN] Corrections count; sales, other dates/resources and non-base quantities do not.
        Assert.AreEqual('Success', Response.GetText('status'), 'Read succeeds');
        Assert.AreEqual(1, Response.GetArray('rows').Count(), 'One resource and one period');
        AssertRow(Row, ResourceNo, '2026-01-05', '2026-01-05', 8, 5, 5);
        Assert.AreEqual(Format(Response), Format(Execute(Request)), 'Read is idempotent');
        Assert.AreEqual(BeforeCounts, StrSubstNo('%1/%2/%3/%4', Capacity.Count(), Detail.Count(), Archive.Count(), Usage.Count()), 'Read must not insert/delete business rows');
        Resource.Get(ResourceNo);
        Assert.AreEqual(BeforeResource, Resource.SystemModifiedAt, 'Resource is not modified');
        Capacity.SetRange("Resource No.", ResourceNo);
        Capacity.CalcSums(Capacity);
        Assert.AreEqual(108, Capacity.Capacity, 'Source capacity is unchanged');
        Detail.SetRange("Resource No.", ResourceNo);
        Detail.CalcSums(Quantity);
        Assert.AreEqual(103, Detail.Quantity, 'Source time sheets are unchanged');
        Archive.SetRange("Resource No.", ResourceNo);
        Archive.CalcSums(Quantity);
        Assert.AreEqual(2, Archive.Quantity, 'Source archive is unchanged');
        Usage.SetRange("Resource No.", ResourceNo);
        Usage.CalcSums("Quantity (Base)");
        Assert.AreEqual(205, Usage."Quantity (Base)", 'Source usage is unchanged');
    end;

    /// <summary>Calendar clipping matches ResourceAllocation, including leap days.</summary>
    [Test]
    procedure Scenario_AC03_CalendarPeriods_MatchAllocation()
    var
        Allocation: Codeunit "Projects Allocation ori";
        Response: JsonObject;
        PeriodType: Text;
        ResourceNo: Code[20];
    begin
        // Story #51, AC03 | Time: fixed leap-year boundary | Risk: shared PeriodEnd contract
        Initialize();
        // [GIVEN] A resource and a mid-period start.
        ResourceNo := NewResource('');
        foreach PeriodType in 'week,month,quarter,year'.Split(',') do begin
            // [WHEN] Reading up to a date in the following year.
            Response := Execute(NewRequest(ResourceNo, PeriodType, '2024-02-28', '2025-01-02'));
            // [THEN] The first boundary equals Allocation; the last is clipped.
            Assert.AreEqual('2024-02-28', Response.GetArray('rows').GetObject(0).GetText('fromDate'), 'Clipped first boundary');
            Assert.AreEqual(Format(Allocation.PeriodEnd(20240228D, PeriodType), 0, 9), Response.GetArray('rows').GetObject(0).GetText('toDate'), 'Same calendar shape');
            Assert.AreEqual('2025-01-02', Response.GetArray('rows').GetObject(Response.GetArray('rows').Count() - 1).GetText('toDate'), 'Clipped last boundary');
        end;
    end;

    /// <summary>Quantities are assigned to their work/posting periods without crossing the requested boundary.</summary>
    [Test]
    procedure Scenario_AC01_MonthBoundary_SplitsQuantities()
    var
        Response: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #51, AC01 | Time: fixed leap-day/month boundary | Risk: None
        Initialize();
        // [GIVEN] Distinct quantities inside each month and outside the range.
        ResourceNo := NewResource('');
        SeedCapacity(ResourceNo, 20240228D, 8);
        SeedCapacity(ResourceNo, 20240229D, 8);
        SeedCapacity(ResourceNo, 20240301D, 4);
        SeedCapacity(ResourceNo, 20240302D, 100);
        SeedTime(ResourceNo, 20240229D, 5, false);
        SeedTime(ResourceNo, 20240301D, 2, true);
        SeedUsage(ResourceNo, 20240301D, 7, false);
        // [WHEN] Reading a clipped two-month range.
        Response := Execute(NewRequest(ResourceNo, 'month', '2024-02-28', '2024-03-01'));
        // [THEN] Work dates and posting dates select their own period.
        Assert.AreEqual(2, Response.GetArray('rows').Count(), 'Two months');
        AssertRow(Response.GetArray('rows').GetObject(0), ResourceNo, '2024-02-28', '2024-02-29', 16, 5, 0);
        AssertRow(Response.GetArray('rows').GetObject(1), ResourceNo, '2024-03-01', '2024-03-01', 4, 2, 7);
    end;

    /// <summary>Missing entries return zeros, including the maximum supported date.</summary>
    [Test]
    procedure Scenario_AC01_EmptyResource_ReturnsZero()
    var
        ResourceNo: Code[20];
        Response: JsonObject;
        PeriodType: Text;
    begin
        // Story #51, AC01 | Time: fixed last date supported by BC | Risk: None
        Initialize();
        // [GIVEN] A resource without entries.
        ResourceNo := NewResource('');
        // [WHEN] Reading a single day at the date boundary.
        foreach PeriodType in 'day,week,month,quarter,year'.Split(',') do begin
            Response := Execute(NewRequest(ResourceNo, PeriodType, '9999-12-31', '9999-12-31'));
            // [THEN] No overflow or fabricated quantity.
            AssertRow(Response.GetArray('rows').GetObject(0), ResourceNo, '9999-12-31', '9999-12-31', 0, 0, 0);
        end;
    end;

    /// <summary>Group filters exclude other resources and empty groups return no rows.</summary>
    [Test]
    procedure Scenario_AC01_GroupFilter_SelectsMembers()
    var
        Group: Record "Resource Group";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
    begin
        // Story #51, AC01 | Time: fixed dates | Risk: None
        Initialize();
        // [GIVEN] A fresh group, one member and one unrelated resource.
        Group."No." := NewNumber();
        Group.Insert(false);
        ResourceNo := NewResource(Group."No.");
        NewResource('');
        Request := NewRequest('', 'day', '2026-01-05', '2026-01-05');
        Request.Add('resourceGroupNo', Group."No.");
        // [WHEN] Selecting by group alone.
        Response := Execute(Request);
        // [THEN] Only that member is returned.
        Assert.AreEqual(1, Response.GetArray('rows').Count(), 'One group member');
        Assert.AreEqual(ResourceNo, Response.GetArray('rows').GetObject(0).GetText('resourceNo'), 'Correct member');
        Group."No." := NewNumber();
        Group.Insert(false);
        Request.Replace('resourceGroupNo', Group."No.");
        Response := Execute(Request);
        Assert.AreEqual(0, Response.GetArray('rows').Count(), 'Empty group returns no rows');
        Request.Replace('resourceNo', ResourceNo);
        AssertRefusal(Request, 'ConflictingIdentifiers', 'resourceGroupNo');
    end;

    /// <summary>The inclusive 53-period boundary is shared with Allocation.</summary>
    [Test]
    procedure Scenario_AC03_PeriodLimit_Accepts53Refuses54()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #51, AC03 | Time: fixed 53/54-day range | Risk: None
        Initialize();
        // [GIVEN] Exactly 53 days.
        Request := NewRequest(NewResource(''), 'day', '2026-01-01', '2026-02-22');
        // [WHEN] Reading then extending by a day.
        Response := Execute(Request);
        // [THEN] Boundary is accepted, overflow refused without partial rows.
        Assert.AreEqual(53, Response.GetArray('rows').Count(), '53 periods');
        Request.Replace('toDate', '2026-02-23');
        AssertRefusal(Request, 'LimitExceeded', 'toDate');
    end;

    /// <summary>Missing, unknown, null and incorrectly typed input receives typed refusals.</summary>
    [Test]
    procedure Scenario_AC04_InvalidInput_ReturnsActionableErrors()
    var
        Request: JsonObject;
        NullValue: JsonValue;
        ResourceNo: Code[20];
    begin
        // Story #51, AC04 | Time: fixed ISO dates | Risk: None
        Initialize();
        // [GIVEN] A valid request varied one field at a time.
        ResourceNo := NewResource('');
        Request := NewRequest(ResourceNo, 'day', '2026-01-05', '2026-01-05');
        Request.Remove('periodType');
        // [WHEN/THEN] Every invalid form returns a stable code and correction.
        AssertRefusal(Request, 'MissingParameter', 'periodType');
        Request.Add('periodType', 1);
        AssertRefusal(Request, 'InvalidParameterFormat', 'periodType');
        Request.Replace('periodType', 'fortnight');
        AssertRefusal(Request, 'InvalidParameter', 'periodType');
        Request.Replace('periodType', 'day');
        Request.Add('unexpected', true);
        AssertRefusal(Request, 'UnknownParameter', 'unexpected');
        Request.Remove('unexpected');
        Request.Replace('fromDate', '05.01.2026');
        AssertRefusal(Request, 'InvalidParameterFormat', 'fromDate');
        Request.Replace('fromDate', '2026-01-06');
        AssertRefusal(Request, 'InvalidParameter', 'toDate');
        Request.Replace('fromDate', '2026-01-05');
        NullValue.SetValueToNull();
        Request.Replace('resourceNo', NullValue);
        AssertRefusal(Request, 'InvalidParameterFormat', 'resourceNo');
        Request.Replace('resourceNo', '123456789012345678901');
        AssertRefusal(Request, 'InvalidParameterFormat', 'resourceNo');
    end;

    /// <summary>Selectors are exact identifiers, never BC filter expressions.</summary>
    [Test]
    procedure Scenario_AC04_UnknownIdentifiers_Refused()
    var
        Request: JsonObject;
    begin
        // Story #51, AC04 | Time: fixed dates | Risk: None
        Initialize();
        // [GIVEN] A nonexistent exact identifier and then a group identifier.
        Request := NewRequest(NewNumber(), 'day', '2026-01-05', '2026-01-05');
        // [WHEN/THEN] No implicit all-resource result or filter interpretation.
        AssertRefusal(Request, 'RecordNotFound', 'resourceNo');
        Request.Replace('resourceNo', '*');
        AssertRefusal(Request, 'RecordNotFound', 'resourceNo');
        Request.Replace('resourceNo', '');
        Request.Add('resourceGroupNo', NewNumber());
        AssertRefusal(Request, 'RecordNotFound', 'resourceGroupNo');
    end;

    /// <summary>Disabling the feature denies the public interface before licensing or reads.</summary>
    [Test]
    procedure Scenario_AC04_DisabledFeature_DeniesRequest()
    var
        Setup: Record "Projects Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
        Response: JsonObject;
    begin
        // Story #51, AC04 | Time: no date dependency | Risk: None
        Initialize();
        // [GIVEN] The company has disabled Projects.
        Setup.Get();
        Setup.Enabled := false;
        Setup.Modify(false);
        Impl := "Message Type ori"::"Projects.ResourceCapacity.Get";
        TempArgument.Type := "Message Type ori"::"Projects.ResourceCapacity.Get";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        // [WHEN] Executing through the registered interface.
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        // [THEN] No business data can be read.
        Assert.IsFalse(Impl.IsEnabled(), 'Disabled in discovery');
        Assert.AreEqual('PermissionDenied', Response.GetText('code'), 'Disabled refusal');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable refusal');
        Assert.IsFalse(Response.Contains('rows'), 'No data leak');
    end;

    /// <summary>Help and corrections are localized; names and effects remain stable.</summary>
    [Test]
    procedure Scenario_AC04_AC05_LocalizedHelp_ThreePartReadType()
    var
        Impl: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Examples: JsonArray;
        Parameters: JsonArray;
        Response: JsonObject;
        Request: JsonObject;
        EnglishDescription: Text;
        EnglishNextStep: Text;
        EnglishParameters: Text;
        OriginalLanguage: Integer;
    begin
        // Story #51, AC04/AC05 | Time: fixed dates in request/help example | Risk: XLF synchronization
        Initialize();
        // [GIVEN] The registered three-part message type.
        Assert.AreEqual(3, 'Projects.ResourceCapacity.Get'.Split('.').Count(), 'Three-part name');
        Impl := "Message Type ori"::"Projects.ResourceCapacity.Get";
        Contract := "Message Type ori"::"Projects.ResourceCapacity.Get";
        Request := NewRequest(NewResource(''), 'invalid', '2026-01-05', '2026-01-05');
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishDescription := Impl.GetDescription();
        Contract.GetParameters(Parameters);
        EnglishParameters := Format(Parameters);
        Response := Execute(Request);
        EnglishNextStep := Response.GetText('nextStep');
        // [WHEN] Switching to Icelandic.
        GlobalLanguage(1039);
        Clear(Parameters);
        Contract.GetParameters(Parameters);
        Response := Execute(Request);
        // [THEN] Prose changes while contract tokens do not.
        Assert.AreNotEqual(EnglishDescription, Impl.GetDescription(), 'Icelandic description');
        Assert.AreNotEqual(EnglishParameters, Format(Parameters), 'Icelandic parameters');
        Assert.AreNotEqual(EnglishNextStep, Response.GetText('nextStep'), 'Icelandic correction');
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Stable code');
        Contract.GetEffect(Effect);
        Assert.AreEqual('read', Effect.GetText('effect'), 'Read only');
        Assert.IsTrue(Effect.GetBoolean('idempotent'), 'Idempotent');
        Contract.GetExamples(Examples);
        Assert.AreEqual('Projects.ResourceCapacity.Get', Examples.GetObject(0).GetObject('request').GetText('type'), 'Runnable example type');
        Assert.IsTrue(Examples.GetObject(0).GetObject('response').GetArray('rows').GetObject(0).Contains('timeSheetHours'), 'Example documents quantities');
        GlobalLanguage(OriginalLanguage);
    end;

    local procedure Initialize()
    var
        Setup: Record "Projects Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(false);
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Capacity: Codeunit "Projects Capacity ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.ResourceCapacity.Get";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Capacity.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure AssertRefusal(Request: JsonObject; ErrorCode: Text; ParameterName: Text)
    var
        Response: JsonObject;
    begin
        Response := Execute(Request);
        Assert.AreEqual(ErrorCode, Response.GetText('code'), 'Typed refusal');
        Assert.AreEqual(ParameterName, Response.GetText('parameter'), 'Named invalid parameter');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Correction is provided');
        Assert.IsFalse(Response.Contains('rows'), 'No partial data on refusal');
    end;

    local procedure AssertRow(Row: JsonObject; ResourceNo: Code[20]; FirstDate: Text; LastDate: Text; Capacity: Decimal; Hours: Decimal; Usage: Decimal)
    begin
        Assert.AreEqual(ResourceNo, Row.GetText('resourceNo'), 'Resource selector');
        Assert.AreEqual(FirstDate, Row.GetText('fromDate'), 'Inclusive first date');
        Assert.AreEqual(LastDate, Row.GetText('toDate'), 'Inclusive last date');
        Assert.AreEqual(Capacity, Row.GetDecimal('capacity'), 'Capacity');
        Assert.AreEqual(Hours, Row.GetDecimal('timeSheetHours'), 'Active and archived hours');
        Assert.AreEqual(Usage, Row.GetDecimal('usage'), 'Net posted usage in base units');
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
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure NewResource(GroupNo: Code[20]): Code[20]
    var
        Resource: Record Resource;
    begin
        Resource."No." := NewNumber();
        Resource."Resource Group No." := GroupNo;
        Resource.Insert(false);
        exit(Resource."No.");
    end;

    local procedure SeedCapacity(ResourceNo: Code[20]; EntryDate: Date; Quantity: Decimal)
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
        Capacity.Date := EntryDate;
        Capacity.Capacity := Quantity;
        Capacity.Insert(false);
    end;

    local procedure SeedTime(ResourceNo: Code[20]; EntryDate: Date; Quantity: Decimal; Archived: Boolean)
    var
        Detail: Record "Time Sheet Detail";
        Archive: Record "Time Sheet Detail Archive";
    begin
        Detail."Time Sheet No." := NewNumber();
        Detail."Time Sheet Line No." := 10000;
        Detail."Resource No." := ResourceNo;
        Detail.Date := EntryDate;
        Detail.Quantity := Quantity;
        if Archived then
            Detail.Status := Detail.Status::Approved
        else
            Detail.Status := Detail.Status::Open;
        if Archived then begin
            Archive.TransferFields(Detail);
            Archive.Insert(false);
        end else
            Detail.Insert(false);
    end;

    local procedure SeedUsage(ResourceNo: Code[20]; EntryDate: Date; Quantity: Decimal; Sale: Boolean)
    var
        Usage: Record "Res. Ledger Entry";
        EntryNo: Integer;
    begin
        Usage.LockTable();
        if Usage.FindLast() then
            EntryNo := Usage."Entry No.";
        Usage.Init();
        Usage."Entry No." := EntryNo + 1;
        Usage."Resource No." := ResourceNo;
        Usage."Posting Date" := EntryDate;
        Usage."Quantity (Base)" := Quantity;
        Usage.Quantity := Quantity / 2;
        Usage."Qty. per Unit of Measure" := 2;
        if Sale then
            Usage."Entry Type" := Usage."Entry Type"::Sale
        else
            Usage."Entry Type" := Usage."Entry Type"::Usage;
        Usage.Insert(false);
    end;
}
