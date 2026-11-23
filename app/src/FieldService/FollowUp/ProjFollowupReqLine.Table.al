namespace Origo.Bifrost.Projects;

/// <summary>Parts and photo bytes belonging to one follow-up request.</summary>
table 70013445 "Proj. Follow-up Req. Line ori"
{
    Caption = 'Project Follow-up Line', Comment = 'is-IS=Eftirfylgnilína verkefnis';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Request No."; Integer)
        {
            Caption = 'Request No.', Comment = 'is-IS=Beiðninúmer';
            ToolTip = 'Specifies request no..', Comment = 'is-IS=Tilgreinir beiðninúmer.';
            
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.', Comment = 'is-IS=Línunúmer';
            ToolTip = 'Specifies line no..', Comment = 'is-IS=Tilgreinir línunúmer.';
            
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.', Comment = 'is-IS=Vörunúmer';
            ToolTip = 'Specifies item no..', Comment = 'is-IS=Tilgreinir vörunúmer.';
            
        }
        field(4; "Description"; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
            ToolTip = 'Specifies description.', Comment = 'is-IS=Tilgreinir lýsing.';
            
        }
        field(5; "Quantity"; Decimal)
        {
            Caption = 'Quantity', Comment = 'is-IS=Magn';
            ToolTip = 'Specifies quantity.', Comment = 'is-IS=Tilgreinir magn.';
            trigger OnValidate()
            var
                PositiveLbl: Label 'The requested quantity must be greater than zero.', Comment = 'is-IS=Umbeðið magn verður að vera stærra en núll.';
            begin
                if Quantity <= 0 then
                    Error(PositiveLbl);
            end;
        }
        field(6; "Planning Line No."; Integer)
        {
            Caption = 'Planning Line No.', Comment = 'is-IS=Áætlunarlínunúmer';
            ToolTip = 'Specifies planning line no..', Comment = 'is-IS=Tilgreinir áætlunarlínunúmer.';
            
        }
        field(7; "Photo"; Blob)
        {
            Caption = 'Photo', Comment = 'is-IS=Ljósmynd';
            ToolTip = 'Specifies photo.', Comment = 'is-IS=Tilgreinir ljósmynd.';
            
        }
        field(8; "File Name"; Text[250])
        {
            Caption = 'File Name', Comment = 'is-IS=Skráarheiti';
            ToolTip = 'Specifies file name.', Comment = 'is-IS=Tilgreinir skráarheiti.';
            
        }
        field(9; "Content Type"; Text[100])
        {
            Caption = 'Content Type', Comment = 'is-IS=Efnistegund';
            ToolTip = 'Specifies content type.', Comment = 'is-IS=Tilgreinir efnistegund.';
            
        }
        field(10; "Is Photo"; Boolean)
        {
            Caption = 'Is Photo', Comment = 'is-IS=Er ljósmynd';
            ToolTip = 'Specifies is photo.', Comment = 'is-IS=Tilgreinir er ljósmynd.';
            
        }
    }
    keys
    {
        key(PK; "Request No.", "Line No.") { Clustered = true; }
    }
}
