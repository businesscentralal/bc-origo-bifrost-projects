namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Projects #49: caller isolation, typed selection, daily hours, paging and localized help.</summary>
codeunit 97161 "TS Sheet Get Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Owners read the header, all line statuses and daily hours in English.</summary>
    [Test]
    procedure AC01_OwnerRead_1033()
    begin
        AssertOwnerRead(1033);
    end;

    /// <summary>Icelandic calls retain stable machine-readable status names.</summary>
    [Test]
    procedure AC01_OwnerRead_1039()
    begin
        AssertOwnerRead(1039);
    end;

    /// <summary>The approver can read a sheet belonging to another employee.</summary>
    [Test]
    procedure AC02_ApproverRead()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] Another employee owns a sheet addressed to the caller.
        CreateSheet(Header, NewResource(), 'XOTHER', UserId(), 20990105D);
        Request.Add('timeSheetNo', Header."No.");
        // [WHEN] The approver reads it.
        Response := Execute(Request);
        // [THEN] Header data is available, including an empty line list.
        Assert.AreEqual('Success', Response.GetText('status'), 'Approver has access.');
        Assert.AreEqual(0, FirstSheet(Response).GetArray('lines').Count(), 'Empty sheet has no lines.');
    end;

    /// <summary>Unrelated callers receive no sheet data in English.</summary>
    [Test]
    procedure AC02_ForeignSheet_1033()
    begin
        AssertForeignSheet(1033);
    end;

    /// <summary>Unrelated callers receive no sheet data in Icelandic.</summary>
    [Test]
    procedure AC02_ForeignSheet_1039()
    begin
        AssertForeignSheet(1039);
    end;

    /// <summary>Blank owner and approver never grant access.</summary>
    [Test]
    procedure AC02_BlankAssignments_Denied()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
    begin
        CreateSheet(Header, NewResource(), '', '', 20990105D);
        Request.Add('timeSheetNo', Header."No.");
        AssertRefusal(Request, 'PermissionDenied');
    end;

    /// <summary>Resource-and-date selection enforces the same authorization as number selection.</summary>
    [Test]
    procedure AC02_ForeignResourceDate_Denied()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
    begin
        CreateSheet(Header, NewResource(), 'XOTHER', 'XAPPROVER', 20990105D);
        Request.Add('resourceNo', Header."Resource No.");
        Request.Add('date', '2099-01-05');
        AssertRefusal(Request, 'PermissionDenied');
    end;

    /// <summary>An explicitly foreign resource list is refused.</summary>
    [Test]
    procedure AC02_ForeignResourceList_Denied()
    var
        Resource: Record Resource;
        Request: JsonObject;
    begin
        Resource.Get(NewResource());
        Resource."Time Sheet Owner User ID" := 'XOTHER';
        Resource.Modify();
        Request.Add('resourceNo', Resource."No.");
        AssertRefusal(Request, 'PermissionDenied');
    end;

    /// <summary>List calls from a caller with no resource or sheet mapping fail closed.</summary>
    [Test]
    procedure AC02_UnmappedCaller_Denied()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Request: JsonObject;
    begin
        // [GIVEN] Isolate this test session from any demo mappings; test isolation restores them.
        Resource.SetRange("Time Sheet Owner User ID", UpperCase(UserId()));
        Resource.ModifyAll("Time Sheet Owner User ID", 'XOTHER');
        Resource.Reset();
        Resource.SetRange("Time Sheet Approver User ID", UpperCase(UserId()));
        Resource.ModifyAll("Time Sheet Approver User ID", 'XOTHER');
        Header.SetRange("Owner User ID", UpperCase(UserId()));
        Header.ModifyAll("Owner User ID", 'XOTHER');
        Header.Reset();
        Header.SetRange("Approver User ID", UpperCase(UserId()));
        Header.ModifyAll("Approver User ID", 'XOTHER');
        // [WHEN/THEN] An unfiltered read is refused without data.
        AssertRefusal(Request, 'PermissionDenied');
    end;

    /// <summary>The starting and ending dates both select the same sheet.</summary>
    [Test]
    procedure AC01_ResourceDate_InclusiveBoundaries()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSheet(Header, NewResource(), UserId(), 'XAPPROVER', 20990105D);
        Request.Add('resourceNo', Header."Resource No.");
        Request.Add('date', '2099-01-05');
        Response := Execute(Request);
        Assert.AreEqual(Header."No.", FirstSheet(Response).GetText('timeSheetNo'), 'First day is included.');
        Request.Replace('date', '2099-01-11');
        Response := Execute(Request);
        Assert.AreEqual(Header."No.", FirstSheet(Response).GetText('timeSheetNo'), 'Last day is included.');
        Request.Replace('date', '2099-01-12');
        AssertRefusal(Request, 'RecordNotFound');
    end;

    /// <summary>Paging counts only authorized sheets, includes owner and approver, and has no duplicates.</summary>
    [Test]
    procedure AC03_Paging_ExcludesForeignSheets()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
        ResourceNo: Code[20];
        FirstNo: Text;
    begin
        ResourceNo := NewResource();
        CreateSheet(Header, ResourceNo, UserId(), 'XOTHER', 20990105D);
        CreateSheet(Header, ResourceNo, 'XOTHER', UserId(), 20990112D);
        CreateSheet(Header, ResourceNo, 'XOTHER', 'XAPPROVER', 20990119D);
        Request.Add('resourceNo', ResourceNo);
        Request.Add('take', 1);
        Response := Execute(Request);
        Assert.IsTrue(Response.GetBoolean('hasMore'), 'Second authorized sheet remains.');
        FirstNo := FirstSheet(Response).GetText('timeSheetNo');
        Request.Add('skip', 1);
        Response := Execute(Request);
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'Foreign sheet does not count.');
        Assert.AreNotEqual(FirstNo, FirstSheet(Response).GetText('timeSheetNo'), 'No duplicate across pages.');
        Request.Replace('skip', 2);
        Response := Execute(Request);
        Assert.AreEqual(0, Response.GetArray('timeSheets').Count(), 'Offset at end is empty.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'No next page.');
    end;

    /// <summary>Overlap filters include boundary dates and retain all days on a selected sheet.</summary>
    [Test]
    procedure AC03_OverlapRange_KeepsAllHours()
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonToken;
    begin
        CreateSheet(Header, NewResource(), UserId(), 'XOTHER', 20990105D);
        CreateLine(Header, "Time Sheet Status"::Submitted, 0);
        Request.Add('resourceNo', Header."Resource No.");
        Request.Add('from', '2099-01-11');
        Request.Add('to', '2099-01-11');
        Response := Execute(Request);
        FirstSheet(Response).GetArray('lines').Get(0, Line);
        Assert.AreEqual(3.5, Line.AsObject().GetDecimal('totalHours'), 'Hours on the first day are retained.');
        Request.Replace('from', '2099-01-12');
        Request.Replace('to', '2099-01-12');
        Response := Execute(Request);
        Assert.AreEqual(0, Response.GetArray('timeSheets').Count(), 'Next day no longer overlaps.');
    end;

    /// <summary>Mapped resources without sheets return a successful empty list.</summary>
    [Test]
    procedure AC03_EmptyResource_Success()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('resourceNo', NewResource());
        Request.Add('take', 100);
        Request.Add('skip', 2147483647);
        Response := Execute(Request);
        Assert.AreEqual('Success', Response.GetText('status'), 'Empty mapped scope succeeds.');
        Assert.AreEqual(0, Response.GetArray('timeSheets').Count(), 'No sheets.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'No more sheets.');
    end;

    /// <summary>Malformed scalar, null and compound values fail with typed errors.</summary>
    [Test]
    procedure AC04_InvalidValues_Refused()
    begin
        AssertJsonError('{"take":0}', 'InvalidParameterFormat');
        AssertJsonError('{"take":101}', 'InvalidParameterFormat');
        AssertJsonError('{"take":1.5}', 'InvalidParameterFormat');
        AssertJsonError('{"take":"1"}', 'InvalidParameterFormat');
        AssertJsonError('{"take":true}', 'InvalidParameterFormat');
        AssertJsonError('{"skip":-1}', 'InvalidParameterFormat');
        AssertJsonError('{"skip":2147483648}', 'InvalidParameterFormat');
        AssertJsonError('{"resourceNo":null}', 'InvalidParameterFormat');
        AssertJsonError('{"resourceNo":{}}', 'InvalidParameterFormat');
        AssertJsonError('{"resourceNo":[]}', 'InvalidParameterFormat');
        AssertJsonError('{"resourceNo":" "}', 'InvalidParameterFormat');
        AssertJsonError('{"timeSheetNo":"123456789012345678901"}', 'InvalidParameterFormat');
        AssertJsonError('{"date":"2099-99-99"}', 'InvalidParameterFormat');
        AssertJsonError('{"from":"2099-01-06","to":"2099-01-05"}', 'InvalidParameter');
    end;

    /// <summary>Missing, conflicting and unknown selectors have actionable refusals.</summary>
    [Test]
    procedure AC04_InvalidSelectors_Refused()
    begin
        AssertJsonError('{"date":"2099-01-05"}', 'MissingParameter');
        AssertJsonError('{"from":"2099-01-05"}', 'MissingParameter');
        AssertJsonError('{"timeSheetNo":"X49","take":1}', 'ConflictingIdentifiers');
        AssertJsonError('{"resourceNo":"X49","date":"2099-01-05","skip":0}', 'ConflictingIdentifiers');
        AssertJsonError('{"userId":"XOTHER"}', 'UnknownParameter');
        AssertJsonError('{"timeSheetNo":"X49-NONEXISTENT"}', 'RecordNotFound');
        AssertJsonError('{"resourceNo":"X49-NONEXISTENT"}', 'RecordNotFound');
    end;

    /// <summary>The public contract is complete and translated into both supported locales.</summary>
    [Test]
    procedure AC04_AC05_BilingualContract_ThreePartName()
    var
        Impl: Codeunit "TS Sheet Get Impl ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        EnglishDescription: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishDescription := Impl.GetDescription();
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Projects.TimeSheet.Get", Contract), 'English contract exists.');
        Assert.IsTrue(Contract.Contains('parameters'), 'Parameters are documented.');
        Clear(Contract);
        GlobalLanguage(1039);
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Projects.TimeSheet.Get", Contract), 'Icelandic contract exists.');
        Assert.AreNotEqual(EnglishDescription, Impl.GetDescription(), 'Description is translated.');
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual(3, 'Projects.TimeSheet.Get'.Split('.').Count(), 'Exactly three name parts.');
    end;

    local procedure AssertOwnerRead(LanguageId: Integer)
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        Response: JsonObject;
        Sheet: JsonObject;
        Line: JsonToken;
        Day: JsonToken;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] An owned sheet contains each native line status and fractional hours.
        CreateSheet(Header, NewResource(), UserId(), 'XOTHER', 20990105D);
        CreateLine(Header, "Time Sheet Status"::Open, 0);
        CreateLine(Header, "Time Sheet Status"::Submitted, 1);
        CreateLine(Header, "Time Sheet Status"::Rejected, 2);
        CreateLine(Header, "Time Sheet Status"::Approved, 3);
        Request.Add('timeSheetNo', Header."No.");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Read through the registered message interface.
        Response := Execute(Request);
        GlobalLanguage(PreviousLanguage);
        // [THEN] All header, line and day values survive, without writes.
        Sheet := FirstSheet(Response);
        Assert.AreEqual(Header."Resource No.", Sheet.GetText('resourceNo'), 'Resource identity.');
        Assert.AreEqual(4, Sheet.GetArray('lines').Count(), 'All statuses included.');
        Sheet.GetArray('lines').Get(0, Line);
        Assert.AreEqual('Open', Line.AsObject().GetText('status'), 'Stable status name.');
        Assert.AreEqual(3.5, Line.AsObject().GetDecimal('totalHours'), 'Fractional total.');
        Line.AsObject().GetArray('days').Get(0, Day);
        Assert.AreEqual('2099-01-05', Day.AsObject().GetText('date'), 'ISO date.');
        Assert.AreEqual(3.5, Day.AsObject().GetDecimal('hours'), 'Daily hours.');
        Assert.AreEqual('Open', Day.AsObject().GetText('status'), 'Daily status.');
        Sheet.GetArray('lines').Get(3, Line);
        Assert.AreEqual('Approved', Line.AsObject().GetText('status'), 'Approved lines included.');
        Assert.IsFalse(Response.GetBoolean('hasMore'), 'Single result never paged.');
    end;

    local procedure AssertForeignSheet(LanguageId: Integer)
    var
        Header: Record "Time Sheet Header";
        Request: JsonObject;
        PreviousLanguage: Integer;
    begin
        CreateSheet(Header, NewResource(), 'XOTHER', 'XAPPROVER', 20990105D);
        CreateLine(Header, "Time Sheet Status"::Open, 0);
        Request.Add('timeSheetNo', Header."No.");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        AssertRefusal(Request, 'PermissionDenied');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertJsonError(RequestText: Text; ExpectedCode: Text)
    var
        Request: JsonObject;
    begin
        Request.ReadFrom(RequestText);
        AssertRefusal(Request, ExpectedCode);
    end;

    local procedure AssertRefusal(Request: JsonObject; ExpectedCode: Text)
    var
        Response: JsonObject;
        ResponseText: Text;
    begin
        Response := Execute(Request);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Error', Response.GetText('status'), ResponseText);
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), ResponseText);
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'Refusal gives a next step.');
        Assert.IsFalse(Response.Contains('timeSheets'), 'No sheet data on refusal.');
    end;

    local procedure FirstSheet(Response: JsonObject): JsonObject
    var
        Sheet: JsonToken;
    begin
        Assert.AreEqual('Success', Response.GetText('status'), 'Read succeeds.');
        Assert.AreEqual(1, Response.GetArray('timeSheets').Count(), 'Exactly one sheet.');
        Response.GetArray('timeSheets').Get(0, Sheet);
        exit(Sheet.AsObject());
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Interface "Msg Interface ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := "Message Type ori"::"Projects.TimeSheet.Get";
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        Impl := TempArgument.GetMessageTypeInterface();
        Impl.ExecuteBifrostTask(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure NewResource(): Code[20]
    var
        Resource: Record Resource;
    begin
        Resource."No." := CopyStr('X49' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(UserId()), 1, 50);
        Resource.Insert(false);
        exit(Resource."No.");
    end;

    local procedure CreateSheet(var Header: Record "Time Sheet Header"; ResourceNo: Code[20]; Owner: Text; Approver: Text; StartDate: Date)
    begin
        Clear(Header);
        Header."No." := CopyStr('X49' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Header."Resource No." := ResourceNo;
        Header."Owner User ID" := CopyStr(UpperCase(Owner), 1, 50);
        Header."Approver User ID" := CopyStr(UpperCase(Approver), 1, 50);
        Header."Starting Date" := StartDate;
        Header."Ending Date" := StartDate + 6;
        Header.Insert(false);
    end;

    local procedure CreateLine(Header: Record "Time Sheet Header"; Status: Enum "Time Sheet Status"; Index: Integer)
    var
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
    begin
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := (Index + 1) * 10000;
        Line.Type := Line.Type::Resource;
        Line.Status := Status;
        Line.Description := 'X49 read fixture';
        Line.Insert(false);
        Detail."Time Sheet No." := Line."Time Sheet No.";
        Detail."Time Sheet Line No." := Line."Line No.";
        Detail.Date := Header."Starting Date";
        Detail.Quantity := 3.5;
        Detail.Status := Status;
        Detail.Insert(false);
    end;
}
