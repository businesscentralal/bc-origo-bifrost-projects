namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using System.Security.User;
using System.TestLibraries.Utilities;

/// <summary>Projects #53: approval keeps transaction control out of its public request contract.</summary>
codeunit 97152 "TS Approve Contract Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>The English approval contract names only supported public keys.</summary>
    [Test]
    procedure Scenario_AC01_EnglishContract_ExcludesInternalKey()
    begin
        // Story #53, AC01 | Time: none | Risk: Foundation contract assembly
        AssertContract(1033);
    end;

    /// <summary>The Icelandic approval contract names only supported public keys.</summary>
    [Test]
    procedure Scenario_AC01_IcelandicContract_ExcludesInternalKey()
    begin
        // Story #53, AC01 | Time: none | Risk: Foundation contract assembly
        AssertContract(1039);
    end;

    /// <summary>A supported request still approves its submitted line.</summary>
    [Test]
    procedure Scenario_AC02_PublicRequest_ApprovesSubmittedLine()
    var
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Story #53, AC02 | Time: WorkDate fixture; native approval uses Today | Risk: none
        CreateSubmittedLine(Line);
        Request.Add('timeSheetNo', Line."Time Sheet No.");

        Response := Execute(Request);
        Response.WriteTo(ResponseText);

        Assert.AreEqual('Success', Response.GetText('status'), ResponseText);
        Line.Get(Line."Time Sheet No.", Line."Line No.");
        Assert.AreEqual(Line.Status::Approved, Line.Status, 'Native approval changes the submitted line.');
    end;

    /// <summary>A true omitCommit key is refused before approval.</summary>
    [Test]
    procedure Scenario_AC02_InternalKeyTrue_RefusesWithoutWriting()
    begin
        // Story #53, AC02 | Time: WorkDate fixture | Risk: none
        AssertInternalKeyRefused(true);
    end;

    /// <summary>A false omitCommit key is also unsupported, rather than silently ignored.</summary>
    [Test]
    procedure Scenario_AC02_InternalKeyFalse_RefusesWithoutWriting()
    begin
        // Story #53, AC02 | Time: WorkDate fixture | Risk: none
        AssertInternalKeyRefused(false);
    end;

    /// <summary>An empty selection succeeds without approving any submitted line.</summary>
    [Test]
    procedure Scenario_AC02_EmptySelection_LeavesLineSubmitted()
    var
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
        LineNos: JsonArray;
    begin
        // Story #53, AC02 | Time: WorkDate fixture | Risk: none
        CreateSubmittedLine(Line);
        Request.Add('timeSheetNo', Line."Time Sheet No.");
        Request.Add('lineNos', LineNos);

        Response := Execute(Request);

        Assert.AreEqual('Success', Response.GetText('status'), 'An empty explicit selection is valid.');
        Assert.AreEqual(0, Response.GetArray('lines').Count(), 'No lines were selected.');
        Line.Get(Line."Time Sheet No.", Line."Line No.");
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'The unselected line stays submitted.');
    end;

    local procedure AssertContract(LanguageId: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ContractImpl: Interface "Msg Contract ori";
        MessageImpl: Interface "Msg Interface ori";
        Contract: JsonObject;
        Parameters: JsonArray;
        Parameter: JsonToken;
        ContractText: Text;
        Description: Text;
        PreviousLanguage: Integer;
        HasContract: Boolean;
        HasParameters: Boolean;
    begin
        // [GIVEN] The moved Projects approval implementation in the requested locale.
        ContractImpl := "Message Type ori"::"Projects.TimeSheet.Approve";
        MessageImpl := "Message Type ori"::"Projects.TimeSheet.Approve";
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        // [WHEN] Read both the raw parameter declaration and the assembled public contract.
        HasParameters := ContractImpl.GetParameters(Parameters);
        HasContract := ContractMgt.GetContract("Message Type ori"::"Projects.TimeSheet.Approve", Contract);
        Description := MessageImpl.GetDescription();
        GlobalLanguage(PreviousLanguage);

        // [THEN] No hidden/filtering behavior can mask an unsupported raw request key.
        Assert.IsTrue(HasParameters, 'Approval declares public parameters.');
        Assert.AreEqual(3, Parameters.Count(), 'Only timeSheetNo, timeSheetId and lineNos are supported.');
        foreach Parameter in Parameters do
            Assert.IsTrue(Parameter.AsObject().GetText('name') in ['timeSheetNo', 'timeSheetId', 'lineNos'], 'Unexpected approval parameter.');
        Assert.IsTrue(HasContract, 'Approval has a complete contract.');
        Contract.WriteTo(ContractText);
        Assert.IsFalse(LowerCase(ContractText + Description).Contains('omitcommit'), 'No public chapter or description may name the internal transaction flag.');
    end;

    local procedure AssertInternalKeyRefused(Value: Boolean)
    var
        Line: Record "Time Sheet Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A valid submitted line and an unsupported transaction-control key.
        CreateSubmittedLine(Line);
        Request.Add('timeSheetNo', Line."Time Sheet No.");
        Request.Add('omitCommit', Value);

        // [WHEN] The caller sends the unsupported key.
        Response := Execute(Request);

        // [THEN] The refusal identifies that key and preserves the submitted line.
        Assert.AreEqual('Error', Response.GetText('status'), 'The request must be refused.');
        Assert.AreEqual('UnknownParameter', Response.GetText('code'), 'Transaction control is not a public request parameter.');
        Assert.AreEqual('omitCommit', Response.GetText('parameter'), 'The refusal identifies the supplied unsupported key.');
        Line.Get(Line."Time Sheet No.", Line."Line No.");
        Assert.AreEqual(Line.Status::Submitted, Line.Status, 'A refused request must not approve the line.');
    end;

    local procedure CreateSubmittedLine(var Line: Record "Time Sheet Line")
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        UserSetup: Record "User Setup";
        LibraryResource: Codeunit "Library - Resource";
    begin
        if not UserSetup.Get(UserId()) then begin
            UserSetup.Init();
            UserSetup."User ID" := CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"));
            UserSetup.Insert(true);
        end;
        UserSetup.Validate("Time Sheet Admin.", false);
        UserSetup.Modify(true);
        LibraryResource.CreateResourceNew(Resource);
        Resource.Rename(CopyStr('X53' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Resource."No.")));
        Resource.Validate("Use Time Sheet", true);
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Modify(true);
        Header.Init();
        Header."No." := Resource."No.";
        Header."Resource No." := Resource."No.";
        Header."Starting Date" := WorkDate();
        Header."Ending Date" := WorkDate() + 6;
        Header."Owner User ID" := Resource."Time Sheet Owner User ID";
        Header."Approver User ID" := Resource."Time Sheet Approver User ID";
        Header.Insert(false);
        Line.Init();
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        Line.Status := Line.Status::Submitted;
        Line."Approver ID" := Header."Approver User ID";
        Line.Insert(false);
    end;

    local procedure Execute(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageImpl: Interface "Msg Interface ori";
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument."Type" := "Message Type ori"::"Projects.TimeSheet.Approve";
        TempArgument."Version" := TempArgument."Version"::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        MessageImpl := TempArgument.GetMessageTypeInterface();
        MessageImpl.ExecuteBifrostTask(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;
}
