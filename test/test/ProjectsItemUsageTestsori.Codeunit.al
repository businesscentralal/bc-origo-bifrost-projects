namespace Origo.Bifrost.Projects.Test;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Tests native item usage with isolated project/item fixtures and strict refusal assertions.</summary>
codeunit 97125 "Projects Item Usage Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Projects Test Library ori";

    /// <summary>A native journal post produces only ledger entries for the owned project and item.</summary>
    [Test]
    procedure HappyPath_PostsThroughNativeProjectJournal()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.GetInteger('firstEntryNo') > 0, 'Native posting returns a ledger entry');
        Ledger.Get(Response.GetInteger('firstEntryNo'));
        Assert.AreEqual(Request.GetText('projectNo'), Ledger."Job No.", 'Owned project ledger entry');
        Assert.AreEqual(Request.GetText('taskNo'), Ledger."Job Task No.", 'Owned project task');
        Assert.AreEqual(2, Ledger.Quantity, 'Native usage quantity');
        Assert.AreEqual(Ledger.Type::Item, Ledger.Type, 'Item usage posting');
        Assert.AreEqual(Response.GetInteger('firstEntryNo'), Response.GetInteger('lastEntryNo'), 'Single line ledger range');
    end;

    /// <summary>Blocked projects refuse before any native ledger write.</summary>
    [Test]
    procedure BlockedProject_RefusesWithoutLedgerWrites()
    var
        Project: Record Job;
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Project.Get(Request.GetText('projectNo'));
        Project.Blocked := Project.Blocked::All;
        Project.Modify(true);
        Response := ValidateRequest(Request);
        Assert.AreEqual('PreconditionFailed', Response.GetText('code'), 'Blocked project refusal');
        Assert.AreEqual('Change the status with Projects.Project.SetStatus.', Response.GetText('nextStep'), 'Exact status remedy');
        Ledger.SetRange("Job No.", Project."No.");
        Assert.IsTrue(Ledger.IsEmpty(), 'No owned project ledger entries');
    end;

    /// <summary>A missing later item refuses the whole request before the valid first line can post.</summary>
    [Test]
    procedure InvalidSecondItem_RefusesEntireArrayBeforePosting()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Lines := Request.GetArray('lines');
        Line.Add('itemNo', 'X-MISSING-' + CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 8));
        Line.Add('quantity', 1);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := Execute(Request);
        Assert.AreEqual('RecordNotFound', Response.GetText('code'), 'Missing second item');
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Ledger.IsEmpty(), 'Valid first line was not posted');
    end;

    /// <summary>Empty arrays and non-object lines have deterministic actionable refusals.</summary>
    [Test]
    procedure EmptyAndWrongTypedLines_Refuse()
    var
        Request: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('MissingParameter', Response.GetText('code'), 'Empty array');
        Assert.AreEqual('lines', Response.GetText('parameter'), 'Names missing lines');
        Lines.Add(7);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Scalar is not a usage object');
    end;

    /// <summary>Unknown nested fields and numeric strings are never silently accepted.</summary>
    [Test]
    procedure NestedUnknownAndWrongTypedKeys_Refuse()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Add('unitCost', 100);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'No silent direct price/cost overrides');
        Line.Remove('unitCost');
        Line.Replace('quantity', '2');
        Clear(Lines);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Numeric string is not a number');
    end;

    /// <summary>Zero and negative quantities refuse before entering native posting.</summary>
    [Test]
    procedure NonpositiveQuantity_Refuses()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Replace('quantity', 0);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Zero is not item consumption');
        Line.Replace('quantity', -1);
        Clear(Lines);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Negative consumption excluded');
    end;

    /// <summary>A single serial number cannot consume multiple base units.</summary>
    [Test]
    procedure SerialQuantity_RequiresOneBaseUnit()
    var
        Request: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        Line := Request.GetArray('lines').GetObject(0);
        Line.Add('serialNo', 'OWN-SERIAL');
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := ValidateRequest(Request);
        Assert.AreEqual('InvalidParameter', Response.GetText('code'), 'Two base units cannot share one serial');
        Assert.AreEqual('serialNo', Response.GetText('parameter'), 'Names tracking selector');
    end;

    /// <summary>A later native validation error rolls back an earlier successfully processed line.</summary>
    [Test]
    procedure NativeFailureOnSecondLine_RollsBackFirstLine()
    var
        Item: Record Item;
        Ledger: Record "Job Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
        Observer: Codeunit "Proj. Usage Observed ori";
        Request: JsonObject;
        OtherRequest: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Request := NewRequest();
        OtherRequest := NewRequest();
        Line := OtherRequest.GetArray('lines').GetObject(0);
        Item.Get(Line.GetText('itemNo'));
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Lines := Request.GetArray('lines');
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Observer.ObserveProject(CopyStr(Request.GetText('projectNo'), 1, 20));
        BindSubscription(Observer);
        Usage.Execute(TempArgument);
        UnbindSubscription(Observer);
        Assert.IsTrue(Observer.ObservedCount() > 0, 'An earlier native ledger insertion actually occurred before the later failure');
        Response := TempArgument.GetResponseJson();
        Assert.AreEqual('Error', Response.GetText('status'), 'Native blocked second item is a clean error');
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Ledger.IsEmpty(), 'Earlier first-line native posting rolled back with the whole task');
    end;

    /// <summary>Every native line entry is captured rather than only the final returned posting identifier.</summary>
    [Test]
    procedure MultipleNativeLines_ReturnExactCreatedEntryList()
    var
        Ledger: Record "Job Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        TotalQuantity: Decimal;
        LineText: Text;
    begin
        Request := NewRequest();
        Lines := Request.GetArray('lines');
        Lines.GetObject(0).WriteTo(LineText);
        Line.ReadFrom(LineText);
        Line.Replace('quantity', 1);
        Lines.Add(Line);
        Request.Replace('lines', Lines);
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('entryNos').Count(), 'Both native lines are captured');
        TotalQuantity := 0;
        foreach Token in Response.GetArray('entryNos') do begin
            Ledger.Get(Token.AsValue().AsInteger());
            Assert.AreEqual(Request.GetText('projectNo'), Ledger."Job No.", 'Every captured entry belongs to owned project');
            TotalQuantity += Ledger.Quantity;
        end;
        Assert.AreEqual(3, TotalQuantity, 'Both native quantities accounted for');
    end;

    local procedure NewRequest() Request: JsonObject
    var
        Project: Record Job;
        PlanningLine: Record "Job Planning Line";
        Planning: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
    begin
        Planning := Library.NewPlanningRequest('Item');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", Planning), 'Success');
        PlanningLine.Get(Planning.GetText('projectNo'), Planning.GetText('taskNo'), Planning.GetInteger('lineNo'));
        PlanningLine.Validate("Usage Link", true);
        PlanningLine.Modify(true);
        Project.Get(Planning.GetText('projectNo'));
        Project.Validate(Status, Project.Status::Open);
        Project.Modify(true);
        Request.Add('projectNo', Planning.GetText('projectNo'));
        Request.Add('taskNo', Planning.GetText('taskNo'));
        Line.Add('itemNo', Planning.GetText('no'));
        Line.Add('quantity', 2);
        Lines.Add(Line);
        Request.Add('lines', Lines);
    end;

    local procedure ValidateRequest(Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Insert(true);
        if Usage.Validate(TempArgument, Request) then
            Response.Add('status', 'Success')
        else
            Response := TempArgument.GetResponseJson();
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Usage: Codeunit "Projects Item Usage ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument."Omit Commit" := true;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Usage.Execute(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;
}
