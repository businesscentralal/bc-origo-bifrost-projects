namespace Origo.Bifrost.Projects;

/// <summary>Administrative company switch for Projects message types.</summary>
page 70013500 "Projects Setup ori"
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
            group(FieldService)
            {
                Caption = 'Field service', Comment = 'is-IS=Vettvangsþjónusta';
                field(TravelWorkTypeCode; Rec."Travel Work Type Code")
                {
                    ToolTip = 'Specifies the work type used when a visit records travel time.', Comment = 'is-IS=Tilgreinir vinnutegundina sem notuð er þegar heimsókn skráir ferðatíma.';
                }
                field(MileageResourceNo; Rec."Mileage Resource No.")
                {
                    ToolTip = 'Specifies the resource used when a visit records kilometres.', Comment = 'is-IS=Tilgreinir forðann sem notaður er þegar heimsókn skráir kílómetra.';
                }
                field(RoundingMinutes; Rec."Rounding Minutes")
                {
                    ToolTip = 'Specifies how visit minutes are rounded. Zero or one uses one minute.', Comment = 'is-IS=Tilgreinir hvernig mínútur heimsóknar eru námundaðar. Núll eða einn notar eina mínútu.';
                }
                field(ClientTimeToleranceHours; Rec."Client Time Tolerance Hours")
                {
                    ToolTip = 'Specifies how many hours a client time may be in the past. Zero uses 24 hours.', Comment = 'is-IS=Tilgreinir hversu margar klukkustundir tími biðlara má vera aftur í tímann. Núll notar 24 klukkustundir.';
                }
                field(AllowUnplannedTasks; Rec."Allow Unplanned Tasks")
                {
                    ToolTip = 'Specifies whether a technician can start a visit on a task they are not planned on.', Comment = 'is-IS=Tilgreinir hvort tæknimaður megi hefja heimsókn á verkþætti sem hann er ekki skipulagður á.';
                }
            }
        }
    }
    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
