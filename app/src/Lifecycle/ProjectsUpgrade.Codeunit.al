namespace Origo.Bifrost.Projects;

using System.Upgrade;

/// <summary>Keeps the 28.1.1 behaviour for existing companies when the #113 domain switches arrive (AC4).</summary>
codeunit 70013484 "Projects Upgrade ori"
{
    Access = Internal;
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Setup: Record "Projects Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(DomainsUpgradeTag()) then
            exit;
        Setup.UpgradeDomainsFromEnabled();
        UpgradeTag.SetUpgradeTag(DomainsUpgradeTag());
    end;

    /// <summary>Marks the domain upgrade as done for a fresh install, so a later upgrade never turns on domains the administrator left off.</summary>
    procedure SetDomainsUpgradeTagIfMissing()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(DomainsUpgradeTag()) then
            UpgradeTag.SetUpgradeTag(DomainsUpgradeTag());
    end;

    /// <summary>The per-company upgrade tag of the #113 domain switches.</summary>
    procedure DomainsUpgradeTag(): Code[250]
    begin
        exit('ORIGO-PROJECTS-113-DOMAINS-20261127');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(DomainsUpgradeTag());
    end;
}
