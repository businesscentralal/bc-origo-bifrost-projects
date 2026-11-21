namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Follow-up lifecycle, refusal, preview and generic-write regression tests (#87).</summary>
codeunit 97188 "Proj. Follow-up Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Proj. Follow-up Fixture ori";

    [Test]
    procedure Scenario_AC01_AC02_RequestPreviewConvert()
    var
        Header: Record "Proj. Follow-up Request ori";
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Manifest: JsonObject;
        Response: JsonObject;
        Request: JsonObject;
        Id: Integer;
    begin
        // [GIVEN] Raw project, item and caller resource, independent of demo data.
        Manifest := Fixture.Seed();
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", RequestJson(Manifest));
        Success(Response);
        Id := Response.GetInteger('requestId');
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Open, Header.Status, 'Request stays open.');
        Assert.AreEqual(3, Header."Estimated Hours", 'Three hours retained.');
        Request.Add('projectNo', Manifest.GetText('projectNo'));
        Response := Run("Message Type ori"::"Projects.FollowUp.List", Request);
        Success(Response);
        Assert.AreEqual(1, Response.GetArray('requests').Count(), 'Manager sees own project.');
        Request := ConvertJson(Id, true);
        // [WHEN] Preview runs native task and planning triggers, then rolls back.
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Success(Response);
        Assert.AreEqual(2, Response.GetObject('created').GetArray('planningLines').Count(), 'Resource and item preview.');
        Assert.AreEqual('Open', Response.GetObject('request').GetText('status'), 'Preview reports the retained open request.');
        Assert.IsFalse(Task.Get(Manifest.GetText('projectNo'), '1100'), 'Preview creates no task.');
        Planning.SetRange("Job No.", Manifest.GetText('projectNo'));
        Assert.AreEqual(0, Planning.Count(), 'Preview creates no lines.');
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Open, Header.Status, 'Preview retains Open.');
        Request.Replace('preview', false);
        // [THEN] Real conversion stores both planning keys and closes the request.
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Success(Response);
        Assert.IsTrue(Task.Get(Manifest.GetText('projectNo'), '1100'), 'Task exists.');
        Assert.AreEqual(2, Planning.Count(), 'Two native lines.');
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Converted, Header.Status, 'Converted.');
        Assert.AreEqual('1100', Header."Converted Task No.", 'Linked task.');
        Assert.AreEqual(10000, Header."Resource Planning Line No.", 'Linked resource line.');
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Refused(Response, 'PreconditionFailed');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC03_RejectRetainsReason()
    var
        Header: Record "Proj. Follow-up Request ori";
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Id: Integer;
    begin
        Manifest := Fixture.Seed();
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", RequestJson(Manifest));
        Success(Response);
        Id := Response.GetInteger('requestId');
        Request.Add('requestId', Id);
        Request.Add('reason', 'Already covered');
        Response := Run("Message Type ori"::"Projects.FollowUp.Reject", Request);
        Success(Response);
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Rejected, Header.Status, 'Rejected.');
        Assert.AreEqual('Already covered', Header."Rejection Reason", 'Reason retained.');
        Response := Run("Message Type ori"::"Projects.FollowUp.Reject", Request);
        Refused(Response, 'PreconditionFailed');
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", ConvertJson(Id, false));
        Refused(Response, 'PreconditionFailed');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC04_RefusalsLeaveNoRequests()
    var
        Header: Record "Proj. Follow-up Request ori";
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Request.Remove('description');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'MissingParameter');
        Request := RequestJson(Manifest);
        Request.Replace('estimatedHours', 0);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'InvalidParameterFormat');
        Request.Replace('estimatedHours', -1);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'InvalidParameterFormat');
        Request := RequestJson(Manifest);
        Request.Add('preferredDate', '2026-02-30');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'InvalidParameterFormat');
        Request := RequestJson(Manifest);
        Request.Add('surprise', true);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'UnknownParameter');
        Request := RequestJson(Manifest);
        Request.Replace('projectNo', 'X87MISSING');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'RecordNotFound');
        Request := RequestJson(Manifest);
        Request.Replace('taskNo', 'X87MISSING');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'RecordNotFound');
        Header.SetRange("Project No.", Manifest.GetText('projectNo'));
        Assert.AreEqual(0, Header.Count(), 'All refusals leave no request.');
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", ConvertJson(2147483647, false));
        Refused(Response, 'RecordNotFound');
        Clear(Request);
        Request.Add('requestId', 2147483647);
        Request.Add('reason', 'Missing');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Reject", Request), 'RecordNotFound');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC02_AC04_ConflictAndNativeRollback()
    var
        Item: Record Item;
        Task: Record "Job Task";
        Header: Record "Proj. Follow-up Request ori";
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Id: Integer;
    begin
        Manifest := Fixture.Seed();
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", RequestJson(Manifest));
        Success(Response);
        Id := Response.GetInteger('requestId');
        Request := ConvertJson(Id, false);
        Request.Replace('taskNo', '1000');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Convert", Request), 'ConflictingIdentifiers');
        Item.Get(Manifest.GetText('itemNo'));
        Item.Blocked := true;
        Item.Modify(false);
        Request.Replace('taskNo', '1100');
        Refused(Run("Message Type ori"::"Projects.FollowUp.Convert", Request), 'BusinessCentralError');
        Assert.IsFalse(Task.Get(Manifest.GetText('projectNo'), '1100'), 'Native failure rolls task back.');
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Open, Header.Status, 'Native failure leaves request open.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC01_DuplicateAndExistingTask()
    var
        Header: Record "Proj. Follow-up Request ori";
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Id: Integer;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Request.Add('clientRequestId', 'duplicate-key');
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Success(Response);
        Id := Response.GetInteger('requestId');
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Success(Response);
        Assert.AreEqual(Id, Response.GetInteger('requestId'), 'Duplicate returns the same request.');
        Header.SetRange("Project No.", Manifest.GetText('projectNo'));
        Assert.AreEqual(1, Header.Count(), 'No duplicate.');
        Request := ConvertJson(Id, false);
        Request.Replace('target', 'existingTask');
        Request.Remove('taskNo');
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Success(Response);
        Header.Get(Id);
        Assert.AreEqual('1000', Header."Converted Task No.", 'Uses original task by default.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC07_ManagedFieldsAreRestricted()
    var
        Header: Record "Proj. Follow-up Request ori";
        Manifest: JsonObject;
        Response: JsonObject;
        Fields: JsonObject;
        Id: Integer;
        Dump: Text;
    begin
        Manifest := Fixture.Seed();
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", RequestJson(Manifest));
        Success(Response);
        Id := Response.GetInteger('requestId');
        Fields.Add('Status', 1);
        Response := GenericWrite(Id, Fields);
        Response.WriteTo(Dump);
        Assert.IsTrue(Dump.Contains('Projects.FollowUp.'), 'Dedicated operation hint.');
        Header.Get(Id);
        Assert.AreEqual(Header.Status::Open, Header.Status, 'Generic status write refused.');
        Clear(Fields);
        Fields.Add('ConvertedTaskNo_', 'HACKED');
        Response := GenericWrite(Id, Fields);
        Header.Get(Id);
        Assert.AreEqual('', Header."Converted Task No.", 'Generic result-key write refused.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC08_HelpContractsBothLanguages()
    var
        MessageType: Enum "Message Type ori";
        Impl: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        Parameters: JsonArray;
        Errors: JsonArray;
        Overview: Text;
        OldLanguage: Integer;
        Language: Integer;
        Languages: List of [Integer];
        Types: List of [Enum "Message Type ori"];
    begin
        OldLanguage := GlobalLanguage();
        Types.Add("Message Type ori"::"Projects.FollowUp.Request");
        Types.Add("Message Type ori"::"Projects.FollowUp.List");
        Types.Add("Message Type ori"::"Projects.FollowUp.Convert");
        Types.Add("Message Type ori"::"Projects.FollowUp.Reject");
        Languages.Add(1033);
        Languages.Add(1039);
        foreach Language in Languages do begin
            GlobalLanguage(Language);
            foreach MessageType in Types do begin
                Impl := MessageType;
                Contract := MessageType;
                Clear(Parameters);
                Clear(Errors);
                Assert.IsTrue(Contract.GetParameters(Parameters), 'Parameters supplied.');
                Assert.IsTrue(Contract.GetErrors(Errors), 'Refusals supplied.');
                Assert.IsTrue(Contract.GetOverview(Overview), 'English overview supplied.');
                Assert.IsFalse(Overview.Contains('message type'), 'Plain help.');
                Assert.IsTrue(Parameters.Count() > 0, 'Schema exists.');
                Assert.IsTrue(Impl.GetDescription() <> '', 'Discovery exists.');
            end;
        end;
        GlobalLanguage(OldLanguage);
    end;

    [Test]
    procedure Scenario_AC01_PhotoAndRetryRetainBytes()
    var
        Line: Record "Proj. Follow-up Req. Line ori";
        Staging: Codeunit "Blob Staging ori";
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Photos: JsonArray;
        StagingId: Guid;
        Id: Integer;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Photos.Add(Manifest.GetText('stagingId'));
        Request.Add('stagingIds', Photos);
        Request.Add('clientRequestId', 'photo-retry');
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Success(Response);
        Id := Response.GetInteger('requestId');
        Line.SetRange("Request No.", Id);
        Line.SetRange("Is Photo", true);
        Assert.IsTrue(Line.FindFirst(), 'Photo retained.');
        Line.CalcFields(Photo);
        Assert.IsTrue(Line.Photo.Length() > 0, 'Photo bytes retained.');
        Evaluate(StagingId, Manifest.GetText('stagingId'));
        Assert.IsFalse(Staging.Exists(StagingId), 'Upload consumed atomically.');
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Success(Response);
        Assert.AreEqual(Id, Response.GetInteger('requestId'), 'Retry works after staging consumption.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC04_InvalidItemsAndPhotos()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Item: JsonObject;
        Items: JsonArray;
        Photos: JsonArray;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Item.Add('description', 'Valve');
        Item.Add('quantity', 0);
        Items.Add(Item);
        Request.Replace('items', Items);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'InvalidParameterFormat');
        Clear(Items);
        Item.Replace('quantity', 1);
        Item.Add('unknown', true);
        Items.Add(Item);
        Request.Replace('items', Items);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'UnknownParameter');
        Request := RequestJson(Manifest);
        Photos.Add(123);
        Request.Add('stagingIds', Photos);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'InvalidParameterFormat');
        Clear(Photos);
        Photos.Add(Format(CreateGuid(), 0, 4));
        Request.Replace('stagingIds', Photos);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'RecordNotFound');
        Clear(Photos);
        Photos.Add(Manifest.GetText('stagingId'));
        Photos.Add(Manifest.GetText('stagingId'));
        Request.Replace('stagingIds', Photos);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'ConflictingIdentifiers');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC04_BlockedAndCompletedProject()
    var
        Project: Record Job;
        Manifest: JsonObject;
        Request: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Project.Get(Manifest.GetText('projectNo'));
        Project.Blocked := Project.Blocked::All;
        Project.Modify(false);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'PreconditionFailed');
        Project.Blocked := Project.Blocked::" ";
        Project.Status := Project.Status::Completed;
        Project.Modify(false);
        Refused(Run("Message Type ori"::"Projects.FollowUp.Request", Request), 'PreconditionFailed');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC01_ListBoundariesAndEmptyWindow()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Manifest := Fixture.Seed();
        Request.Add('projectNo', Manifest.GetText('projectNo'));
        Request.Add('take', 1);
        Response := Run("Message Type ori"::"Projects.FollowUp.List", Request);
        Success(Response);
        Assert.AreEqual(0, Response.GetArray('requests').Count(), 'Empty list is successful.');
        Request.Replace('take', 100);
        Success(Run("Message Type ori"::"Projects.FollowUp.List", Request));
        Request.Replace('take', 101);
        Refused(Run("Message Type ori"::"Projects.FollowUp.List", Request), 'InvalidParameterFormat');
        Request.Replace('take', 0);
        Refused(Run("Message Type ori"::"Projects.FollowUp.List", Request), 'InvalidParameterFormat');
        Request.Replace('take', 1);
        Request.Add('skip', -1);
        Refused(Run("Message Type ori"::"Projects.FollowUp.List", Request), 'InvalidParameterFormat');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Scenario_AC02_DescriptionOnlyAndAutomaticNumber()
    var
        Manifest: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Id: Integer;
    begin
        Manifest := Fixture.Seed();
        Request := RequestJson(Manifest);
        Request.Remove('items');
        Request.Remove('estimatedHours');
        Response := Run("Message Type ori"::"Projects.FollowUp.Request", Request);
        Success(Response);
        Id := Response.GetInteger('requestId');
        Request := ConvertJson(Id, false);
        Request.Remove('taskNo');
        Response := Run("Message Type ori"::"Projects.FollowUp.Convert", Request);
        Success(Response);
        Assert.IsTrue(Response.GetObject('created').GetObject('task').GetText('taskNo') > '1000', 'Automatic task number follows source.');
        Assert.AreEqual(0, Response.GetObject('created').GetArray('planningLines').Count(), 'Description-only task has no invented quantities.');
        Fixture.Cleanup(Manifest);
    end;

    [Test]
    procedure Z_CleanupLastFixture()
    begin
        Fixture.CleanupLast();
        Commit();
    end;

    /// <summary>Runs the public implementation boundary after committing only test setup.</summary>
    procedure Run(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        Argument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
    begin
        Argument.ID := CreateGuid();
        Argument.Type := MessageType;
        Argument.Version := Argument.Version::"1.0";
        Argument.Insert();
        Argument.SetRequestJson(Request);
        Impl := Argument.GetMessageTypeInterface();
        Commit();
        Impl.ExecuteBifrostTask(Argument);
        exit(Argument.GetResponseJson());
    end;

    /// <summary>Builds a request with one item and three resource hours.</summary>
    procedure RequestJson(Manifest: JsonObject) Request: JsonObject
    var
        Item: JsonObject;
        Items: JsonArray;
    begin
        Request.Add('projectNo', Manifest.GetText('projectNo'));
        Request.Add('taskNo', Manifest.GetText('taskNo'));
        Request.Add('description', 'Replace the second valve');
        Request.Add('estimatedHours', 3);
        Item.Add('itemNo', Manifest.GetText('itemNo'));
        Item.Add('quantity', 1);
        Items.Add(Item);
        Request.Add('items', Items);
    end;

    local procedure ConvertJson(Id: Integer; Preview: Boolean) Request: JsonObject
    begin
        Request.Add('requestId', Id);
        Request.Add('target', 'newTask');
        Request.Add('taskNo', '1100');
        Request.Add('preview', Preview);
    end;

    local procedure GenericWrite(EntryNo: Integer; Fields: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        PrimaryKey: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        Request: JsonObject;
        ContentType: Text[100];
        RequestText: Text;
        ResponseText: Text;
    begin
        PrimaryKey.Add('EntryNo_', EntryNo);
        Row.Add('primaryKey', PrimaryKey);
        Row.Add('fields', Fields);
        Rows.Add(Row);
        Request.Add('tableId', Database::"Proj. Follow-up Request ori");
        Request.Add('data', Rows);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'XFOLLOWUP87', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure Success(Response: JsonObject)
    var
        Dump: Text;
    begin
        Response.WriteTo(Dump);
        Assert.AreEqual('Success', Response.GetText('status'), Dump);
    end;

    local procedure Refused(Response: JsonObject; Code: Text)
    var
        Dump: Text;
    begin
        Response.WriteTo(Dump);
        Assert.AreEqual('Error', Response.GetText('status'), Dump);
        Assert.AreEqual(Code, Response.GetText('code'), Dump);
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable refusal.');
    end;
}
