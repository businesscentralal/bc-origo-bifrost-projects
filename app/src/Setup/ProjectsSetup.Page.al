namespace Origo.Bifrost.Projects;

/// <summary>Administrative company switch for Projects message types.</summary>
page 10078485 "Projects Setup ori"
{
    ApplicationArea = All;
    Caption = 'Projects Setup', Comment = 'is-IS=Uppsetning verkefna';
    ContextSensitiveHelpPage = 'projects';
    PageType = Card;
    SourceTable = "Projects Setup ori";
    UsageCategory = Administration;
    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General', Comment = 'is-IS=Almennt';
                field(Enabled; Rec.Enabled)
                {
                    ToolTip = 'Specifies whether Projects message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort verkefnaskilaboð séu virk fyrir þetta fyrirtæki.';
                }
            }
        }
    }
    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
