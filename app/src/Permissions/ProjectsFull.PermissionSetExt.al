namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Extends the Foundation Full role with Projects objects; no Foundation Setup tabledata grant.</summary>
permissionsetextension 10078486 "Projects Full ori" extends "BIFROST Full ori"
{
    Permissions =
        codeunit "Proj. Usage Get Impl ori" = X,
        codeunit "Proj. Usage Link Impl ori" = X,
        codeunit "Projects Usage ori" = X,
        codeunit "Proj. Statistics Impl ori" = X,
        codeunit "Proj. Budget Actual Impl ori" = X,
        codeunit "Projects Statistics ori" = X,
        codeunit "Proj. Posting Gate ori" = X,
        codeunit "Proj. WIP Post Impl ori" = X,
        codeunit "Proj. WIP Get Impl ori" = X,
        codeunit "Proj. WIP Calc Impl ori" = X,
        codeunit "Projects WIP ori" = X,
        codeunit "Proj. Status Impl ori" = X,
        codeunit "Proj. Copy Impl ori" = X,
        codeunit "Projects Contract ori" = X,
        codeunit "Projects Input ori" = X,
        codeunit "Projects Write ori" = X,
        codeunit "Projects Write Process ori" = X,
        codeunit "Proj. Create Impl ori" = X,
        codeunit "Proj. Update Impl ori" = X,
        codeunit "Proj. Task Create Impl ori" = X,
        codeunit "Proj. Task Update Impl ori" = X,
        codeunit "Proj. Plan Create Impl ori" = X,
        codeunit "Proj. Plan Update Impl ori" = X,
        codeunit "Proj. Plan Delete Impl ori" = X,
        tabledata "Projects Setup ori" = RIMD,
        codeunit "Projects Gate ori" = X,
        codeunit "Projects Registration ori" = X,
        codeunit "Projects Setup Restrict ori" = X,
        page "Projects Setup ori" = X,
        codeunit "Projects Install ori" = X;
}
