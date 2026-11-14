namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.Reporting;
using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Customer;

/// <summary>
/// Seeds the issue #15 MCP fixture in the worker-owned tenant only: per language a customer, a quote project, an open
/// project, a profile without any channel and a profile with a Disk channel. Nothing can leave the tenant. The MCP
/// script removes the rows afterwards (Test.Records.Delete on the XQ15 codes). Writes no licence or consent state.
/// </summary>
codeunit 97141 "Proj. Quote Send Fixture ori"
{
    Access = Internal;

    trigger OnRun()
    begin
        Seed('E');
        Seed('I');
    end;

    local procedure Seed(Language: Text[1])
    var
        Customer: Record Customer;
    begin
        if Customer.Get('XQ15W27' + Language) then
            exit;
        Customer.Init();
        Customer."No." := CopyStr('XQ15W27' + Language, 1, MaxStrLen(Customer."No."));
        Customer.Name := 'X Projects 15 MCP';
        Customer.Insert(true);
        InsertProfile('XQ15' + Language + 'N', false);
        InsertProfile('XQ15' + Language + 'D', true);
        InsertProject('XQ15W27' + Language + 'Q', Customer."No.", "Job Status"::Quote);
        InsertProject('XQ15W27' + Language + 'O', Customer."No.", "Job Status"::Open);
    end;

    local procedure InsertProfile(ProfileCode: Text; WithDisk: Boolean)
    var
        Profile: Record "Document Sending Profile";
    begin
        Profile.Init();
        Profile.Code := CopyStr(ProfileCode, 1, MaxStrLen(Profile.Code));
        Profile.Description := 'X Projects 15 MCP';
        Profile.Printer := Profile.Printer::No;
        Profile."E-Mail" := Profile."E-Mail"::No;
        Profile."Electronic Document" := Profile."Electronic Document"::No;
        Profile.Disk := Profile.Disk::No;
        if WithDisk then
            Profile.Disk := Profile.Disk::PDF;
        Profile.Insert(false);
    end;

    local procedure InsertProject(ProjectNo: Text; CustomerNo: Code[20]; Status: Enum "Job Status")
    var
        Project: Record Job;
    begin
        Project.Init();
        Project."No." := CopyStr(ProjectNo, 1, MaxStrLen(Project."No."));
        Project.Insert(true);
        Project.Validate("Bill-to Customer No.", CustomerNo);
        Project.Description := 'X Projects 15 MCP';
        Project.Status := Status;
        Project.Modify(true);
    end;
}
