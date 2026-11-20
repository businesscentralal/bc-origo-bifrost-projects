namespace Origo.Bifrost.Projects;

using System.Upgrade;

/// <summary>Backfills Time Sheet Date on existing open and posted project lines once per company (#71).</summary>
codeunit 70013580 "Proj. TS Date Upgrade ori"
{
    Access = Internal;
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
    begin
        if UpgradeTag.HasUpgradeTag(TimeSheetDateUpgradeTag()) then
            exit;
        TSDateMgt.Backfill();
        UpgradeTag.SetUpgradeTag(TimeSheetDateUpgradeTag());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerCompanyUpgradeTags', '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(TimeSheetDateUpgradeTag());
    end;

    local procedure TimeSheetDateUpgradeTag(): Code[250]
    begin
        exit('ORI-PROJECTS-71-TIMESHEETDATE-20261120');
    end;
}
