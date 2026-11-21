namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Text;
using System.Utilities;

/// <summary>Own-tenant synthetic fixtures and a real signed PDF for #86 MCP receipts. No cleanup operation.</summary>
codeunit 97196 "Proj. Visit Sign Probe ori" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>Only synthetic CRONUS companies may run this test fixture.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(CompanyName().StartsWith('CRONUS'));
    end;

    /// <summary>No filter subject.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Test fixture description.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Seeds synthetic visit sign-off data and renders a test PDF.');
    end;

    /// <summary>The fixture writes test records.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Seeds an unsigned visit for MCP and a signed report fixture; returns native PDF bytes for review.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Visit: Record "Proj. Field Visit ori";
        ReportVisit: Record "Proj. Field Visit ori";
        TempSignArgument: Record "Message Argument ori" temporary;
        Fixture: Codeunit "Proj. Visit Sign Fixture ori";
        Manager: Codeunit "Proj. Visit Sign Mgt ori";
        Staging: Codeunit "Blob Staging ori";
        Base64: Codeunit "Base64 Convert";
        Blob: Codeunit "Temp Blob";
        Input: InStream;
        SignatureId: Guid;
        PdfId: Guid;
        Request: JsonObject;
        Response: JsonObject;
        SignResponse: JsonObject;
    begin
        if not IsEnabled() then
            Error('Only synthetic CRONUS test companies are allowed.');
        Fixture.Seed(Visit);
        SignatureId := Fixture.StageImage('image/png', true);
        Response.Add('visitId', Visit."Entry No.");
        Response.Add('projectNo', Visit."Project No.");
        Response.Add('taskNo', Visit."Task No.");
        Response.Add('date', Format(Visit.Date, 0, 9));
        Response.Add('signatureStagingId', Format(SignatureId, 0, 4));
        Fixture.Seed(ReportVisit);
        SignatureId := Fixture.StageImage('image/png', true);
        Request.Add('visitId', ReportVisit."Entry No.");
        Request.Add('signerName', 'Synthetic signer');
        Request.Add('signatureStagingId', Format(SignatureId, 0, 4));
        Request.Add('clientRequestId', 'synthetic-pdf');
        TempSignArgument.ID := CreateGuid();
        TempSignArgument.Type := TempSignArgument.Type::"Projects.Visit.SignOff";
        TempSignArgument.Version := TempSignArgument.Version::"1.0";
        TempSignArgument.Insert();
        TempSignArgument.SetRequestJson(Request);
        Commit();
        Manager.Execute(TempSignArgument, true);
        SignResponse := TempSignArgument.GetResponseJson();
        if SignResponse.GetText('status') <> 'Success' then
            Error('Synthetic signature setup failed.');
        ReportVisit.Get(ReportVisit."Entry No.");
        PdfId := Fixture.Render(ReportVisit);
        if not Staging.Take(PdfId, Blob) then
            Error('Synthetic PDF could not be taken from staging.');
        Blob.CreateInStream(Input);
        Response.Add('pdfBase64', Base64.ToBase64(Input));
        Response.Add('reportVisitId', ReportVisit."Entry No.");
        Response.Add('reportProjectNo', ReportVisit."Project No.");
        Response.Add('reportStagingId', Format(PdfId, 0, 4));
        Response.Add('pdfStagingConsumed', not Staging.Exists(PdfId));
        Response.Add('status', 'Success');
        Argument.SetResponseJson(Response);
    end;
}
