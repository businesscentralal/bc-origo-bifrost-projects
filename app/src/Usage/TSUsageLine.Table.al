namespace Origo.Bifrost.Projects;

/// <summary>
/// Item or resource usage registered by a user on a time sheet line (tools, km driven, bolts).
/// Status, Reversed and the journal fields change only through the Projects.Usage.* messages.
/// </summary>
table 70013400 "TS Usage Line ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'Time Sheet Usage Line', Comment = 'is-IS=Notkunarlína tímaskýrslu';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "Time Sheet No."; Code[20])
        {
            Caption = 'Time Sheet No.', Comment = 'is-IS=Tímaskýrslunr.';
        }
        field(3; "Time Sheet Line No."; Integer)
        {
            Caption = 'Time Sheet Line No.', Comment = 'is-IS=Línunr. tímaskýrslu';
        }
        field(4; "Resource No."; Code[20])
        {
            Caption = 'Resource No.', Comment = 'is-IS=Aðfangsnr. starfsmanns';
        }
        field(5; Type; Enum "TS Usage Type ori")
        {
            Caption = 'Type', Comment = 'is-IS=Tegund';
        }
        field(6; "No."; Code[20])
        {
            Caption = 'No.', Comment = 'is-IS=Nr.';
        }
        field(7; Date; Date)
        {
            Caption = 'Date', Comment = 'is-IS=Dagsetning';
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Quantity', Comment = 'is-IS=Magn';
            DecimalPlaces = 0 : 5;
        }
        field(9; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code', Comment = 'is-IS=Einingarkóði';
        }
        field(10; Description; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
        }
        field(11; Status; Enum "TS Usage Status ori")
        {
            Caption = 'Status', Comment = 'is-IS=Staða';
        }
        field(12; Reversed; Boolean)
        {
            Caption = 'Reversed', Comment = 'is-IS=Bakfært';
        }
        field(13; "Approved By"; Code[50])
        {
            Caption = 'Approved By', Comment = 'is-IS=Samþykkt af';
        }
        field(14; "Approved At"; DateTime)
        {
            Caption = 'Approved At', Comment = 'is-IS=Samþykkt þann';
        }
        field(15; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name', Comment = 'is-IS=Heiti færslubókarsniðmáts';
        }
        field(16; "Journal Batch Name"; Code[10])
        {
            Caption = 'Journal Batch Name', Comment = 'is-IS=Heiti færslubókarkeyrslu';
        }
        field(17; "Journal Line No."; Integer)
        {
            Caption = 'Journal Line No.', Comment = 'is-IS=Línunr. færslubókar';
        }
        field(18; "Ledger Entry No."; Integer)
        {
            Caption = 'Ledger Entry No.', Comment = 'is-IS=Færslunr. í höfuðbók';
        }
        field(19; "Reject Comment"; Text[250])
        {
            Caption = 'Reject Comment', Comment = 'is-IS=Athugasemd við höfnun';
        }
        field(20; "Document No."; Code[20])
        {
            Caption = 'Document No.', Comment = 'is-IS=Skjalanr.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Sheet; "Time Sheet No.", "Time Sheet Line No.")
        {
        }
        key(Document; "Document No.")
        {
        }
        key(Journal; Type, "Journal Template Name", "Journal Batch Name", "Journal Line No.")
        {
        }
    }
}
