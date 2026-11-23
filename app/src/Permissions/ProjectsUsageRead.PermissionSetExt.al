namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Grants read access to time sheet usage lines and the List message to the Foundation Read role (projects#52). Base Application data comes from PROJ USAGE ori (#65).</summary>
permissionsetextension 70013401 "Projects Usage Read ori" extends "BIFROST Read ori"
{
    Permissions =
        tabledata "TS Usage Line ori" = R,
        page "TS Usage Lines ori" = X,
        codeunit "TS Usage Mgt ori" = X,
        codeunit "TS Usage Contract ori" = X,
        codeunit "TS Usage Restrict ori" = X,
        codeunit "TS Usage Journal ori" = X,
        codeunit "TS Usage List Impl ori" = X,
        codeunit "TS Usage Register Impl ori" = X,
        codeunit "TS Usage Submit Impl ori" = X,
        codeunit "TS Usage Approve Impl ori" = X,
        codeunit "TS Usage Reject Impl ori" = X,
        codeunit "TS Usage Transfer Impl ori" = X,
        codeunit "TS Usage Reverse Impl ori" = X;
}
