namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Grants the time sheet usage objects to the Foundation Full role (projects#52). Base Application data comes from PROJ USAGE ori (#65).</summary>
permissionsetextension 70013400 "Projects Usage Full ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "TS Usage Line ori" = RIMD,
        page "TS Usage Lines ori" = X,
        codeunit "TS Usage Mgt ori" = X,
        codeunit "TS Usage Context ori" = X,
        codeunit "TS Usage Journal ori" = X,
        codeunit "TS Usage Runner ori" = X,
        codeunit "TS Usage Contract ori" = X,
        codeunit "TS Usage Restrict ori" = X,
        codeunit "TS Usage Register Impl ori" = X,
        codeunit "TS Usage Submit Impl ori" = X,
        codeunit "TS Usage Approve Impl ori" = X,
        codeunit "TS Usage Reject Impl ori" = X,
        codeunit "TS Usage Transfer Impl ori" = X,
        codeunit "TS Usage Reverse Impl ori" = X,
        codeunit "TS Usage List Impl ori" = X;
}
