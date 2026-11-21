namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 81 acceptance tests for linked, append-only planning journal transfers.</summary>
codeunit 97179 "Proj. Plan Journal Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Proj. Plan Journal Fixture ori";
        Library: Codeunit "Projects Test Library ori";
        Assert: Codeunit "Library Assert";

    /// <summary>AC01: resource and stocked item lines post through Foundation and update usage.</summary>
    [Test]
    procedure AC01_TransferAndFoundationPost()
    var
        Request: JsonObject;
        Response: JsonObject;
        Plan: Record "Job Planning Line";
        Journal: Record "Job Journal Line";
        Ledger: Record "Job Ledger Entry";
    begin
        // Story #81, AC01 | Time: own open posting date | Risk: Foundation journal posting
        Request := Fixture.Seed();
        Response := Fixture.Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(2, Response.GetArray('journalLines').Count(), 'One journal line per selected planning line');
        Journal.SetRange("Journal Template Name", Request.GetText('templateName'));
        Journal.FindFirst();
        Assert.AreEqual(10000, Journal."Job Planning Line No.", 'Resource linked');
        Assert.AreEqual(3, Journal.Quantity, 'Default remaining quantity');
        Assert.AreEqual(7, Journal."Unit Cost", 'Native cost copied');
        Assert.AreEqual(11, Journal."Unit Price", 'Native price copied');
        Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        Assert.IsTrue(Ledger.IsEmpty(), 'Transfer does not post');
        Library.AssertStatus(Fixture.Post(Request), 'Success');
        Assert.AreEqual(2, Ledger.Count(), 'Resource and item usage posted');
        Plan.SetRange("Job No.", Request.GetText('projectNo'));
        Plan.FindSet();
        repeat
            Assert.IsTrue(Plan."Usage Link", 'Usage link enabled');
            Assert.AreEqual(3, Plan."Qty. Posted", 'Usage on original planning line');
            Assert.AreEqual(0, Plan."Remaining Qty.", 'Remaining quantity reduced');
        until Plan.Next() = 0;
        Assert.IsTrue(Journal.IsEmpty(), 'Foundation post consumed created journal lines');
    end;

    /// <summary>AC02: partial quantities append and preserve every existing journal field.</summary>
    [Test]
    procedure AC02_PartialAppendPreservesExisting()
    var
        Request: JsonObject;
        Selection: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
        Existing: Record "Job Journal Line";
        After: Record "Job Journal Line";
        BeforeRef: RecordRef;
        AfterRef: RecordRef;
        Index: Integer;
    begin
        // Story #81, AC02 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        Existing."Journal Template Name" := CopyStr(Request.GetText('templateName'), 1, 10);
        Existing."Journal Batch Name" := 'X81';
        Existing."Line No." := 12345;
        Existing.Description := 'X existing line stays exactly the same';
        Existing.Quantity := 19;
        Existing.Insert(false);
        BeforeRef.GetTable(Existing);
        Selection := Request.GetArray('planningLines').GetObject(0).Clone().AsObject();
        Selection.Add('quantity', 1.5);
        Lines.Add(Selection);
        Request.Replace('planningLines', Lines);
        Response := Fixture.Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(22345, Response.GetArray('journalLines').GetObject(0).GetInteger('lineNo'), 'Append after existing highest line');
        Assert.AreEqual(1.5, Response.GetArray('journalLines').GetObject(0).GetDecimal('quantity'), 'Partial quantity');
        After.Get(Existing."Journal Template Name", Existing."Journal Batch Name", Existing."Line No.");
        AfterRef.GetTable(After);
        for Index := 1 to BeforeRef.FieldCount() do
            Assert.AreEqual(Format(BeforeRef.FieldIndex(Index).Value()), Format(AfterRef.FieldIndex(Index).Value()), 'Existing field unchanged');
    end;

    /// <summary>AC03: every quantity boundary refuses without a partial journal.</summary>
    [Test]
    procedure AC03_QuantityRefusals()
    var
        Request: JsonObject;
        Quantity: Integer;
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        for Quantity := -1 to 0 do
            AssertRefusal(WithQuantity(Request, Quantity), 'PreconditionFailed');
        AssertRefusal(WithQuantity(Request, 3.00001), 'PreconditionFailed');
        AssertRefusal(WithQuantity(Request, 999999), 'PreconditionFailed');
    end;

    /// <summary>AC03: billable-only, text, exhausted and blocked lines refuse atomically.</summary>
    [Test]
    procedure AC03_BusinessPreconditions()
    var
        Request: JsonObject;
        Project: Record Job;
        Plan: Record "Job Planning Line";
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        Plan.Get(Request.GetText('projectNo'), 'X100', 20000);
        Plan."Line Type" := Plan."Line Type"::Billable;
        Plan.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Plan."Line Type" := Plan."Line Type"::Budget;
        Plan.Type := Plan.Type::Text;
        Plan.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Plan.Type := Plan.Type::Item;
        Plan."Remaining Qty." := 0;
        Plan.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Plan."Remaining Qty." := 3;
        Plan.Modify(false);
        Project.Get(Request.GetText('projectNo'));
        Project.Blocked := Project.Blocked::Posting;
        Project.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Project.Blocked := Project.Blocked::All;
        Project.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Project.Blocked := Project.Blocked::" ";
        Project.Status := Project.Status::Completed;
        Project.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
    end;

    /// <summary>AC03: unknown project, task, line, template and batch return RecordNotFound.</summary>
    [Test]
    procedure AC03_MissingRecords()
    var
        Request: JsonObject;
        Changed: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Name: Text;
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        foreach Name in 'projectNo,templateName,batchName'.Split(',') do begin
            Changed := Request.Clone().AsObject();
            Changed.Replace(Name, 'XNOEXIST');
            AssertCode(Fixture.Execute(Changed), 'RecordNotFound');
            AssertNoJournal(Request);
        end;
        Line := Request.GetArray('planningLines').GetObject(0).Clone().AsObject();
        Line.Replace('taskNo', 'XNOEXIST');
        Lines.Add(Line.Clone());
        Changed := Request.Clone().AsObject();
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'RecordNotFound');
        Clear(Lines);
        Line.Replace('taskNo', 'X100');
        Line.Replace('lineNo', 99999);
        Lines.Add(Line.Clone());
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'RecordNotFound');
    end;

    /// <summary>AC03: top-level and nested required, unknown and malformed values are rejected.</summary>
    [Test]
    procedure AC03_ParameterValidation()
    var
        Request: JsonObject;
        Changed: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Name: Text;
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        foreach Name in 'projectNo,planningLines,templateName,batchName,postingDate'.Split(',') do begin
            Changed := Request.Clone().AsObject();
            Changed.Remove(Name);
            AssertCode(Fixture.Execute(Changed), 'MissingParameter');
            AssertNoJournal(Request);
            Changed := Request.Clone().AsObject();
            Changed.Replace(Name, true);
            AssertCode(Fixture.Execute(Changed), 'InvalidParameterFormat');
            AssertNoJournal(Request);
        end;
        Changed := Request.Clone().AsObject();
        Changed.Add('clearExistingLines', true);
        AssertRefusal(Changed, 'UnknownParameter');
        Changed := Request.Clone().AsObject();
        Changed.Replace('postingDate', '2026-99-99');
        AssertRefusal(Changed, 'InvalidParameterFormat');
        Changed.Replace('postingDate', Request.GetText('postingDate'));
        Changed.Replace('templateName', '12345678901');
        AssertCode(Fixture.Execute(Changed), 'InvalidParameterFormat');
        AssertNoJournal(Request);
        Changed := Request.Clone().AsObject();
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'InvalidParameterFormat');
        Line := Request.GetArray('planningLines').GetObject(0).Clone().AsObject();
        Line.Add('unexpected', 1);
        Lines.Add(Line.Clone());
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'UnknownParameter');
        Clear(Lines);
        Line.Remove('unexpected');
        Line.Remove('taskNo');
        Lines.Add(Line.Clone());
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'MissingParameter');
        Clear(Lines);
        Line.Add('taskNo', 'X100');
        Line.Add('quantity', '1.5');
        Lines.Add(Line.Clone());
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'InvalidParameterFormat');
        Clear(Lines);
        Line.Remove('quantity');
        Line.Replace('lineNo', 0);
        Lines.Add(Line.Clone());
        Changed.Replace('planningLines', Lines);
        AssertRefusal(Changed, 'InvalidParameterFormat');
    end;

    /// <summary>AC03 edge: duplicate selections are refused before creating a journal.</summary>
    [Test]
    procedure AC03_DuplicateSelection()
    var
        Request: JsonObject;
        Lines: JsonArray;
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: None
        Request := Fixture.Seed();
        Lines.Add(Request.GetArray('planningLines').GetObject(0));
        Lines.Add(Request.GetArray('planningLines').GetObject(0));
        Request.Replace('planningLines', Lines);
        AssertRefusal(Request, 'InvalidParameterFormat');
    end;

    /// <summary>AC03: a native error on the second line rolls back the first line and planning changes.</summary>
    [Test]
    procedure AC03_NativeFailureRollsBack()
    var
        Request: JsonObject;
        Plan: Record "Job Planning Line";
        OriginalLink: Boolean;
        OriginalQty: Decimal;
    begin
        // Story #81, AC03 | Time: own open posting date | Risk: Native unit validation
        Request := Fixture.Seed();
        Plan.Get(Request.GetText('projectNo'), 'X100', 10000);
        OriginalLink := Plan."Usage Link";
        OriginalQty := Plan."Qty. to Transfer to Journal";
        Plan.Get(Request.GetText('projectNo'), 'X100', 20000);
        Plan."Unit of Measure Code" := 'XINVALID';
        Plan.Modify(false);
        AssertRefusal(Request, 'PreconditionFailed');
        Plan.Get(Request.GetText('projectNo'), 'X100', 10000);
        Assert.AreEqual(OriginalLink, Plan."Usage Link", 'Usage link rolled back');
        Assert.AreEqual(OriginalQty, Plan."Qty. to Transfer to Journal", 'Transfer quantity rolled back');
    end;

    /// <summary>AC05: discovery and refusals translate while help chapters remain English.</summary>
    [Test]
    procedure AC05_BilingualContract()
    var
        Impl: Codeunit "Proj. Plan Journal Impl ori";
        Errors: JsonArray;
        Effect: JsonObject;
        Overview: Text;
        EnglishOverview: Text;
        EnglishDescription: Text;
        EnglishErrors: Text;
        IcelandicErrors: Text;
        PreviousLanguage: Integer;
    begin
        // Story #81, AC05 | Time: none | Risk: Translation compilation
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishDescription := Impl.GetDescription();
        Impl.GetOverview(EnglishOverview);
        Impl.GetErrors(Errors);
        Errors.WriteTo(EnglishErrors);
        Clear(Errors);
        GlobalLanguage(1039);
        Assert.AreNotEqual(EnglishDescription, Impl.GetDescription(), 'Discovery translated');
        Impl.GetOverview(Overview);
        Assert.AreEqual(EnglishOverview, Overview, 'English-only help');
        Impl.GetErrors(Errors);
        Errors.WriteTo(IcelandicErrors);
        Assert.AreNotEqual(EnglishErrors, IcelandicErrors, 'Refusals and next steps translated');
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', Effect.GetText('effect'), 'No confirmation needed');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>AC03: Foundation stores an Error response for the refused request.</summary>
    [Test]
    procedure AC03_DispatchedRefusalIsLogged()
    var
        Request: JsonObject;
        Response: JsonObject;
        MessageId: Guid;
        MessageRef: RecordRef;
        ResponseBlob: Codeunit "Temp Blob";
        ResponseStream: InStream;
    begin
        // Story #81, AC03 | Time: none | Risk: Foundation dispatch and read-only log inspection
        Request := Fixture.Seed();
        Request.Add('clearExistingLines', true);
        Response := Fixture.Dispatch("Message Type ori"::"Projects.PlanningLine.TransferToJournal", Request, MessageId);
        AssertCode(Response, 'UnknownParameter');
        AssertNoJournal(Request);
        // Foundation owns table 10077897; its public dispatcher returns the primary key (field 1).
        // Inspect only this request's persisted response (field 9); no Foundation data is modified.
        MessageRef.Open(10077897);
        MessageRef.Field(1).SetRange(MessageId);
        Assert.IsTrue(MessageRef.FindFirst(), 'Refused request was persisted');
        ResponseBlob.FromRecordRef(MessageRef, 9);
        ResponseBlob.CreateInStream(ResponseStream, TextEncoding::UTF8);
        Clear(Response);
        Response.ReadFrom(ResponseStream);
        AssertCode(Response, 'UnknownParameter');
    end;

    local procedure WithQuantity(Request: JsonObject; Quantity: Decimal) Result: JsonObject
    var
        Lines: JsonArray;
        Selection: JsonObject;
    begin
        Result := Request.Clone().AsObject();
        Selection := Request.GetArray('planningLines').GetObject(0).Clone().AsObject();
        Selection.Add('quantity', Quantity);
        Lines.Add(Selection);
        Result.Replace('planningLines', Lines);
    end;

    local procedure AssertRefusal(Request: JsonObject; ExpectedCode: Text)
    begin
        AssertCode(Fixture.Execute(Request), ExpectedCode);
        AssertNoJournal(Request);
    end;

    local procedure AssertCode(Response: JsonObject; ExpectedCode: Text)
    begin
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), Format(Response));
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Actionable refusal');
    end;

    local procedure AssertNoJournal(Request: JsonObject)
    var
        Journal: Record "Job Journal Line";
    begin
        Journal.SetRange("Journal Template Name", Request.GetText('templateName'));
        Journal.SetRange("Journal Batch Name", Request.GetText('batchName'));
        Assert.IsTrue(Journal.IsEmpty(), 'Nothing created on refusal');
    end;
}
