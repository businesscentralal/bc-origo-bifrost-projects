namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;
using System.Utilities;
using System.Media;

/// <summary>Takes and validates the signature and signs the visit in one rollback-capable transaction.</summary>
codeunit 70013463 "Proj. Visit Sign Runner ori"
{
    Access = Internal;
    var
        VisitId: Integer;
        Signer: Text;
        StagingId: Guid;
        RequestId: Text;
        Photos: JsonArray;
        Failure: Enum "Bifrost Error Code ori";
        RefusedLbl: Label 'The customer signature could not be stored.', Comment = 'is-IS=Ekki var hægt að vista undirskrift viðskiptavinar.';

    /// <summary>Sets the validated signature request.</summary>
    procedure SetCall(NewVisitId: Integer; NewSigner: Text; NewStagingId: Guid; NewRequestId: Text; NewPhotos: JsonArray)
    begin
        VisitId := NewVisitId;
        Signer := NewSigner;
        StagingId := NewStagingId;
        RequestId := NewRequestId;
        Photos := NewPhotos;
        Failure := Failure::BusinessCentralError;
    end;

    /// <summary>Returns the structured refusal from the failed transaction.</summary>
    procedure GetErrorCode(): Enum "Bifrost Error Code ori"
    begin
        exit(Failure);
    end;

    trigger OnRun()
    var
        Visit: Record "Proj. Field Visit ori";
        Resource: Record Resource;
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Allowed: List of [Text];
        ContentType: Text;
        FileName: Text;
        Input: InStream;
        Output: OutStream;
        PhotoToken: JsonToken;
        PhotoId: Guid;
        PhotoRequestText: Text;
    begin
        Visit.LockTable();
        if not Visit.Get(VisitId) then
            Refuse(Failure::RecordNotFound);
        if not Resource.Get(Visit."Resource No.") then
            Refuse(Failure::PermissionDenied);
        if Resource."Time Sheet Owner User ID" <> UpperCase(UserId()) then
            Refuse(Failure::PermissionDenied);
        Photos.WriteTo(PhotoRequestText);
        if Visit.Signed and (Visit."Sign Request Id" = RequestId) then begin
            if (Visit."Signer Name" <> Signer) or (Visit."Signature Id" <> StagingId) or (Visit."Sign Photo Requests" <> PhotoRequestText) then
                Refuse(Failure::ConflictingIdentifiers);
            exit;
        end;
        if Visit.Signed or Visit.Locked or (Visit.Status <> Visit.Status::Completed) then
            Refuse(Failure::PreconditionFailed);
        if not Staging.Take(StagingId, Blob, ContentType, FileName) then
            Refuse(Failure::RecordNotFound);
        Allowed.AddRange('image/png', 'image/jpeg');
        if not Staging.NormalizeMetadata(ContentType, FileName, Allowed) then
            Refuse(Failure::InvalidParameterFormat);
        if not ValidImage(Blob, ContentType) then
            Refuse(Failure::InvalidParameterFormat);
        Blob.CreateInStream(Input);
        Visit.Signature.CreateOutStream(Output);
        CopyStream(Output, Input);
        Visit."Signature Id" := StagingId;
        Visit."Signature Content Type" := CopyStr(ContentType, 1, MaxStrLen(Visit."Signature Content Type"));
        Visit."Signature File Name" := CopyStr(FileName, 1, MaxStrLen(Visit."Signature File Name"));
        Visit."Signer Name" := CopyStr(Signer, 1, MaxStrLen(Visit."Signer Name"));
        Visit."Signed At" := CurrentDateTime();
        Visit."Sign Request Id" := CopyStr(RequestId, 1, MaxStrLen(Visit."Sign Request Id"));
        Visit."Sign Photo Requests" := CopyStr(PhotoRequestText, 1, MaxStrLen(Visit."Sign Photo Requests"));
        Visit.Signed := true;
        Visit.Locked := true;
        foreach PhotoToken in Photos do begin
            Evaluate(PhotoId, PhotoToken.AsValue().AsText());
            Clear(Blob);
            if not Staging.Take(PhotoId, Blob, ContentType, FileName) then
                Refuse(Failure::RecordNotFound);
            if not Staging.NormalizeMetadata(ContentType, FileName, Allowed) or not ValidImage(Blob, ContentType) then
                Refuse(Failure::InvalidParameterFormat);
            Blob.CreateInStream(Input);
            Visit.Photos.ImportStream(Input, FileName, ContentType);
        end;
        Visit.Modify(true);
    end;

    local procedure ValidImage(var Blob: Codeunit "Temp Blob"; ContentType: Text): Boolean
    var
        Input: InStream;
        Bytes: array[8] of Byte;
        Index: Integer;
    begin
        if (Blob.Length() < 24) or (Blob.Length() > 5242880) then
            exit(false);
        Blob.CreateInStream(Input);
        for Index := 1 to 8 do
            Input.Read(Bytes[Index]);
        if not TryDecodeImage(Blob, ContentType) then
            exit(false);
        if ContentType = 'image/png' then
            exit((Bytes[1] = 137) and (Bytes[2] = 80) and (Bytes[3] = 78) and (Bytes[4] = 71) and
                 (Bytes[5] = 13) and (Bytes[6] = 10) and (Bytes[7] = 26) and (Bytes[8] = 10));
        exit((Bytes[1] = 255) and (Bytes[2] = 216) and (Bytes[3] = 255));
    end;

    [TryFunction]
    local procedure TryDecodeImage(var Blob: Codeunit "Temp Blob"; ContentType: Text)
    var
        Image: Codeunit Image;
        Input: InStream;
    begin
        Blob.CreateInStream(Input);
        Image.FromStream(Input);
        if (Image.GetWidth() < 1) or (Image.GetHeight() < 1) or
           (Image.GetWidth() > 8192) or (Image.GetHeight() > 8192)
        then
            Error(ErrorInfo.Create(RefusedLbl));
        if ((ContentType = 'image/png') and (LowerCase(Image.GetFormatAsText()) <> 'png')) or
           ((ContentType = 'image/jpeg') and (LowerCase(Image.GetFormatAsText()) <> 'jpeg'))
        then
            Error(ErrorInfo.Create(RefusedLbl));
    end;

    local procedure Refuse(Code: Enum "Bifrost Error Code ori")
    begin
        Failure := Code;
        Error(ErrorInfo.Create(RefusedLbl));
    end;
}
