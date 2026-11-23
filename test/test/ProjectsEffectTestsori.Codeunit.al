namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Verifies the declared effects of #42 and the expectedCount unit sentences of the irreversible Projects types.</summary>
codeunit 97111 "Projects Effect Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ProjectUnitTxt: Label 'expectedCount counts the one project named by projectNo', Locked = true;
        PreviewTxt: Label 'send the same request without expectedCount while confirmation is enabled and read expected', Locked = true;

    /// <summary>Usage.Link declares write: it needs no confirmation, even with a wrong expectedCount.</summary>
    [Test]
    procedure UsageLink_IsWrite_NoConfirmation()
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
        Response: JsonObject;
    begin
        Assert.AreEqual('write', DeclaredEffect("Message Type ori"::"Projects.Usage.Link"), 'Usage.Link effect');
        Assert.IsFalse(ConfirmGate.IsConfirmRequired("Message Type ori"::"Projects.Usage.Link"), 'Usage.Link needs no confirmation');
        Assert.IsTrue(CheckGate("Message Type ori"::"Projects.Usage.Link", 0, Response), 'A write type passes the gate with any expectedCount');
    end;

    /// <summary>AC01: walks every Projects message type; only the posting types are irreversible.</summary>
    [Test]
    procedure OnlyPostingTypesAreIrreversible()
    var
        Contract: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Effect: JsonObject;
        Posting: List of [Text];
        Ordinal: Integer;
        Name: Text;
        Walked: Integer;
    begin
        Posting.Add('Projects.ItemUsage.Post');
        Posting.Add('Projects.WIP.Post');
        Posting.Add('Projects.WIP.Reverse');
        Posting.Add('Projects.TimeSheet.Post');
        Posting.Add('Projects.ProjectJournal.Post');
        foreach Ordinal in MessageType.Ordinals() do begin
            MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
            Name := Format(MessageType);
            if Name.StartsWith('Projects.') then begin
                Clear(Effect);
                Contract := MessageType;
                if Contract.GetEffect(Effect) then begin
                    Walked += 1;
                    Assert.AreEqual(Posting.Contains(Name), Effect.GetText('effect') = 'irreversible', Name + ': irreversible only when it posts');
                end;
            end;
        end;
        Assert.IsTrue(Walked > 20, 'The walk covered the Projects types');
    end;

    /// <summary>Every type of #42 that is irreversible declares it, so Foundation requires confirmation.</summary>
    [Test]
    procedure IrreversibleTypes_RequireConfirmation()
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
        MessageType: Enum "Message Type ori";
    begin
        foreach MessageType in IrreversibleTypes() do begin
            Assert.AreEqual('irreversible', DeclaredEffect(MessageType), Format(MessageType));
            Assert.IsTrue(ConfirmGate.IsConfirmRequired(MessageType), Format(MessageType));
        end;
    end;

    /// <summary>The gate counts the one named project: expectedCount 1 passes, 0 is refused with ConfirmationMismatch and expected 1.</summary>
    [Test]
    procedure IrreversibleTypes_CountOneProject()
    var
        MessageType: Enum "Message Type ori";
        Response: JsonObject;
    begin
        foreach MessageType in IrreversibleTypes() do begin
            Assert.IsTrue(CheckGate(MessageType, 1, Response), Format(MessageType) + ': expectedCount 1 must pass');
            Clear(Response);
            Assert.IsFalse(CheckGate(MessageType, 0, Response), Format(MessageType) + ': expectedCount 0 must be refused');
            Assert.AreEqual('ConfirmationMismatch', Response.GetText('code'), Format(MessageType) + ' code');
            Assert.AreEqual('expectedCount', Response.GetText('parameter'), Format(MessageType) + ' parameter');
            Assert.AreEqual('1', Response.GetText('expected'), Format(MessageType) + ' expected');
        end;
    end;

    /// <summary>A negative expectedCount is refused as InvalidParameterFormat; nothing runs.</summary>
    [Test]
    procedure ItemUsagePost_NegativeCount_Refused()
    var
        Response: JsonObject;
    begin
        Assert.IsFalse(CheckGate("Message Type ori"::"Projects.ItemUsage.Post", -1, Response), 'Negative count refused');
        Assert.AreEqual('InvalidParameterFormat', Response.GetText('code'), 'Negative count code');
    end;

    /// <summary>effect.changes and the expectedCount parameter name the unit and the side-effect-free preview, in English at 1033 and 1039.</summary>
    [Test]
    procedure IrreversibleTypes_HelpNamesCountUnit_BothLanguages()
    var
        MessageType: Enum "Message Type ori";
        PreviousLanguage: Integer;
        Changes1033: Text;
        Parameter1033: Text;
    begin
        PreviousLanguage := GlobalLanguage();
        foreach MessageType in IrreversibleTypes() do begin
            GlobalLanguage(1033);
            Changes1033 := EffectChanges(MessageType);
            Parameter1033 := ExpectedCountDescription(MessageType);
            Assert.IsTrue(Changes1033.Contains(ProjectUnitTxt), Format(MessageType) + ' effect.changes names the unit: ' + Changes1033);
            Assert.IsTrue(Changes1033.Contains(PreviewTxt), Format(MessageType) + ' effect.changes names the preview: ' + Changes1033);
            Assert.IsTrue(Parameter1033.StartsWith('expectedCount counts '), Format(MessageType) + ' expectedCount carries the core#1378 marker "expectedCount counts " (#44): ' + Parameter1033);
            Assert.IsTrue(Parameter1033.Contains('the one project named by projectNo'), Format(MessageType) + ' expectedCount names the unit: ' + Parameter1033);
            Assert.IsTrue(Parameter1033.Contains('always 1'), Format(MessageType) + ' expectedCount names the value');
            Assert.IsTrue(Parameter1033.Contains('send the request without expectedCount and read expected'), Format(MessageType) + ' expectedCount names the preview');
            GlobalLanguage(1039);
            Assert.AreEqual(Changes1033, EffectChanges(MessageType), Format(MessageType) + ' effect.changes is English at 1039 (#1239)');
            Assert.AreEqual(Parameter1033, ExpectedCountDescription(MessageType), Format(MessageType) + ' expectedCount is English at 1039 (#1239)');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>The Item Usage counter does not depend on the number of lines.</summary>
    [Test]
    procedure ItemUsagePost_HelpSaysCountIgnoresLines()
    begin
        Assert.IsTrue(EffectChanges("Message Type ori"::"Projects.ItemUsage.Post").Contains('whatever the number of lines'), 'Item usage changes');
        Assert.IsTrue(ExpectedCountDescription("Message Type ori"::"Projects.ItemUsage.Post").Contains('whatever the number of lines'), 'Item usage parameter');
    end;

    /// <summary>projects#104 AC01/AC02: no Projects type that declares effect read is Inbound; the three former Inbound reads are named.</summary>
    [Test]
    procedure ReadTypes_AreOutbound()
    var
        Contract: Interface "Msg Contract ori";
        Message: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Effect: JsonObject;
        Ordinal: Integer;
        Name: Text;
        Reads: Integer;
    begin
        foreach Ordinal in MessageType.Ordinals() do begin
            MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
            Name := Format(MessageType);
            if Name.StartsWith('Projects.') then begin
                Clear(Effect);
                Contract := MessageType;
                Message := MessageType;
                if Contract.GetEffect(Effect) then
                    if Effect.GetText('effect') = 'read' then begin
                        Reads += 1;
                        Assert.AreNotEqual(Format("Msg Direction ori"::Inbound), Format(Message.GetMessageDirection()), Name + ': a read type is never Inbound');
                    end;
            end;
        end;
        Assert.IsTrue(Reads >= 3, 'The walk covered the Projects read types');
        AssertReadOutbound("Message Type ori"::"Projects.VanStock.Get");
        AssertReadOutbound("Message Type ori"::"Projects.VisitReport.Get");
        AssertReadOutbound("Message Type ori"::"Projects.FollowUp.List");
    end;

    local procedure AssertReadOutbound(MessageType: Enum "Message Type ori")
    var
        Message: Interface "Msg Interface ori";
    begin
        Message := MessageType;
        Assert.AreEqual(Format("Msg Direction ori"::Outbound), Format(Message.GetMessageDirection()), Format(MessageType) + ' direction');
        Assert.AreEqual('read', DeclaredEffect(MessageType), Format(MessageType) + ' effect');
    end;

    local procedure IrreversibleTypes() Types: List of [Enum "Message Type ori"]
    begin
        Types.Add("Message Type ori"::"Projects.ItemUsage.Post");
        Types.Add("Message Type ori"::"Projects.WIP.Post");
    end;

    local procedure DeclaredEffect(MessageType: Enum "Message Type ori"): Text
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
    begin
        Contract := MessageType;
        Assert.IsTrue(Contract.GetEffect(Effect), Format(MessageType) + ' declares an effect');
        exit(Effect.GetText('effect'));
    end;

    local procedure EffectChanges(MessageType: Enum "Message Type ori"): Text
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
    begin
        Contract := MessageType;
        Contract.GetEffect(Effect);
        exit(Effect.GetText('changes'));
    end;

    local procedure ExpectedCountDescription(MessageType: Enum "Message Type ori"): Text
    var
        Contract: Interface "Msg Contract ori";
        Parameters: JsonArray;
        Entry: JsonToken;
    begin
        Contract := MessageType;
        Assert.IsTrue(Contract.GetParameters(Parameters), Format(MessageType) + ' declares parameters');
        foreach Entry in Parameters do
            if Entry.AsObject().GetText('name') = 'expectedCount' then begin
                Assert.AreEqual('integer', Entry.AsObject().GetText('type'), Format(MessageType) + ' expectedCount type');
                Assert.IsFalse(Entry.AsObject().GetBoolean('required'), Format(MessageType) + ' expectedCount is optional');
                exit(Entry.AsObject().GetText('description'));
            end;
        Assert.Fail(Format(MessageType) + ' declares no expectedCount parameter');
    end;

    /// <summary>Runs only the Foundation gate on a temporary argument naming one project; no business data is read or changed.</summary>
    local procedure CheckGate(MessageType: Enum "Message Type ori"; ExpectedCount: Integer; var Response: JsonObject): Boolean
    var
        TempArgument: Record "Message Argument ori" temporary;
        ConfirmGate: Codeunit "Confirm Gate ori";
        Request: JsonObject;
        Passed: Boolean;
    begin
        Request.Add('projectNo', 'X42-EFFECT');
        Request.Add('expectedCount', ExpectedCount);
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Passed := ConfirmGate.Check(TempArgument, MessageType);
        if not Passed then
            Response := TempArgument.GetResponseJson();
        exit(Passed);
    end;
}
