namespace Origo.Bifrost.Projects;

/// <summary>
/// Grants Bifrost Projects posting.
/// Assign explicitly. Not included in BIFROST ProjRead ori or BIFROST ProjWrite ori.
/// BIFROST ItemPost ori does not cover Projects.TransferOrder.Post or Projects.AssemblyOrder.Post.
/// </summary>
permissionset 10078508 "BIFROST ProjPost ori"
{
    Assignable = true;
    Caption = 'Proj. Posting Gate', MaxLength = 30, Comment = 'is-IS=Bókunarhlið verkefna';

    Permissions = tabledata "Proj. Posting ori" = RIMD;
}
