namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Requisition;
using Microsoft.Projects.Project.Planning;
using Microsoft.Inventory.Planning;

/// <summary>Scopes native planning subscribers to the active purchase calculation only.</summary>
codeunit 70013423 "Proj. Plan Purchase Scope ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Get Unplanned Demand", 'OnBeforeGetUnplannedJobPlanningLine', '', false, false)]
    local procedure BudgetDemandOnly(var UnplannedDemand: Record "Unplanned Demand"; var JobPlanningLine: Record "Job Planning Line")
    begin
        JobPlanningLine.SetRange("Schedule Line", true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Req. Wksh.-Make Order", 'OnCodeOnBeforeInitProgressWindow', '', false, false)]
    local procedure HideNativeProgress(ReqTemplate: Record "Req. Wksh. Template"; var HideProgressWindow: Boolean)
    begin
        HideProgressWindow := true;
    end;
}
