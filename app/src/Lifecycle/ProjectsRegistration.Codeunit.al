namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the Projects setup page in Foundation's application registry.</summary>
codeunit 10078486 "Projects Registration ori"
{
    Access = Internal;
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        Registry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        Registry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), Page::"Projects Setup ori");
    end;
}
