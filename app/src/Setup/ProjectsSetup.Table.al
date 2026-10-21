namespace Origo.Bifrost.Projects;

/// <summary>Company switch for Projects messages. Administrators manage it through Projects Setup.</summary>
table 70009200 "Projects Setup ori"
{
    Access = Internal;
    Caption = 'Projects Setup', Comment = 'is-IS=Uppsetning verkefna';
    DataClassification = CustomerContent;
    Extensible = false;
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
        field(10; Enabled; Boolean)
        {
            Caption = 'Enabled', Comment = 'is-IS=Virkt';
            InitValue = true;
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
    /// <summary>Initializes the company switch without changing existing administrator choices.</summary>
    procedure InsertIfNotExists()
    begin
        if Get() then
            exit;
        Init();
        Insert(true);
    end;
    /// <summary>A missing setup row leaves Projects enabled without writing during discovery.</summary>
    procedure IsEnabled(): Boolean
    begin
        if not Get() then
            exit(true);
        exit(Enabled);
    end;
}
