namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Project.WIP;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;

/// <summary>Issue 16: native WIP method reads, writes, protected history and bilingual refusals.</summary>
codeunit 97116 "Projects WIP Method Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Verifies AC01 Get ReturnsAllNativeSettings.</summary>
    [Test]
    procedure Scenario_AC01_Get_ReturnsAllNativeSettings()
    var
        Method: Record "Job WIP Method";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC01 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] An owned custom method with nondefault recognized settings.
        MethodCode := NewCode();
        Method.Code := MethodCode;
        Method.Description := 'Owned WIP settings';
        Method."Recognized Costs" := Method."Recognized Costs"::"Usage (Total Cost)";
        Method."Recognized Sales" := Method."Recognized Sales"::"Contract (Invoiced Price)";
        Method."WIP Cost" := false;
        Method."WIP Sales" := false;
        Method.Valid := true;
        Method.Insert(true);
        Request.Add('code', MethodCode);
        // [WHEN] The method is queried by its exact code.
        Response := Execute(false, Request);
        // [THEN] Stable enum names and every native flag are returned without writes.
        AssertSuccess(Response);
        Assert.AreEqual(1, Response.GetArray('methods').Count(), 'Exact code must return only one method');
        Row := Response.GetArray('methods').GetObject(0);
        Assert.AreEqual('Usage (Total Cost)', Row.GetText('recognizedCosts'), 'Recognized costs');
        Assert.AreEqual('Contract (Invoiced Price)', Row.GetText('recognizedSales'), 'Recognized sales');
        Assert.AreEqual(Method.Description, Row.GetText('description'), 'Description');
        Assert.IsFalse(Row.GetBoolean('wipCost'), 'WIP cost');
        Assert.IsFalse(Row.GetBoolean('wipSales'), 'WIP sales');
        Assert.IsTrue(Row.GetBoolean('valid'), 'Valid');
        Assert.IsFalse(Row.GetBoolean('systemDefined'), 'Custom method');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC01 GetWithoutCode ListsOwnMethod.</summary>
    [Test]
    procedure Scenario_AC01_GetWithoutCode_ListsOwnMethod()
    var
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonToken;
        MethodCode: Code[20];
        Found: Boolean;
    begin
        // Story #16, AC01 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] An owned method among existing methods.
        MethodCode := SeedMethod(false);
        // [WHEN] Get has no code.
        Response := Execute(false, Request);
        // [THEN] The method is present in the list.
        AssertSuccess(Response);
        foreach Row in Response.GetArray('methods') do
            if Row.AsObject().GetText('code') = MethodCode then
                Found := true;
        Assert.IsTrue(Found, 'Unfiltered Get must list the owned method');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC02 Set CreateAndUpdatePreserveOmittedFields.</summary>
    [Test]
    procedure Scenario_AC02_Set_CreateAndUpdatePreserveOmittedFields()
    var
        Method: Record "Job WIP Method";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC02 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] A fresh code and valid native recognized settings.
        MethodCode := NewCode();
        Request.Add('code', MethodCode);
        Request.Add('description', 'First description');
        Request.Add('recognizedCosts', 'Usage (Total Cost)');
        Request.Add('recognizedSales', 'Contract (Invoiced Price)');
        Request.Add('wipCost', false);
        Request.Add('wipSales', false);
        // [WHEN] Set creates, then partially updates the method.
        AssertSuccess(Execute(true, Request));
        Clear(Request);
        Request.Add('code', MethodCode);
        Request.Add('description', 'Updated description');
        AssertSuccess(Execute(true, Request));
        // [THEN] Native state changes and omitted settings remain intact.
        Method.Get(MethodCode);
        Assert.AreEqual('Updated description', Method.Description, 'Updated description');
        Assert.AreEqual(Method."Recognized Costs"::"Usage (Total Cost)", Method."Recognized Costs", 'Omitted recognized cost');
        Assert.IsFalse(Method."WIP Cost", 'Omitted cost flag');
        Assert.IsFalse(Method."WIP Sales", 'Omitted sales flag');
        Assert.IsTrue(Method.Valid, 'Native default must be preserved');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC02 SystemMethod RefusedAndUnchanged.</summary>
    [Test]
    procedure Scenario_AC02_SystemMethod_RefusedAndUnchanged()
    var
        Method: Record "Job WIP Method";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC02 | Time: independent of Today and WorkDate | Risk: synthetic owned system flag
        // [GIVEN] An owned fixture marked system-defined.
        MethodCode := SeedMethod(true);
        Request.Add('code', MethodCode);
        Request.Add('valid', false);
        // [WHEN] Set attempts even a valid-only change.
        // [THEN] The entire system-defined method is protected.
        AssertRefusal(Execute(true, Request), 'PreconditionFailed');
        Method.Get(MethodCode);
        Assert.IsTrue(Method.Valid, 'System method must remain unchanged');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC03 PostedWIP RefusedEvenWhenReversed.</summary>
    [Test]
    procedure Scenario_AC03_PostedWIP_RefusedEvenWhenReversed()
    var
        Posted: Record "Job WIP G/L Entry";
        Method: Record "Job WIP Method";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC03 | Time: independent of Today and WorkDate | Risk: synthetic owned posted history; no posting
        // [GIVEN] A custom method referenced by reversed posted WIP history.
        MethodCode := SeedMethod(false);
        Posted."Entry No." := Posted.GetLastEntryNo() + 1;
        Posted."WIP Method Used" := MethodCode;
        Posted.Reversed := true;
        Posted.Insert(false);
        Request.Add('code', MethodCode);
        Request.Add('description', 'Must not persist');
        // [WHEN] Set attempts a change.
        // [THEN] Posted history is protected regardless of reversal.
        AssertRefusal(Execute(true, Request), 'PreconditionFailed');
        Method.Get(MethodCode);
        Assert.AreEqual('Owned WIP method', Method.Description, 'Posted method must remain unchanged');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC03 CalculatedWIP RefusedBeforeWrite.</summary>
    [Test]
    procedure Scenario_AC03_CalculatedWIP_RefusedBeforeWrite()
    var
        Calculated: Record "Job WIP Entry";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC03 | Time: independent of Today and WorkDate | Risk: synthetic owned calculated history
        // [GIVEN] A custom method referenced by calculated WIP.
        MethodCode := SeedMethod(false);
        Calculated."Entry No." := Calculated.GetLastEntryNo() + 1;
        Calculated."WIP Method Used" := MethodCode;
        Calculated.Insert(false);
        Request.Add('code', MethodCode);
        Request.Add('valid', false);
        // [WHEN] Set attempts a valid-only change.
        // [THEN] The native calculated-history restriction is preserved.
        AssertRefusal(Execute(true, Request), 'PreconditionFailed');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC04 MissingCode ReturnsActionableRefusal.</summary>
    [Test]
    procedure Scenario_AC04_MissingCode_ReturnsActionableRefusal()
    var
        Request: JsonObject;
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] No required code.
        // [WHEN] Set receives an empty object.
        // [THEN] A typed refusal includes recovery guidance.
        AssertRefusal(Execute(true, Request), 'MissingParameter');
    end;

    /// <summary>Verifies AC04 InvalidInputs RefuseWithoutCreating.</summary>
    [Test]
    procedure Scenario_AC04_InvalidInputs_RefuseWithoutCreating()
    var
        Method: Record "Job WIP Method";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] An owned new code with invalid fields.
        MethodCode := NewCode();
        Request.Add('code', MethodCode);
        Request.Add('wipCost', 'false');
        // [WHEN] Boolean-as-string, invalid enum and unsupported fields are submitted.
        // [THEN] All refuse before creation.
        AssertRefusal(Execute(true, Request), 'InvalidParameterFormat');
        Request.Remove('wipCost');
        Request.Add('recognizedCosts', 'Not an enum');
        AssertRefusal(Execute(true, Request), 'InvalidParameterFormat');
        Request.Remove('recognizedCosts');
        Request.Add('systemDefined', true);
        AssertRefusal(Execute(true, Request), 'InvalidParameterFormat');
        Assert.IsFalse(Method.Get(MethodCode), 'Invalid input must not create records');
    end;

    /// <summary>Verifies AC04 OverlongCode RefusedWithoutTruncation.</summary>
    [Test]
    procedure Scenario_AC04_OverlongCode_RefusedWithoutTruncation()
    var
        Request: JsonObject;
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] A 21-character code.
        Request.Add('code', '123456789012345678901');
        // [WHEN] Either message receives it.
        // [THEN] Neither silently truncates it to an existing native code.
        AssertRefusal(Execute(true, Request), 'InvalidParameterFormat');
        AssertRefusal(Execute(false, Request), 'InvalidParameterFormat');
    end;

    /// <summary>Verifies AC04 UnknownCode ReturnsRecordNotFound.</summary>
    [Test]
    procedure Scenario_AC04_UnknownCode_ReturnsRecordNotFound()
    var
        Request: JsonObject;
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] A fresh nonexistent code.
        Request.Add('code', NewCode());
        // [WHEN] Get requests that code.
        // [THEN] The refusal explains how to find or create a method.
        AssertRefusal(Execute(false, Request), 'RecordNotFound');
    end;

    /// <summary>Verifies AC04 NativeValidation RollsBackEarlierFields.</summary>
    [Test]
    procedure Scenario_AC04_NativeValidation_RollsBackEarlierFields()
    var
        Method: Record "Job WIP Method";
        Request: JsonObject;
        MethodCode: Code[20];
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] An existing method and an incompatible WIP cost flag.
        MethodCode := SeedMethod(false);
        Request.Add('code', MethodCode);
        Request.Add('description', 'Must roll back');
        Request.Add('wipCost', false);
        // [WHEN] Native validation rejects the flag after validating description.
        // [THEN] Earlier changes do not persist and the error is actionable.
        AssertRefusal(Execute(true, Request), 'BusinessCentralError');
        Method.Get(MethodCode);
        Assert.AreEqual('Owned WIP method', Method.Description, 'Failed native validation must roll back description');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC04 TwoLocales TranslateDiscoveryAndRefusals.</summary>
    [Test]
    procedure Scenario_AC04_TwoLocales_TranslateDiscoveryAndRefusals()
    var
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
        Discovery: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        EnglishDescription: Text;
        IcelandicDescription: Text;
        EnglishOverview: Text;
        IcelandicOverview: Text;
        OriginalLanguage: Integer;
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: restores original session language
        // [GIVEN] The Set contract in both supported locales.
        OriginalLanguage := GlobalLanguage();
        Discovery := "Message Type ori"::"Projects.WIPMethod.Set";
        Contract := "Message Type ori"::"Projects.WIPMethod.Set";
        GlobalLanguage(1033);
        EnglishDescription := Discovery.GetDescription();
        Contract.GetOverview(EnglishOverview);
        English := Execute(true, Request);
        // [WHEN] The same missing-code request runs in Icelandic.
        GlobalLanguage(1039);
        IcelandicDescription := Discovery.GetDescription();
        Contract.GetOverview(IcelandicOverview);
        Icelandic := Execute(true, Request);
        GlobalLanguage(OriginalLanguage);
        // [THEN] Contract help stays English, while refusals and discovery are translated.
        AssertRefusal(English, 'MissingParameter');
        AssertRefusal(Icelandic, 'MissingParameter');
        Assert.AreNotEqual(EnglishDescription, IcelandicDescription, 'Discovery must be translated');
        Assert.AreNotEqual(English.GetText('error'), Icelandic.GetText('error'), 'Refusal must be translated');
        Assert.AreNotEqual(English.GetText('nextStep'), Icelandic.GetText('nextStep'), 'Next step must be translated');
        Assert.AreEqual(EnglishOverview, IcelandicOverview, 'Contract chapters must stay English');
    end;

    /// <summary>Verifies that native validation refusals translate even when the platform diagnostic has no translation.</summary>
    [Test]
    procedure Scenario_AC04_NativeErrors_LocalizedSummaryAndDiagnostic()
    var
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
        OriginalLanguage: Integer;
        MethodCode: Code[20];
    begin
        // Story #16, AC04 | Time: independent of Today and WorkDate | Risk: native diagnostic may remain English on a W1 tenant
        // [GIVEN] An owned method and a change rejected by native field validation.
        MethodCode := SeedMethod(false);
        Request.Add('code', MethodCode);
        Request.Add('wipCost', false);
        OriginalLanguage := GlobalLanguage();
        // [WHEN] The same native validation failure is returned in both supported locales.
        GlobalLanguage(1033);
        English := Execute(true, Request);
        GlobalLanguage(1039);
        Icelandic := Execute(true, Request);
        GlobalLanguage(OriginalLanguage);
        // [THEN] Our refusal and recovery text translate; the original platform diagnostic is retained separately.
        AssertRefusal(English, 'BusinessCentralError');
        AssertRefusal(Icelandic, 'BusinessCentralError');
        Assert.AreNotEqual(English.GetText('error'), Icelandic.GetText('error'), 'Native refusal summary must be translated');
        Assert.AreNotEqual(English.GetText('nextStep'), Icelandic.GetText('nextStep'), 'Native refusal guidance must be translated');
        Assert.IsTrue(English.GetText('nativeError') <> '', 'Original diagnostic must remain available');
        Assert.IsTrue(Icelandic.GetText('nativeError') <> '', 'Original diagnostic must remain available in every locale');
        Cleanup(MethodCode);
    end;

    /// <summary>Verifies AC05 NewNames HaveExactlyThreeParts.</summary>
    [Test]
    procedure Scenario_AC05_NewNames_HaveExactlyThreeParts()
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
        TypeName: Text;
    begin
        // Story #16, AC05 | Time: independent of Today and WorkDate | Risk: None
        // [GIVEN] The registered message type enum.
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        // [WHEN] Both WIP method type names are inspected.
        TypeName := Names.Get(Ordinals.IndexOf("Message Type ori"::"Projects.WIPMethod.Get".AsInteger()));
        // [THEN] Each follows the three-part naming rule.
        Assert.AreEqual(3, TypeName.Split('.').Count(), 'Get name');
        TypeName := Names.Get(Ordinals.IndexOf("Message Type ori"::"Projects.WIPMethod.Set".AsInteger()));
        Assert.AreEqual(3, TypeName.Split('.').Count(), 'Set name');
    end;

    local procedure Execute(Writing: Boolean; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Methods: Codeunit "Projects WIP Methods ori";
    begin
        TempArgument.ID := CreateGuid();
        if Writing then
            TempArgument.Type := "Message Type ori"::"Projects.WIPMethod.Set"
        else
            TempArgument.Type := "Message Type ori"::"Projects.WIPMethod.Get";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Commit();
        Methods.Execute(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        Assert.AreEqual('Success', Response.GetText('status'), 'Expected success: ' + Format(Response));
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', Response.GetText('status'), 'Expected refusal');
        Assert.AreEqual(ExpectedCode, Response.GetText('code'), 'Typed refusal: ' + Format(Response));
        Assert.IsTrue(Response.GetText('nextStep') <> '', 'Every refusal needs nextStep');
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X16' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure SeedMethod(SystemDefined: Boolean) MethodCode: Code[20]
    var
        Method: Record "Job WIP Method";
    begin
        MethodCode := NewCode();
        Method.Code := MethodCode;
        Method.Description := 'Owned WIP method';
        Method."System Defined" := SystemDefined;
        Method.Insert(true);
    end;

    local procedure Cleanup(MethodCode: Code[20])
    var
        Method: Record "Job WIP Method";
        Calculated: Record "Job WIP Entry";
        Posted: Record "Job WIP G/L Entry";
    begin
        Calculated.SetRange("WIP Method Used", MethodCode);
        Calculated.DeleteAll(false);
        Posted.SetRange("WIP Method Used", MethodCode);
        Posted.DeleteAll(false);
        Method.Get(MethodCode);
        Method.Delete(false);
    end;
}
