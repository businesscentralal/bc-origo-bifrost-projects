namespace Origo.Bifrost.Projects;

/// <summary>A technician request retained after a manager converts or rejects it.</summary>
table 70013444 "Proj. Follow-up Request ori"
{
    Caption = 'Project Follow-up Request', Comment = 'is-IS=Eftirfylgnibeiðni verkefnis';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Request No.', Comment = 'is-IS=Beiðninúmer';
            ToolTip = 'Specifies request no..', Comment = 'is-IS=Tilgreinir beiðninúmer.';
            AutoIncrement = true;
        }
        field(2; "Project No."; Code[20])
        {
            Caption = 'Project No.', Comment = 'is-IS=Verkefnisnúmer';
            ToolTip = 'Specifies project no..', Comment = 'is-IS=Tilgreinir verkefnisnúmer.';
            
        }
        field(3; "Task No."; Code[20])
        {
            Caption = 'Original Task No.', Comment = 'is-IS=Upprunalegur verkþáttur';
            ToolTip = 'Specifies original task no..', Comment = 'is-IS=Tilgreinir upprunalegur verkþáttur.';
            
        }
        field(4; "Resource No."; Code[20])
        {
            Caption = 'Technician Resource No.', Comment = 'is-IS=Forði tæknimanns';
            ToolTip = 'Specifies technician resource no..', Comment = 'is-IS=Tilgreinir forði tæknimanns.';
            
        }
        field(5; "Description"; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
            ToolTip = 'Specifies description.', Comment = 'is-IS=Tilgreinir lýsing.';
            
        }
        field(6; "Estimated Hours"; Decimal)
        {
            Caption = 'Estimated Hours', Comment = 'is-IS=Áætlaðar stundir';
            ToolTip = 'Specifies estimated hours.', Comment = 'is-IS=Tilgreinir áætlaðar stundir.';
            trigger OnValidate()
            var
                PositiveLbl: Label 'Estimated hours must be greater than zero.', Comment = 'is-IS=Áætlaðar stundir verða að vera stærri en núll.';
            begin
                if "Estimated Hours" <= 0 then
                    Error(PositiveLbl);
            end;
        }
        field(7; "Preferred Date"; Date)
        {
            Caption = 'Preferred Date', Comment = 'is-IS=Óskadagsetning';
            ToolTip = 'Specifies preferred date.', Comment = 'is-IS=Tilgreinir óskadagsetning.';
            
        }
        field(8; "Urgency"; Text[20])
        {
            Caption = 'Urgency', Comment = 'is-IS=Forgangur';
            ToolTip = 'Specifies urgency.', Comment = 'is-IS=Tilgreinir forgangur.';
            
        }
        field(9; "Status"; Enum "Proj. Follow-up Status ori")
        {
            Caption = 'Status', Comment = 'is-IS=Staða';
            ToolTip = 'Specifies status.', Comment = 'is-IS=Tilgreinir staða.';
            
        }
        field(10; "Converted Task No."; Code[20])
        {
            Caption = 'Converted Task No.', Comment = 'is-IS=Stofnaður verkþáttur';
            ToolTip = 'Specifies converted task no..', Comment = 'is-IS=Tilgreinir stofnaður verkþáttur.';
            
        }
        field(11; "Resource Planning Line No."; Integer)
        {
            Caption = 'Resource Planning Line No.', Comment = 'is-IS=Áætlunarlína forða';
            ToolTip = 'Specifies resource planning line no..', Comment = 'is-IS=Tilgreinir áætlunarlína forða.';
            
        }
        field(12; "Decided By"; Guid)
        {
            Caption = 'Decided By', Comment = 'is-IS=Ákveðið af';
            ToolTip = 'Specifies decided by.', Comment = 'is-IS=Tilgreinir ákveðið af.';
            DataClassification = EndUserPseudonymousIdentifiers;
        }
        field(13; "Decided At"; DateTime)
        {
            Caption = 'Decided At', Comment = 'is-IS=Ákvörðunartími';
            ToolTip = 'Specifies decided at.', Comment = 'is-IS=Tilgreinir ákvörðunartími.';
            
        }
        field(14; "Client Request Id"; Text[100])
        {
            Caption = 'Client Request Id.', Comment = 'is-IS=Auðkenni beiðni biðlara';
            ToolTip = 'Specifies client request id..', Comment = 'is-IS=Tilgreinir auðkenni beiðni biðlara.';
            
        }
        field(15; "Requested By"; Guid)
        {
            Caption = 'Requested By', Comment = 'is-IS=Beðið um af';
            ToolTip = 'Specifies requested by.', Comment = 'is-IS=Tilgreinir beðið um af.';
            DataClassification = EndUserPseudonymousIdentifiers;
        }
        field(16; "Rejection Reason"; Text[250])
        {
            Caption = 'Rejection Reason', Comment = 'is-IS=Ástæða höfnunar';
            ToolTip = 'Specifies rejection reason.', Comment = 'is-IS=Tilgreinir ástæða höfnunar.';
            
        }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(OwnerRequest; "Requested By", "Client Request Id") { }
        key(ProjectTask; "Project No.", "Task No.", Status) { }
    }
}
