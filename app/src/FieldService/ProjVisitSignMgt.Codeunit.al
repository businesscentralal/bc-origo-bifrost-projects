namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Project.Job;
using Microsoft.CRM.Contact;
using Origo.Bifrost;

/// <summary>Validates the report and customer sign-off requests without granting write permissions.</summary>
codeunit 70013462 "Proj. Visit Sign Mgt ori"
{
    Access = Internal;
    var
        RefusedLbl: Label 'The visit request was refused.', Comment = 'is-IS=Beiðni um heimsókn var hafnað.';
        NextLbl: Label 'Use your completed visit and the documented parameters. Ask the project manager to unlock a signed visit.', Comment = 'is-IS=Notaðu lokna heimsókn þína og skráðar færibreytur. Biddu verkefnisstjóra að aflæsa undirritaðri heimsókn.';
        SummaryLbl: Label 'Visit %1: %2 hours.', Comment = '%1=visit number; %2=hours; is-IS=Heimsókn %1: %2 stundir.';
        RenderLbl: Label 'Render report %1 with the visit filter %2. Pass the PDF through Foundation blob staging. Show the recipient and obtain explicit consent before sending.', Comment = '%1=report id; %2=visit filter; is-IS=Myndaðu skýrslu %1 með heimsóknarsíunni %2. Færðu PDF-skrána gegnum bráðabirgðageymslu Foundation. Sýndu viðtakanda og fáðu skýrt samþykki áður en sent er.';

    /// <summary>Tests the actual table permissions needed by this operation.</summary>
    procedure CanRun(Sign: Boolean): Boolean
    var
        Visit: Record "Proj. Field Visit ori";
        Usage: Record "TS Usage Line ori";
        Resource: Record Resource;
        Job: Record Job;
        Contact: Record Contact;
    begin
        exit(Visit.ReadPermission() and (not Sign or Visit.WritePermission()) and Usage.ReadPermission() and Resource.ReadPermission() and Job.ReadPermission() and Contact.ReadPermission());
    end;

    /// <summary>Executes an approved preview or signature request. A failed signature transaction rolls back the staging take.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Sign: Boolean)
    var
        Visit: Record "Proj. Field Visit ori";
        Resource: Record Resource;
        Runner: Codeunit "Proj. Visit Sign Runner ori";
        Request: JsonObject;
        Response: JsonObject;
        PhotoIds: JsonArray;
        PhotoId: Guid;
        Token: JsonToken;
        Keys: List of [Text];
        KeyName: Text;
        Raw: Text;
        ProjectNo: Text;
        TaskNo: Text;
        DateText: Text;
        Signer: Text;
        RequestId: Text;
        StagingText: Text;
        StagingId: Guid;
        VisitId: Integer;
        Day: Date;
        OwnCount: Integer;
        FoundId: Integer;
    begin
        Argument.AssertVersion1();
        if not CanRun(Sign) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '');
            exit;
        end;
        Request := Argument.GetRequestJson();
        Keys.AddRange('visitId', 'projectNo', 'taskNo', 'date');
        if Sign then
            Keys.AddRange('signerName', 'signatureStagingId', 'clientRequestId', 'photoStagingIds');
        foreach KeyName in Request.Keys() do
            if not Keys.Contains(KeyName) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName);
                exit;
            end;
        if not ReadText(Argument, Request, 'projectNo', 20, false, ProjectNo) or
           not ReadText(Argument, Request, 'taskNo', 20, false, TaskNo) or
           not ReadText(Argument, Request, 'date', 10, false, DateText)
        then
            exit;
        if (DateText <> '') and not Evaluate(Day, DateText, 9) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'date');
            exit;
        end;
        if Request.Get('visitId', Token) then begin
            Token.WriteTo(Raw);
            if not Token.IsValue() or not Evaluate(VisitId, Raw, 9) or (VisitId <= 0) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'visitId');
                exit;
            end;
            if not Visit.Get(VisitId) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'visitId');
                exit;
            end;
            if ((ProjectNo <> '') and (Visit."Project No." <> UpperCase(ProjectNo))) or
               ((TaskNo <> '') and (Visit."Task No." <> UpperCase(TaskNo))) or
               ((DateText <> '') and (Visit.Date <> Day))
            then begin
                Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'visitId');
                exit;
            end;
        end else begin
            if (ProjectNo = '') or (TaskNo = '') or (Day = 0D) then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'visitId');
                exit;
            end;
            Visit.SetRange("Project No.", ProjectNo);
            Visit.SetRange("Task No.", TaskNo);
            Visit.SetRange(Date, Day);
            if not Visit.FindSet() then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'visitId');
                exit;
            end;
            repeat
                if Resource.Get(Visit."Resource No.") then
                    if Resource."Time Sheet Owner User ID" = UpperCase(UserId()) then begin
                        OwnCount += 1;
                        FoundId := Visit."Entry No.";
                    end;
            until Visit.Next() = 0;
            if OwnCount = 0 then begin
                Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'visitId');
                exit;
            end;
            if OwnCount > 1 then begin
                Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'visitId');
                exit;
            end;
            Visit.Reset();
            Visit.Get(FoundId);
        end;
        if not Resource.Get(Visit."Resource No.") then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'visitId');
            exit;
        end;
        if Resource."Time Sheet Owner User ID" <> UpperCase(UserId()) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'visitId');
            exit;
        end;
        if Sign then begin
            if not ReadText(Argument, Request, 'signerName', 100, true, Signer) or
               not ReadText(Argument, Request, 'signatureStagingId', 38, true, StagingText) or
               not ReadText(Argument, Request, 'clientRequestId', 100, true, RequestId)
            then
                exit;
            if not Evaluate(StagingId, StagingText) or IsNullGuid(StagingId) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'signatureStagingId');
                exit;
            end;
            if Argument."Omit Commit" then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '');
                exit;
            end;
            if Request.Get('photoStagingIds', Token) then begin
                if not Token.IsArray() then begin
                    Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'photoStagingIds');
                    exit;
                end;
                PhotoIds := Token.AsArray();
                if PhotoIds.Count() > 10 then begin
                    Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'photoStagingIds');
                    exit;
                end;
                foreach Token in PhotoIds do begin
                    Token.WriteTo(Raw);
                    if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then begin
                        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'photoStagingIds');
                        exit;
                    end;
                    if not Evaluate(PhotoId, Token.AsValue().AsText()) or IsNullGuid(PhotoId) then begin
                        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'photoStagingIds');
                        exit;
                    end;
                end;
            end;
            Runner.SetCall(Visit."Entry No.", Signer, StagingId, RequestId, PhotoIds);
            if Database.IsInWriteTransaction() then
                Commit();
            if not Runner.Run() then begin
                Fail(Argument, Runner.GetErrorCode(), 'signatureStagingId');
                exit;
            end;
            Visit.Get(Visit."Entry No.");
        end;
        Response := Preview(Visit);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Builds a quantity-only preview, using the visit time-sheet line and date.</summary>
    procedure Preview(Visit: Record "Proj. Field Visit ori") Response: JsonObject
    var
        Job: Record Job;
        Contact: Record Contact;
        Usage: Record "TS Usage Line ori";
        VisitJson: JsonObject;
        ReportJson: JsonObject;
        UsageJson: JsonObject;
        Lines: JsonArray;
        NextSteps: JsonArray;
        Recipient: Text;
    begin
        if Job.Get(Visit."Project No.") then
            if Contact.Get(Job."Sell-to Contact No.") then
                Recipient := Contact."E-Mail";
        VisitJson.Add('visitId', Visit."Entry No.");
        VisitJson.Add('hours', Visit."Hours Written");
        VisitJson.Add('outcome', Visit.Outcome);
        VisitJson.Add('signed', Visit.Signed);
        VisitJson.Add('locked', Visit.Locked);
        VisitJson.Add('signerName', Visit."Signer Name");
        VisitJson.Add('signedAt', Format(Visit."Signed At", 0, 9));
        VisitJson.Add('signatureAttachmentId', Format(Visit."Signature Id", 0, 4));
        Usage.SetRange("Time Sheet No.", Visit."Time Sheet No.");
        Usage.SetRange("Time Sheet Line No.", Visit."Time Sheet Line No.");
        Usage.SetRange(Date, Visit.Date);
        Usage.SetRange("Resource No.", Visit."Resource No.");
        if Usage.FindSet() then
            repeat
                Clear(UsageJson);
                UsageJson.Add('entryNo', Usage."Entry No.");
                UsageJson.Add('description', Usage.Description);
                UsageJson.Add('quantity', Usage.Quantity);
                UsageJson.Add('unitOfMeasure', Usage."Unit of Measure Code");
                Lines.Add(UsageJson);
            until Usage.Next() = 0;
        ReportJson.Add('id', Report::"Proj. Visit Report ori");
        ReportJson.Add('name', ReportName());
        ReportJson.Add('visitId', Visit."Entry No.");
        NextSteps.Add(StrSubstNo(RenderLbl, Report::"Proj. Visit Report ori", Visit."Entry No."));
        Response.Add('status', 'Success');
        Response.Add('visit', VisitJson);
        Response.Add('usageLines', Lines);
        Response.Add('photoCount', Visit.Photos.Count());
        Response.Add('recipient', Recipient);
        Response.Add('report', ReportJson);
        Response.Add('summary', StrSubstNo(SummaryLbl, Visit."Entry No.", Visit."Hours Written"));
        Response.Add('nextSteps', NextSteps);
    end;

    local procedure ReportName(): Text
    var
        NameLbl: Label 'Visit Report', Comment = 'is-IS=Heimsóknarskýrsla';
    begin
        exit(NameLbl);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; MaxLength: Integer; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if (Value.Trim() = '') or (StrLen(Value) > MaxLength) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Parameter: Text)
    begin
        Argument.RespondWithError(ErrorCode, RefusedLbl, Parameter, '', '', NextLbl);
    end;
}
