namespace Origo.Bifrost.Projects;

/// <summary>
/// Permission token for the Projects Read/Full role extensions.
/// No records are stored. WritePermission() on this table is the project posting gate
/// for Projects.WIP.Post. Projects Full grants write; Projects Read grants only read.
/// </summary>
table 10078506 "Proj. Posting ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'Projects Posting Rights', Comment = 'is-IS=Bókunarréttindi verkefna';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
