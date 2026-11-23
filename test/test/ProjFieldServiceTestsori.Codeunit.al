namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Utilities;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Issue #82: technician day/brief queries, strict refusals, compact responses and role isolation.</summary>
codeunit 97184 "Proj. Field Service Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Proj. Field Fixture ori";

    /// <summary>AC01: only today's resource visits, with own time, usage, site and nextVisit.</summary>
    [Test]
    procedure AC01_TodayVisits()
    var
        Manifest: JsonObject;
        Response: JsonObject;
        Visit: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Response := Execute(false, Request(Manifest, false));
        AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('visits').Count(), 'Only today, not tomorrow');
        Visit := Response.GetArray('visits').GetObject(0);
        Assert.AreEqual('X1', Visit.GetText('taskNo'), 'Stable task order');
        Assert.AreEqual(4, Visit.GetDecimal('plannedHours'), 'Native plan quantity');
        Assert.AreEqual(1.5, Visit.GetDecimal('loggedHours'), 'Own logged time on requested date');
        Assert.AreEqual(1, Visit.GetInteger('openUsage'), 'Open own usage');
        Assert.AreEqual(Manifest.GetText('timeSheetNo'), Visit.GetText('timeSheetNo'), 'Own sheet');
        Assert.AreEqual(10000, Visit.GetInteger('timeSheetLineNo'), 'Own line');
        Assert.AreEqual('X Site street', Visit.GetObject('address').GetText('address'), 'Project site snapshot');
        Assert.AreEqual('X Site Customer', Visit.GetText('customerName'), 'Project customer snapshot');
        Assert.AreEqual('X1', Response.GetObject('nextVisit').GetText('taskNo'), 'First visit');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC02: brief includes positive remaining quantities, own usage/time and stable systemIds.</summary>
    [Test]
    procedure AC02_Brief()
    var
        Project: Record Job;
        Task: Record "Job Task";
        Manifest: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Response := Execute(true, Request(Manifest, true));
        AssertStatus(Response, 'Success');
        Assert.AreEqual(3, Response.GetObject('planned').GetArray('resources').GetObject(0).GetDecimal('remainingQuantity'), 'Remaining resources');
        Assert.AreEqual(2, Response.GetObject('planned').GetArray('items').GetObject(0).GetDecimal('remainingQuantity'), 'Remaining parts');
        Assert.AreEqual(1.5, Response.GetObject('myTime').GetDecimal('loggedHours'), 'Own task time');
        Assert.AreEqual(1, Response.GetArray('myUsage').Count(), 'Own task usage only');
        Project.Get(Manifest.GetText('projectNo'));
        Task.Get(Project."No.", 'X1');
        Assert.AreEqual(Format(Project.SystemId, 0, 4), Response.GetObject('recordIds').GetText('project'), 'Project systemId');
        Assert.AreEqual(Format(Task.SystemId, 0, 4), Response.GetObject('recordIds').GetText('task'), 'Task systemId');
        Assert.AreEqual(0, Response.GetArray('history').Count(), 'Deferred history');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC03: absent week returns a creation suggestion and no writes.</summary>
    [Test]
    procedure AC03_MissingSheet()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Manifest: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        Manifest := Fixture.Seed(2);
        Header.Get(Manifest.GetText('timeSheetNo'));
        Header.Delete(false);
        Line.SetRange("Time Sheet No.", Manifest.GetText('timeSheetNo'));
        Line.DeleteAll(false);
        BeforeCount := Header.Count();
        Response := Execute(false, Request(Manifest, false));
        AssertStatus(Response, 'Success');
        Assert.AreEqual('Projects.MyTimeSheet.Create', Response.GetArray('nextSteps').GetObject(0).GetText('type'), 'Suggested creation');
        Assert.AreEqual(Manifest.GetText('resourceNo'), Response.GetArray('nextSteps').GetObject(0).GetObject('parameters').GetText('resourceNo'), 'Ready-made resource');
        Assert.AreEqual(BeforeCount, Header.Count(), 'No sheet written');
        Assert.AreEqual(0, Line.Count(), 'No line written');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC03: an existing sheet without the task line offers a ready-made Job line request.</summary>
    [Test]
    procedure AC03_MissingLine()
    var
        Line: Record "Time Sheet Line";
        Manifest: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Line.Get(Manifest.GetText('timeSheetNo'), 10000);
        Line.Delete(false);
        Response := Execute(true, Request(Manifest, true));
        AssertStatus(Response, 'Success');
        Assert.AreEqual('Projects.MyTimeSheetLine.Set', Response.GetArray('nextSteps').GetObject(0).GetText('type'), 'Suggested task line');
        Assert.AreEqual('Job', Response.GetArray('nextSteps').GetObject(0).GetObject('parameters').GetText('type'), 'Native line type');
        Assert.IsFalse(Line.Get(Manifest.GetText('timeSheetNo'), 10000), 'No line written');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: required brief identifiers are strict.</summary>
    [Test]
    procedure AC04_MissingTask()
    var
        Data: JsonObject;
    begin
        Data.Add('projectNo', 'XUNKNOWN');
        AssertCode(Execute(true, Data), 'MissingParameter');
    end;

    /// <summary>AC04: invalid dates, value kinds, include/detail and unknown keys return typed refusals.</summary>
    [Test]
    procedure AC04_BadParameters()
    var
        Data: JsonObject;
    begin
        Data.Add('date', '2026-02-30');
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Clear(Data);
        Data.Add('date', 42);
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Clear(Data);
        Data.Add('unexpected', true);
        AssertCode(Execute(false, Data), 'UnknownParameter');
        Clear(Data);
        Data.Add('include', 'items');
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Clear(Data);
        Data.Add('detail', true);
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Clear(Data);
        Data.Add('projectNo', true);
        Data.Add('taskNo', 'X1');
        AssertCode(Execute(true, Data), 'InvalidParameterFormat');
    end;

    /// <summary>AC04: unknown project/task and foreign resource never return data.</summary>
    [Test]
    procedure AC04_NotFoundAndForeign()
    var
        Resource: Record Resource;
        Manifest: JsonObject;
        Data: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Data := Request(Manifest, true);
        Data.Replace('projectNo', 'XUNKNOWN82');
        AssertCode(Execute(true, Data), 'RecordNotFound');
        Data := Request(Manifest, true);
        Data.Replace('taskNo', 'XUNKNOWN82');
        AssertCode(Execute(true, Data), 'RecordNotFound');
        Resource.Get(Manifest.GetText('resourceNo'));
        Resource."Time Sheet Owner User ID" := 'XOTHER82';
        Resource.Modify(false);
        AssertCode(Execute(false, Request(Manifest, false)), 'PermissionDenied');
        AssertCode(Execute(true, Request(Manifest, true)), 'PermissionDenied');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC04: no mapping and ambiguous mapping are distinct, deterministic refusals.</summary>
    [Test]
    procedure AC04_OwnerMapping()
    var
        Resource: Record Resource;
        Manifest: JsonObject;
        Second: JsonObject;
        Data: JsonObject;
    begin
        // The test transaction restores pre-existing mappings after this test.
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", 'XOTHER82', false);
        AssertCode(Execute(false, Data), 'PreconditionFailed');
        Manifest := Fixture.Seed(2);
        AssertStatus(Execute(false, Data), 'Success');
        Second := Fixture.Seed(2);
        AssertCode(Execute(false, Data), 'ConflictingIdentifiers');
        AssertStatus(Execute(false, Request(Manifest, false)), 'Success');
        Fixture.Cleanup(Second);
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC05: Read plus technician role runs both queries and owner usage Register/Submit/List, with no journal or planning writes.</summary>
    [Test]
    procedure AC05_TechnicianRole()
    var
        Journal: Record "Job Journal Line";
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Lower: Codeunit "Library - Lower Permissions";
        UsageMgt: Codeunit "TS Usage Mgt ori";
        Manifest: JsonObject;
        Data: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ FIELD TECH ori');
        Assert.IsFalse(Journal.WritePermission(), 'No project journal writes');
        Assert.IsFalse(Project.WritePermission(), 'No project writes');
        Assert.IsFalse(Task.WritePermission(), 'No task writes');
        Assert.IsFalse(Planning.WritePermission(), 'No planning writes');
        AssertStatus(Execute(false, Request(Manifest, false)), 'Success');
        AssertStatus(Execute(true, Request(Manifest, true)), 'Success');
        Assert.IsTrue(UsageMgt.CanUse(1), 'Can register own usage');
        Data.Add('timeSheetNo', Manifest.GetText('timeSheetNo'));
        Data.Add('lineNo', 10000);
        Data.Add('type', 'Resource');
        Data.Add('no', Manifest.GetText('resourceNo'));
        Data.Add('date', Manifest.GetText('date'));
        Data.Add('quantity', 1);
        Data.Add('unitOfMeasure', Manifest.GetText('unit'));
        Response := ExecuteType("Message Type ori"::"Projects.Usage.Register", Data);
        AssertStatus(Response, 'Success');
        Clear(Data);
        Data.Add('timeSheetNo', Manifest.GetText('timeSheetNo'));
        AssertStatus(ExecuteType("Message Type ori"::"Projects.Usage.Submit", Data), 'Success');
        AssertStatus(ExecuteType("Message Type ori"::"Projects.Usage.List", Data), 'Success');
    end;

    /// <summary>AC05: the Foundation read role alone is refused with the technician set in nextStep.</summary>
    [Test]
    procedure AC05_NoRole()
    var
        Lower: Codeunit "Library - Lower Permissions";
        Data: JsonObject;
        Response: JsonObject;
    begin
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Response := Execute(false, Data);
        AssertCode(Response, 'PermissionDenied');
        Assert.IsTrue(Response.GetText('nextStep').Contains('PROJ FIELD TECH ori'), 'Assignable set named');
        AssertCode(Execute(true, Data), 'PermissionDenied');
    end;

    /// <summary>AC07: ten visits fit within 8 KB in the default compact response.</summary>
    [Test]
    procedure AC07_CompactTenVisits()
    var
        Blob: Codeunit "Temp Blob";
        Manifest: JsonObject;
        Response: JsonObject;
        Result: Text;
        Stream: OutStream;
    begin
        Manifest := Fixture.Seed(10);
        Response := Execute(false, Request(Manifest, false));
        AssertStatus(Response, 'Success');
        Assert.AreEqual(10, Response.GetArray('visits').Count(), 'Ten visits');
        Response.WriteTo(Result);
        Blob.CreateOutStream(Stream, TextEncoding::UTF8);
        Stream.WriteText(Result);
        Assert.IsTrue(Blob.Length() < 8192, 'UTF-8 response under 8 KB');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>Boundary: an empty day has a null nextVisit and no side effects.</summary>
    [Test]
    procedure EmptyDay()
    var
        Manifest: JsonObject;
        Data: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Manifest := Fixture.Seed(2);
        Data := Request(Manifest, false);
        Data.Add('date', Format(Today() + 10, 0, 9));
        Response := Execute(false, Data);
        AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('visits').Count(), 'No visits');
        Response.Get('nextVisit', Token);
        Assert.IsTrue(Token.AsValue().IsNull(), 'Null nextVisit');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>Include sections are explicit; a completed planned line is omitted from the brief.</summary>
    [Test]
    procedure IncludeItemsAndCompletedPlan()
    var
        Planning: Record "Job Planning Line";
        Manifest: JsonObject;
        Data: JsonObject;
        Response: JsonObject;
        Includes: JsonArray;
    begin
        Manifest := Fixture.Seed(2);
        Data := Request(Manifest, false);
        Includes.Add('items');
        Data.Add('include', Includes);
        Response := Execute(false, Data);
        Assert.AreEqual(1, Response.GetArray('visits').GetObject(0).GetArray('items').Count(), 'Requested items');
        Assert.IsFalse(Response.GetArray('visits').GetObject(0).Contains('address'), 'Address omitted explicitly');
        Planning.Get(Manifest.GetText('projectNo'), 'X1', 20000);
        Planning."Remaining Qty." := 0;
        Planning.Modify(false);
        Response := Execute(true, Request(Manifest, true));
        Assert.AreEqual(0, Response.GetObject('planned').GetArray('items').Count(), 'Consumed item omitted');
        Fixture.Cleanup(Manifest);
    end;

    /// <summary>AC08: contracts have required chapters in both LCIDs; chapters remain English.</summary>
    [Test]
    procedure AC08_HelpBothLanguages()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        PreviousLanguage: Integer;
        LanguageId: Integer;
        Languages: List of [Integer];
        MessageType: Enum "Message Type ori";
        Types: List of [Enum "Message Type ori"];
        Result: Text;
    begin
        PreviousLanguage := GlobalLanguage();
        Languages.AddRange(1033, 1039);
        Types.AddRange("Message Type ori"::"Projects.MyDay.Get", "Message Type ori"::"Projects.VisitBrief.Get");
        foreach LanguageId in Languages do begin
            GlobalLanguage(LanguageId);
            foreach MessageType in Types do begin
                Clear(Contract);
                Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Help contract exists');
                Contract.WriteTo(Result);
                Assert.IsTrue(Contract.Contains('parameters') and Contract.Contains('response') and Contract.Contains('errors') and Contract.Contains('effect') and Contract.Contains('examples'), 'Required chapters');
                Assert.IsFalse(LowerCase(Result).Contains('message type'), 'No internal terminology');
                Assert.IsTrue(Result.Contains('Read-only technician self-service'), 'English chapters in both languages');
            end;
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Identifier boundary values and invalid JSON kinds are rejected without truncation.</summary>
    [Test]
    procedure ParameterBoundaries()
    var
        Data: JsonObject;
        Includes: JsonArray;
        NullValue: JsonValue;
    begin
        Data.Add('resourceNo', 'X123456789012345678901');
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Data.Replace('resourceNo', 'X1234567890123456789');
        AssertCode(Execute(false, Data), 'RecordNotFound');
        Clear(Data);
        NullValue.SetValueToNull();
        Data.Add('resourceNo', NullValue);
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
        Clear(Data);
        Includes.Add('unknown');
        Data.Add('include', Includes);
        AssertCode(Execute(false, Data), 'InvalidParameterFormat');
    end;

    /// <summary>A historic sheet contributes time but does not hide the missing current-week sheet.</summary>
    [Test]
    procedure HistoricTimeMissingCurrentSheet()
    var
        Header: Record "Time Sheet Header";
        Manifest: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed(2);
        Header.Get(Manifest.GetText('timeSheetNo'));
        Header."Starting Date" -= 14;
        Header."Ending Date" -= 14;
        Header.Modify(false);
        Response := Execute(true, Request(Manifest, true));
        AssertStatus(Response, 'Success');
        Assert.AreEqual(1.5, Response.GetObject('myTime').GetDecimal('loggedHours'), 'Historic task total retained');
        Assert.AreEqual('Projects.MyTimeSheet.Create', Response.GetArray('nextSteps').GetObject(0).GetText('type'), 'Current sheet still needed');
        Fixture.Cleanup(Manifest);
    end;

    local procedure Request(Manifest: JsonObject; Brief: Boolean) Data: JsonObject
    begin
        Data.Add('resourceNo', Manifest.GetText('resourceNo'));
        if Brief then begin
            Data.Add('projectNo', Manifest.GetText('projectNo'));
            Data.Add('taskNo', Manifest.GetText('taskNo'));
        end;
    end;

    local procedure Execute(Brief: Boolean; Data: JsonObject): JsonObject
    begin
        if Brief then
            exit(ExecuteType("Message Type ori"::"Projects.VisitBrief.Get", Data));
        exit(ExecuteType("Message Type ori"::"Projects.MyDay.Get", Data));
    end;

    local procedure ExecuteType(MessageType: Enum "Message Type ori"; Data: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        FieldMgt: Codeunit "Proj. Field Service Mgt ori";
        UsageMgt: Codeunit "TS Usage Mgt ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert(false);
        TempArgument.SetRequestJson(Data);
        // Unit-test the same native entry point as production without fabricating licence state.
        case MessageType of
            "Message Type ori"::"Projects.MyDay.Get":
                FieldMgt.Execute(TempArgument, false);
            "Message Type ori"::"Projects.VisitBrief.Get":
                FieldMgt.Execute(TempArgument, true);
            "Message Type ori"::"Projects.Usage.Register":
                UsageMgt.Execute(TempArgument, 1);
            "Message Type ori"::"Projects.Usage.Submit":
                UsageMgt.Execute(TempArgument, 2);
            "Message Type ori"::"Projects.Usage.List":
                UsageMgt.Execute(TempArgument, 7);
        end;
        exit(TempArgument.GetResponseJson());
    end;

    local procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Result: Text;
    begin
        Response.WriteTo(Result);
        Assert.AreEqual(Expected, Response.GetText('status'), Result);
    end;

    local procedure AssertCode(Response: JsonObject; Expected: Text)
    begin
        AssertStatus(Response, 'Error');
        Assert.AreEqual(Expected, Response.GetText('code'), 'Foundation refusal code');
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable next step');
    end;
}
