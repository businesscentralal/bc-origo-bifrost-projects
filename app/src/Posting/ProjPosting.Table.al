namespace Origo.Bifrost.Projects;

/// <summary>
/// Permission token for BIFROST ProjPost ori.
/// No records are stored. WritePermission() on this table is the project posting gate
/// for Projects.TransferOrder.Post and Projects.AssemblyOrder.Post.
/// </summary>
table 10078506 "Proj. Posting ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'BIFROST ProjPost ori', Comment = 'is-IS=Bifröst bókun verkefna';
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
