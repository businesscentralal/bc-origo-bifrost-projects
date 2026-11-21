namespace Origo.Bifrost.Projects.Test;

using Microsoft.CRM.Contact;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using Origo.Bifrost.Projects;
using System.Text;
using System.Utilities;

/// <summary>Raw, isolated synthetic data for #86 tests. No CRONUS records or external services.</summary>
codeunit 97195 "Proj. Visit Sign Fixture ori"
{
    Access = Internal;
    /// <summary>Creates a completed 2.5-hour visit and two quantity-only usage lines.</summary>
    procedure Seed(var Visit: Record "Proj. Field Visit ori")
    var
        Job: Record Job;
        Task: Record "Job Task";
        Resource: Record Resource;
        Contact: Record Contact;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Usage: Record "TS Usage Line ori";
        Prefix: Code[20];
        Index: Integer;
    begin
        Prefix := CopyStr('X86' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Resource."No." := Prefix;
        Resource.Name := 'Synthetic technician';
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := CopyStr(UpperCase(UserId()), 1, 50);
        Resource.Insert();
        Contact."No." := Prefix;
        Contact.Name := 'Synthetic customer';
        Contact."E-Mail" := 'visit@example.invalid';
        Contact.Insert();
        Job."No." := Prefix;
        Job.Description := 'Synthetic visit report';
        Job."Sell-to Contact No." := Prefix;
        Job.Insert();
        Task."Job No." := Prefix;
        Task."Job Task No." := '100';
        Task."Job Task Type" := Task."Job Task Type"::Posting;
        Task.Insert();
        Header."No." := Prefix;
        Header."Resource No." := Prefix;
        Header."Owner User ID" := Resource."Time Sheet Owner User ID";
        Header."Starting Date" := Today();
        Header."Ending Date" := Today() + 6;
        Header.Insert();
        Line."Time Sheet No." := Prefix;
        Line."Line No." := 10000;
        Line.Type := Line.Type::Job;
        Line."Job No." := Prefix;
        Line."Job Task No." := '100';
        Line.Insert();
        Detail."Time Sheet No." := Prefix;
        Detail."Time Sheet Line No." := 10000;
        Detail.Date := Today();
        Detail.Quantity := 2.5;
        Detail.Insert();
        for Index := 1 to 2 do begin
            Usage.Init();
            Usage."Entry No." := 0;
            Usage."Time Sheet No." := Prefix;
            Usage."Time Sheet Line No." := 10000;
            Usage."Resource No." := Prefix;
            Usage.Date := Today();
            Usage.Quantity := Index;
            Usage.Description := CopyStr('Synthetic part ' + Format(Index), 1, 100);
            Usage."Unit of Measure Code" := 'PCS';
            Usage.Insert();
        end;
        Visit.Init();
        Visit."Entry No." := 0;
        Visit."Resource No." := Prefix;
        Visit."Project No." := Prefix;
        Visit."Task No." := '100';
        Visit.Date := Today();
        Visit.Status := Visit.Status::Completed;
        Visit.Kind := Visit.Kind::Work;
        Visit."Hours Written" := 2.5;
        Visit."Time Sheet No." := Prefix;
        Visit."Time Sheet Line No." := 10000;
        Visit.Outcome := 'Synthetic equipment repaired';
        Visit.Insert();
    end;

    /// <summary>Stages a synthetic one-pixel PNG; never a customer signature.</summary>
    procedure StageImage(ContentType: Text; ValidBytes: Boolean): Guid
    var
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        Base64: Codeunit "Base64 Convert";
        Output: OutStream;
        Input: InStream;
    begin
        Blob.CreateOutStream(Output);
        if ValidBytes then
            Base64.FromBase64('iVBORw0KGgoAAAANSUhEUgAAAKAAAAAyCAIAAABUA0cyAAABKklEQVR4nO2Y2w6CMBQE+/8/jYkl0RAjt5bdbmeescw5YyJSFoimqAWgLwQOh8DhEDgcAodD4HAIHA6BwyFwOAQOh8DhEDgcAofjEri8UVsEauiHqZQv0Gio4RhYuN88DZfAlbz9yjW8AleS9ivX2L960MHQWD94/Oh7hhcZfb9yjROBxxpsHo2diy+caDIYGs0Cb040GQyN5cAT0mktn8HQOMJFIZPB0NjllorJYGj8oYGEyWBo/PZpdpDHYGhsTRof5zEYGh+HLocaDIbGeveOR7NfA43ut5l8v3KNp75Hs+5XrvHs78F8+5VrKJ7rZtqvXEP3/8xguTNoqN+zqDcbr+HxvlS92UqkhsVI0A8Ch0PgcAgcDoHDIXA4BA6HwOEQOBwCh0PgcF4E84lMu1Hu3gAAAABJRU5ErkJggg==', Output)
        else
            Output.WriteText('This is a synthetic invalid image payload.');
        Blob.CreateInStream(Input);
        exit(Staging.Create(Input, 'synthetic-signature.png', ContentType, 'Projects #86 test'));
    end;

    /// <summary>Renders the native Word report to PDF and hands the bytes through staging.</summary>
    procedure Render(Visit: Record "Proj. Field Visit ori"): Guid
    var
        Blob: Codeunit "Temp Blob";
        Staging: Codeunit "Blob Staging ori";
        RecRef: RecordRef;
        Output: OutStream;
        Input: InStream;
    begin
        Visit.SetRecFilter();
        RecRef.GetTable(Visit);
        Blob.CreateOutStream(Output);
        Report.SaveAs(Report::"Proj. Visit Report ori", '', ReportFormat::Pdf, Output, RecRef);
        Blob.CreateInStream(Input);
        exit(Staging.Create(Input, 'synthetic-visit.pdf', 'application/pdf', 'Projects #86 test'));
    end;
}
