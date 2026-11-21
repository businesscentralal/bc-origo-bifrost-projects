namespace Origo.Bifrost.Projects.Test;

using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Customer sign-off and PDF report behavior for issue #86; SaaS Team Member proof remains separate.</summary>
codeunit 97194 "Proj. Visit Sign Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Proj. Visit Sign Fixture ori";

    [Test]
    procedure Scenario_AC01_SignAndPreview()
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Response: JsonObject;
        Request: JsonObject;
        Token: JsonToken;
        Photos: JsonArray;
        SignatureId: Guid;
        PhotoId: Guid;
    begin
        // [GIVEN] A synthetic completed visit, two usage lines and customer-captured test image bytes.
        Fixture.Seed(Visit);
        SignatureId := Fixture.StageImage(' IMAGE/PNG; charset=binary ', true);
        PhotoId := Fixture.StageImage('image/png', true);
        Request := SignRequest(Visit, SignatureId);
        Photos.Add(Format(PhotoId, 0, 4));
        Request.Add('photoStagingIds', Photos);
        // [WHEN] The technician signs and then previews the visit.
        Response := Run("Message Type ori"::"Projects.Visit.SignOff", Request);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Visit.Get(Visit."Entry No.");
        Assert.IsTrue(Visit.Signed and Visit.Locked, 'Signed and locked.');
        Assert.AreEqual('Synthetic signer', Visit."Signer Name", 'Signer.');
        Assert.AreEqual(SignatureId, Visit."Signature Id", 'Signature reference.');
        Assert.IsTrue(Visit."Signed At" <> 0DT, 'Signature timestamp.');
        Visit.CalcFields(Signature);
        Assert.IsTrue(Visit.Signature.HasValue(), 'Signature bytes on visit.');
        Assert.AreEqual(1, Visit.Photos.Count(), 'Photo attached to visit.');
        Assert.IsFalse(Staging.Exists(SignatureId), 'Signature consumed once.');
        Assert.IsFalse(Staging.Exists(PhotoId), 'Photo consumed once.');
        Response := Run("Message Type ori"::"Projects.VisitReport.Get", ById(Visit));
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
        Assert.AreEqual('visit@example.invalid', TextOf(Response, 'recipient'), 'Synthetic recipient.');
        Response.Get('usageLines', Token);
        Assert.AreEqual(2, Token.AsArray().Count(), 'Two usage lines.');
        Response.Get('visit', Token);
        Assert.AreEqual('2.5', TextOf(Token.AsObject(), 'hours'), 'Visit hours.');
        Response.Get('report', Token);
        Assert.AreEqual('70013460', TextOf(Token.AsObject(), 'id'), 'Report id.');
    end;

    [Test]
    procedure Scenario_AC04_InvalidImageRollsBackTake()
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('image/png', false);
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Id)), 'InvalidParameterFormat');
        Assert.IsTrue(Staging.Exists(Id), 'Failed signature must not consume staging.');
        Visit.Get(Visit."Entry No.");
        Assert.IsFalse(Visit.Signed or Visit.Locked, 'No visit mutation.');
    end;

    [Test]
    procedure Scenario_AC04_ContentTypeRollsBackTake()
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('text/plain', true);
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Id)), 'InvalidParameterFormat');
        Assert.IsTrue(Staging.Exists(Id), 'Refused metadata must not consume staging.');
    end;

    [Test]
    procedure Scenario_AC04_MissingSigner()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := SignRequest(Visit, CreateGuid());
        Request.Remove('signerName');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'MissingParameter');
    end;

    [Test]
    procedure Scenario_AC04_UnknownAndMalformedKeys()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := ById(Visit);
        Request.Add('unknown', true);
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", Request), 'UnknownParameter');
        Clear(Request);
        Request.Add('visitId', 'not-an-integer');
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", Request), 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC04_UnknownVisitAndStaging()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, CreateGuid())), 'RecordNotFound');
        Request.Add('visitId', 2147483647);
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", Request), 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_ConflictingIdentifiers()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := ById(Visit);
        Request.Add('taskNo', 'DIFFERENT');
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", Request), 'ConflictingIdentifiers');
    end;

    [Test]
    procedure Scenario_AC04_OtherTechnicianRefused()
    var
        Visit: Record "Proj. Field Visit ori";
        Resource: Record Resource;
    begin
        Fixture.Seed(Visit);
        Resource.Get(Visit."Resource No.");
        Resource."Time Sheet Owner User ID" := 'X86OTHER';
        Resource.Modify();
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", ById(Visit)), 'PermissionDenied');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, CreateGuid())), 'PermissionDenied');
    end;

    [Test]
    procedure Scenario_AC04_RunningRefused()
    var
        Visit: Record "Proj. Field Visit ori";
    begin
        Fixture.Seed(Visit);
        Visit.Status := Visit.Status::Running;
        Visit.Modify();
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, CreateGuid())), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_ReplayAndAlreadySigned()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('image/png', true);
        Request := SignRequest(Visit, Id);
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'status'), 'Initial sign.');
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'status'), 'Same request replays.');
        Request.Replace('clientRequestId', 'another-request');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_BadPhotoRollsBackSignature()
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Request: JsonObject;
        Photos: JsonArray;
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('image/png', true);
        Request := SignRequest(Visit, Id);
        Photos.Add(Format(CreateGuid(), 0, 4));
        Request.Add('photoStagingIds', Photos);
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'RecordNotFound');
        Assert.IsTrue(Staging.Exists(Id), 'Signature restored after later photo failure.');
        Visit.Get(Visit."Entry No.");
        Assert.IsFalse(Visit.Signed, 'Signature state rolled back.');
    end;

    [Test]
    procedure Scenario_AC05_ReadRoleCannotSign()
    var
        Visit: Record "Proj. Field Visit ori";
        Lower: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := SignRequest(Visit, CreateGuid());
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'PermissionDenied');
    end;

    [Test]
    procedure Scenario_AC05_TechnicianSignsAndReads()
    var
        Visit: Record "Proj. Field Visit ori";
        Lower: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := SignRequest(Visit, Fixture.StageImage('image/png', true));
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ FIELD TECH');
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'status'), 'Technician sign.');
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.VisitReport.Get", ById(Visit)), 'status'), 'Technician preview.');
    end;

    [Test]
    procedure Scenario_AC03_StopCompleteAndUnlock()
    var
        Resource: Record Resource;
        Visit: Record "Proj. Field Visit ori";
        Lower: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Fixture.StageImage('image/png', true))), 'status'), 'Sign.');
        Request := ById(Visit);
        Resource.SetFilter("No.", 'X86*');
        Resource.SetFilter("No.", '<>%1&X86*', Visit."Resource No.");
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        Resource.ModifyAll("Time Sheet Owner User ID", 'X86OTHER', false);
        Response := Run("Message Type ori"::"Projects.Visit.Stop", Request);
        Refusal(Response, 'PreconditionFailed');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains('unlock'), 'Stop refuses because signed visit is locked.');
        Response := Run("Message Type ori"::"Projects.Visit.Complete", Request);
        Refusal(Response, 'PreconditionFailed');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains('unlock'), 'Complete refuses because signed visit is locked.');
        Visit.Get(Visit."Entry No.");
        Commit();
        Lower.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Lower.AddPermissionSet('PROJ FIELD TECH');
        asserterror Codeunit.Run(Codeunit::"Proj. Visit Unlock ori", Visit);
        Clear(Lower);
        Lower.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Codeunit.Run(Codeunit::"Proj. Visit Unlock ori", Visit);
        Assert.IsFalse(Visit.Locked, 'Manager unlock.');
    end;

    [Test]
    procedure Scenario_AC02_Pdf1033()
    begin
        CheckPdf(1033);
    end;

    [Test]
    procedure Scenario_AC02_Pdf1039()
    begin
        CheckPdf(1039);
    end;

    [Test]
    procedure Scenario_AC07_GenericSignFieldsRefused()
    var
        Visit: Record "Proj. Field Visit ori";
        Fields: JsonObject;
        Response: JsonObject;
        FieldNames: List of [Text];
        FieldName: Text;
    begin
        Fixture.Seed(Visit);
        Commit();
        FieldNames.AddRange('Signer Name', 'Signed At', 'Locked');
        foreach FieldName in FieldNames do begin
            Clear(Fields);
            case FieldName of
                'Signer Name':
                    Fields.Add(FieldName, 'Not allowed');
                'Signed At':
                    Fields.Add(FieldName, Format(CurrentDateTime(), 0, 9));
                'Locked':
                    Fields.Add(FieldName, true);
            end;
            Response := GenericWrite(Visit."Entry No.", Fields);
            Refusal(Response, 'PermissionDenied');
            Assert.IsTrue(TextOf(Response, 'nextStep').Contains('Projects.Visit.SignOff'), 'Dedicated sign-off hint.');
        end;
        Visit.Get(Visit."Entry No.");
        Assert.IsFalse(Visit.Signed or Visit.Locked, 'Generic writes changed nothing.');
    end;

    [Test]
    procedure Scenario_AC08_HelpBothLanguages()
    begin
        AssertHelp("Message Type ori"::"Projects.VisitReport.Get");
        AssertHelp("Message Type ori"::"Projects.Visit.SignOff");
    end;

    [Test]
    procedure Scenario_AC04_ConsumedStagingRefused()
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('image/png', true);
        Assert.IsTrue(Staging.Take(Id, Blob), 'Consume owned fixture.');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Id)), 'RecordNotFound');
        Visit.Get(Visit."Entry No.");
        Assert.IsFalse(Visit.Signed, 'Consumed signature changed nothing.');
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
        Request.Add('tableId', Database::"Proj. Field Visit ori");
        Request.Add('data', Rows);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Data.Records.Set", "Message Version ori"::"1.0", '', 'XVISIT86', 'application/json', RequestContent, ResponseContent, ContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure AssertHelp(MessageType: Enum "Message Type ori")
    var
        Api: Interface "Msg Interface ori";
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        English: Text;
        Icelandic: Text;
        EnglishKeywords: Text;
        IcelandicKeywords: Text;
        Overview: Text;
        IcelandicOverview: Text;
        Notes: Text;
        Previous: Integer;
    begin
        Api := MessageType;
        Contract := MessageType;
        Discovery := MessageType;
        Previous := GlobalLanguage();
        GlobalLanguage(1033);
        English := Api.GetDescription();
        EnglishKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(Overview), 'Overview.');
        Assert.IsTrue(Contract.GetNotes(Notes), 'Notes.');
        Assert.IsFalse(English.Contains('message type'), 'No message type wording.');
        Assert.IsFalse(Overview.Contains('codeunit'), 'No AL object name.');
        GlobalLanguage(1039);
        Icelandic := Api.GetDescription();
        IcelandicKeywords := Discovery.GetKeywords();
        Assert.IsTrue(Contract.GetOverview(IcelandicOverview), 'Icelandic overview.');
        Assert.AreNotEqual(English, Icelandic, 'Discovery is translated.');
        Assert.AreEqual(EnglishKeywords.Split(',').Count(), IcelandicKeywords.Split(',').Count(), 'Keyword counts match.');
        Assert.AreEqual(Overview, IcelandicOverview, 'Chapters stay English.');
        GlobalLanguage(Previous);
    end;

    [Test]
    procedure Scenario_AC01_ResolveByProjectTaskDate()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request.Add('projectNo', Visit."Project No.");
        Request.Add('taskNo', Visit."Task No.");
        Request.Add('date', Format(Visit.Date, 0, 9));
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.VisitReport.Get", Request), 'status'), 'Alternate identifier.');
    end;

    [Test]
    procedure Scenario_AC04_SignerLengthBoundary()
    var
        Visit: Record "Proj. Field Visit ori";
        Request: JsonObject;
        Response: JsonObject;
        Id: Guid;
    begin
        Fixture.Seed(Visit);
        Id := Fixture.StageImage('image/png', true);
        Request := SignRequest(Visit, Id);
        Request.Replace('signerName', PadStr('X', 101, 'X'));
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'InvalidParameterFormat');
        Request.Replace('signerName', PadStr('X', 100, 'X'));
        Response := Run("Message Type ori"::"Projects.Visit.SignOff", Request);
        Assert.AreEqual('Success', TextOf(Response, 'status'), Dump(Response));
    end;

    [Test]
    procedure Scenario_AC03_UsageRegisterRefusedAfterSign()
    var
        Visit: Record "Proj. Field Visit ori";
        Usage: Record "TS Usage Line ori";
        Request: JsonObject;
        Response: JsonObject;
        CountBefore: Integer;
    begin
        Fixture.Seed(Visit);
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Fixture.StageImage('image/png', true))), 'status'), 'Sign.');
        Usage.SetRange("Time Sheet No.", Visit."Time Sheet No.");
        CountBefore := Usage.Count();
        Request.Add('timeSheetNo', Visit."Time Sheet No.");
        Request.Add('lineNo', Visit."Time Sheet Line No.");
        Request.Add('type', 'Resource');
        Request.Add('no', Visit."Resource No.");
        Request.Add('date', Format(Visit.Date, 0, 9));
        Request.Add('quantity', 1);
        Response := Run("Message Type ori"::"Projects.Usage.Register", Request);
        Refusal(Response, 'PreconditionFailed');
        Assert.IsTrue(TextOf(Response, 'nextStep').Contains('unlock'), 'Usage names the signed-visit lock.');
        Assert.AreEqual(CountBefore, Usage.Count(), 'No new usage.');
    end;

    [Test]
    procedure Scenario_AC05_NoPermissionsRefused()
    var
        Visit: Record "Proj. Field Visit ori";
        Lower: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
    begin
        Fixture.Seed(Visit);
        Request := SignRequest(Visit, CreateGuid());
        Commit();
        Lower.PushPermissionSetWithoutDefaults('ProjVisit86None ori');
        Refusal(Run("Message Type ori"::"Projects.Visit.SignOff", Request), 'PermissionDenied');
        Refusal(Run("Message Type ori"::"Projects.VisitReport.Get", ById(Visit)), 'PermissionDenied');
    end;

    local procedure CheckPdf(LanguageId: Integer)
    var
        Visit: Record "Proj. Field Visit ori";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Input: InStream;
        Id: Guid;
        Prefix: Text;
        PreviousLanguage: Integer;
        ReportText: Text;
    begin
        Fixture.Seed(Visit);
        Assert.AreEqual('Success', TextOf(Run("Message Type ori"::"Projects.Visit.SignOff", SignRequest(Visit, Fixture.StageImage('image/png', true))), 'status'), 'Signed report fixture.');
        Visit.Get(Visit."Entry No.");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ReportText := Fixture.RenderedWordText(Visit);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(ReportText.Contains('Synthetic signer'), 'Merged report contains signer: ' + ReportText);
        Assert.IsTrue(ReportText.Contains('Synthetic equipment repaired'), 'Merged report contains outcome.');
        Assert.IsTrue(ReportText.Contains('Synthetic part 1'), 'Merged report contains first usage line.');
        Assert.IsTrue(ReportText.Contains('Synthetic part 2'), 'Merged report contains second usage line.');
        GlobalLanguage(LanguageId);
        Id := Fixture.Render(Visit);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(Staging.Take(Id, Blob), 'PDF taken from staging.');
        Assert.IsTrue(Blob.Length() > 1000, 'Nonempty PDF.');
        Blob.CreateInStream(Input);
        Input.ReadText(Prefix, 4);
        Assert.AreEqual('%PDF', Prefix, 'Native PDF signature.');
        Assert.IsFalse(Staging.Exists(Id), 'PDF one-shot staging consumed.');
    end;

    local procedure ById(Visit: Record "Proj. Field Visit ori") Request: JsonObject
    begin
        Request.Add('visitId', Visit."Entry No.");
    end;

    local procedure SignRequest(Visit: Record "Proj. Field Visit ori"; Id: Guid) Request: JsonObject
    begin
        Request := ById(Visit);
        Request.Add('signerName', 'Synthetic signer');
        Request.Add('signatureStagingId', Format(Id, 0, 4));
        Request.Add('clientRequestId', 'synthetic-sign-request');
    end;

    local procedure Run(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        UsageManager: Codeunit "TS Usage Mgt ori";
        Handler: Interface "Msg Interface ori";
    begin
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := TempArgument.Version::"1.0";
        TempArgument.Insert();
        TempArgument.SetRequestJson(Request);
        Handler := TempArgument.GetMessageTypeInterface();
        Commit();
        // Usage license gating is outside this business-rule test (NOT_RUN per PR).
        // Exercise the same native manager as the existing usage suite; no licensed flag is fabricated.
        if MessageType = MessageType::"Projects.Usage.Register" then
            UsageManager.Execute(TempArgument, 1)
        else
            Handler.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure Refusal(Response: JsonObject; Expected: Text)
    begin
        Assert.AreEqual('Error', TextOf(Response, 'status'), Dump(Response));
        Assert.AreEqual(Expected, TextOf(Response, 'code'), Dump(Response));
        Assert.IsTrue(TextOf(Response, 'nextStep') <> '', 'Refusal has next step.');
    end;

    local procedure TextOf(Value: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Value.Get(Name, Token) then
            exit(Token.AsValue().AsText());
    end;

    local procedure Dump(Value: JsonObject) Text: Text
    begin
        Value.WriteTo(Text);
    end;
}
