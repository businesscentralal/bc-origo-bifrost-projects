namespace Origo.Bifrost.Projects;

/// <summary>Approver view of time sheet usage lines by status. Changes go through the Projects.Usage.* messages.</summary>
page 70013400 "TS Usage Lines ori"
{
    Caption = 'Time Sheet Usage Lines', Comment = 'is-IS=Notkunarlínur tímaskýrslna';
    PageType = List;
    ContextSensitiveHelpPage = 'ts-usage-lines';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "TS Usage Line ori";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the entry number.', Comment = 'is-IS=Tilgreinir færslunúmerið.';
                }
                field("Time Sheet No."; Rec."Time Sheet No.")
                {
                    ToolTip = 'Specifies the time sheet the usage belongs to.', Comment = 'is-IS=Tilgreinir tímaskýrsluna sem notkunin tilheyrir.';
                }
                field("Time Sheet Line No."; Rec."Time Sheet Line No.")
                {
                    ToolTip = 'Specifies the time sheet line the usage is linked to.', Comment = 'is-IS=Tilgreinir tímaskýrslulínuna sem notkunin er tengd við.';
                }
                field("Resource No."; Rec."Resource No.")
                {
                    ToolTip = 'Specifies the resource that registered the usage.', Comment = 'is-IS=Tilgreinir aðfangið sem skráði notkunina.';
                }
                field(Type; Rec.Type)
                {
                    ToolTip = 'Specifies whether an item or a resource was used.', Comment = 'is-IS=Tilgreinir hvort vara eða aðfang var notað.';
                }
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the item or resource number.', Comment = 'is-IS=Tilgreinir vöru- eða aðfangsnúmerið.';
                }
                field(Date; Rec.Date)
                {
                    ToolTip = 'Specifies the date of the usage.', Comment = 'is-IS=Tilgreinir dagsetningu notkunarinnar.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity used.', Comment = 'is-IS=Tilgreinir magnið sem var notað.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies the unit of measure.', Comment = 'is-IS=Tilgreinir mælieininguna.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the location the item was taken from, for example the technician''s van.', Comment = 'is-IS=Tilgreinir staðsetninguna sem varan var tekin úr, til dæmis bíl tæknimannsins.';
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ToolTip = 'Specifies the bin the item was taken from.', Comment = 'is-IS=Tilgreinir hólfið sem varan var tekin úr.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the lot number of the item used.', Comment = 'is-IS=Tilgreinir lotunúmer vörunnar sem var notuð.';
                }
                field("Serial No."; Rec."Serial No.")
                {
                    ToolTip = 'Specifies the serial number of the item used.', Comment = 'is-IS=Tilgreinir raðnúmer vörunnar sem var notuð.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies a description of the usage.', Comment = 'is-IS=Tilgreinir lýsingu á notkuninni.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the state of the usage line.', Comment = 'is-IS=Tilgreinir stöðu notkunarlínunnar.';
                }
                field(Reversed; Rec.Reversed)
                {
                    ToolTip = 'Specifies that the posted usage has been reversed.', Comment = 'is-IS=Tilgreinir að bókuð notkun hafi verið bakfærð.';
                }
                field("Approved By"; Rec."Approved By")
                {
                    ToolTip = 'Specifies who approved the usage.', Comment = 'is-IS=Tilgreinir hver samþykkti notkunina.';
                }
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ToolTip = 'Specifies the journal template the usage was transferred to.', Comment = 'is-IS=Tilgreinir færslubókarsniðmátið sem notkunin var flutt í.';
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ToolTip = 'Specifies the journal batch the usage was transferred to.', Comment = 'is-IS=Tilgreinir færslubókarkeyrsluna sem notkunin var flutt í.';
                }
                field("Journal Line No."; Rec."Journal Line No.")
                {
                    ToolTip = 'Specifies the journal line number.', Comment = 'is-IS=Tilgreinir línunúmer færslubókar.';
                }
            }
        }
    }
}
