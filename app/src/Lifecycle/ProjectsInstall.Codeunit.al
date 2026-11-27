namespace Origo.Bifrost.Projects;

/// <summary>Creates the initial company switch on installation.</summary>
codeunit 70013502 "Projects Install ori"
{
    Access = Internal;
    Subtype = Install;
    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Projects Setup ori";
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
        Upgrade: Codeunit "Projects Upgrade ori";
    begin
        Setup.InsertIfNotExists();
        Upgrade.SetDomainsUpgradeTagIfMissing();
        TSDateMgt.Backfill();
    end;
}
