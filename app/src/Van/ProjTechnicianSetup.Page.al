namespace Origo.Bifrost.Projects;

/// <summary>Administrator page for the van location and default bin of each technician.</summary>
page 70013471 "Proj. Technician Setup ori"
{
    Caption = 'Technician Setup', Comment = 'is-IS=Uppsetning tæknimanna';
    PageType = List;
    ContextSensitiveHelpPage = 'technician-setup';
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Proj. Technician Setup ori";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Resource No."; Rec."Resource No.")
                {
                    ToolTip = 'Specifies the technician resource.', Comment = 'is-IS=Tilgreinir aðfang tæknimannsins.';
                }
                field("Van Location Code"; Rec."Van Location Code")
                {
                    ToolTip = 'Specifies the location that holds the technician''s van stock.', Comment = 'is-IS=Tilgreinir staðsetninguna sem geymir vörubirgðir í bíl tæknimannsins.';
                }
                field("Default Bin Code"; Rec."Default Bin Code")
                {
                    ToolTip = 'Specifies the bin used when a part is taken from the van without a bin.', Comment = 'is-IS=Tilgreinir hólfið sem er notað þegar vara er tekin úr bílnum án hólfs.';
                }
            }
        }
    }
}
