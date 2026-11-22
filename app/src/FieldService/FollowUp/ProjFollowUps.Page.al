namespace Origo.Bifrost.Projects;

/// <summary>Shows requests and the manager decisions linked to project work.</summary>
page 70013447 "Proj. Follow-ups ori"
{
    PageType = List;
    ContextSensitiveHelpPage = 'projects';
    SourceTable = "Proj. Follow-up Request ori";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Project Follow-up Requests', Comment = 'is-IS=Eftirfylgnibeiðnir verkefna';
    Editable = false;
    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Project No."; Rec."Project No.") { ApplicationArea = All; }
                field("Task No."; Rec."Task No.") { ApplicationArea = All; }
                field("Resource No."; Rec."Resource No.") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
                field("Estimated Hours"; Rec."Estimated Hours") { ApplicationArea = All; }
                field("Preferred Date"; Rec."Preferred Date") { ApplicationArea = All; }
                field("Urgency"; Rec."Urgency") { ApplicationArea = All; }
                field("Status"; Rec."Status") { ApplicationArea = All; }
                field("Converted Task No."; Rec."Converted Task No.") { ApplicationArea = All; }
                field("Resource Planning Line No."; Rec."Resource Planning Line No.") { ApplicationArea = All; }
                field("Decided At"; Rec."Decided At") { ApplicationArea = All; }
                field("Rejection Reason"; Rec."Rejection Reason") { ApplicationArea = All; }
            }
        }
    }
    trigger OnOpenPage()
    var
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
    begin
        Mgt.FilterVisible(Rec);
    end;
}
