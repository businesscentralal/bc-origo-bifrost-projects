namespace Origo.Bifrost.Projects;

using Microsoft.CRM.Contact;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;

/// <summary>Quantity-only customer visit report. Uses only the selected visit and its usage lines.</summary>
report 70013460 "Proj. Visit Report ori"
{
    Caption = 'Visit Report', Comment = 'is-IS=Heimsóknarskýrsla';
    DefaultRenderingLayout = VisitWord;
    UsageCategory = None;
    ApplicationArea = All;
    dataset
    {
        dataitem(Visit; "Proj. Field Visit ori")
        {
            RequestFilterFields = "Entry No.";
            column(Title; TitleLbl) { }
            column(VisitNo; "Entry No.") { }
            column(ProjectNo; "Project No.") { IncludeCaption = true; }
            column(TaskNo; "Task No.") { IncludeCaption = true; }
            column(VisitDate; Date) { IncludeCaption = true; }
            column(Hours; "Hours Written") { IncludeCaption = true; }
            column(OutcomeText; Outcome) { IncludeCaption = true; }
            column(Signer; "Signer Name") { IncludeCaption = true; }
            column(SignedAt; "Signed At") { IncludeCaption = true; }
            column(SignatureImage; Signature) { }
            column(Recipient; RecipientEmail) { }
            dataitem(Usage; "TS Usage Line ori")
            {
                DataItemLink = "Time Sheet No." = field("Time Sheet No."), "Time Sheet Line No." = field("Time Sheet Line No."), Date = field(Date), "Resource No." = field("Resource No.");
                column(Description; Description) { IncludeCaption = true; }
                column(Quantity; Quantity) { IncludeCaption = true; }
                column(Unit; "Unit of Measure Code") { IncludeCaption = true; }
            }
            trigger OnAfterGetRecord()
            var
                Job: Record Job;
                Contact: Record Contact;
            begin
                CalcFields(Signature);
                Clear(RecipientEmail);
                if Job.Get("Project No.") then
                    if Contact.Get(Job."Sell-to Contact No.") then
                        RecipientEmail := Contact."E-Mail";
            end;
        }
    }
    rendering
    {
        layout(VisitWord)
        {
            Type = Word;
            LayoutFile = 'src/FieldService/VisitReport.docx';
            Caption = 'Visit Report', Comment = 'is-IS=Heimsóknarskýrsla';
            Summary = 'Visit time, quantities, outcome and customer signature.', Comment = 'is-IS=Heimsóknartími, magn, niðurstaða og undirskrift viðskiptavinar.';
        }
    }
    trigger OnPreReport()
    var
        SelectedVisit: Record "Proj. Field Visit ori";
        Resource: Record Resource;
    begin
        SelectedVisit.CopyFilters(Visit);
        if SelectedVisit.Count() <> 1 then
            Error(ErrorInfo.Create(SelectVisitLbl));
        SelectedVisit.FindFirst();
        if not Resource.Get(SelectedVisit."Resource No.") then
            Error(ErrorInfo.Create(OwnerLbl));
        if Resource."Time Sheet Owner User ID" <> UpperCase(UserId()) then
            Error(ErrorInfo.Create(OwnerLbl));
    end;
    var
        SelectVisitLbl: Label 'Select exactly one visit for the report.', Comment = 'is-IS=Veldu nákvæmlega eina heimsókn fyrir skýrsluna.';
        OwnerLbl: Label 'Use a visit belonging to your resource.', Comment = 'is-IS=Notaðu heimsókn sem tilheyrir þínum forða.';
        TitleLbl: Label 'Visit Report', Comment = 'is-IS=Heimsóknarskýrsla';
        RecipientEmail: Text;
}
