namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Foundation.Reporting;
using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Process codeunit for Projects.Quote.Send (#15). Repeats the checks of "Proj. Quote Send Impl ori", then does what
/// the Jobs-Send codeunit of the Send Project Quote action does without its confirmation window: validates the
/// electronic formats, sends through Job.SendProfile and archives the project by the Projects Setup rule.
/// Runs through Codeunit.Run, so any Business Central error rolls back and is answered as BusinessCentralError.
/// </summary>
codeunit 70013549 "Proj. Quote Send Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";
    Permissions = tabledata Job = R,
                  tabledata "Job Archive" = R,
                  tabledata "Document Sending Profile" = R;

    trigger OnRun()
    var
        Project: Record Job;
        DocumentSendingProfile: Record "Document Sending Profile";
        TempDocumentSendingProfile: Record "Document Sending Profile" temporary;
        JobArchive: Record "Job Archive";
        JobArchiveManagement: Codeunit "Job Archive Management";
        Impl: Codeunit "Proj. Quote Send Impl ori";
        Request: JsonObject;
        ResponseJson: JsonObject;
        ProfileSource: Text;
        ArchiveCount: Integer;
        SentMsg: Label 'Project quote sent.', Locked = true;
    begin
        Request := Rec.GetRequestJson();
        if not Impl.TryCheckProject(Rec, Request, Project) then
            exit;
        if not Impl.TryResolveProfile(Project."Bill-to Customer No.", Impl.ReadOverride(Request), DocumentSendingProfile, ProfileSource, Rec) then
            exit;

        // In memory only, as Jobs-Send does: the stored profile is never changed.
        TempDocumentSendingProfile.Copy(DocumentSendingProfile);
        TempDocumentSendingProfile.SetDocumentUsage(Project);
        TempDocumentSendingProfile.Insert();
        ValidateElectronicFormats(Project, TempDocumentSendingProfile);

        JobArchive.SetRange("No.", Project."No.");
        ArchiveCount := JobArchive.Count();
        Project.SetRecFilter();
        Project.SendProfile(TempDocumentSendingProfile);
        JobArchiveManagement.AutoArchiveJob(Project);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('projectNo', Project."No.");
        ResponseJson.Add('projectId', Format(Project.SystemId, 0, 4).ToLower());
        ResponseJson.Add('customerNo', Project."Bill-to Customer No.");
        ResponseJson.Add('customerName', Project."Bill-to Name");
        ResponseJson.Add('documentSendingProfileCode', DocumentSendingProfile.Code);
        ResponseJson.Add('documentSendingProfileSource', ProfileSource);
        ResponseJson.Add('archived', JobArchive.Count() > ArchiveCount);
        ResponseJson.Add('message', SentMsg);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure ValidateElectronicFormats(Project: Record Job; DocumentSendingProfile: Record "Document Sending Profile")
    var
        ElectronicDocumentFormat: Record "Electronic Document Format";
    begin
        if (DocumentSendingProfile."E-Mail" <> DocumentSendingProfile."E-Mail"::No) and
           (DocumentSendingProfile."E-Mail Attachment" <> DocumentSendingProfile."E-Mail Attachment"::PDF)
        then begin
            ElectronicDocumentFormat.ValidateElectronicFormat(DocumentSendingProfile."E-Mail Format");
            ElectronicDocumentFormat.ValidateElectronicJobsDocument(Project, DocumentSendingProfile."E-Mail Format");
        end;
        if DocumentSendingProfile."Electronic Document" <> DocumentSendingProfile."Electronic Document"::No then begin
            ElectronicDocumentFormat.ValidateElectronicFormat(DocumentSendingProfile."Electronic Format");
            ElectronicDocumentFormat.ValidateElectronicJobsDocument(Project, DocumentSendingProfile."Electronic Format");
        end;
    end;
}
