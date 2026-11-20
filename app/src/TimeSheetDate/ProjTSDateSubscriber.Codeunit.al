namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;

/// <summary>Fills Time Sheet Date on sales lines that Job Create-Invoice creates from project planning lines (#71).</summary>
codeunit 70013579 "Proj. TS Date Subscriber ori"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Create-Invoice", 'OnBeforeInsertSalesLine', '', false, false)]
    local procedure SetTimeSheetDateOnBeforeInsertSalesLine(var SalesLine: Record "Sales Line"; var SalesHeader: Record "Sales Header"; Job: Record Job; JobPlanningLine: Record "Job Planning Line"; JobInvCurrency: Boolean)
    var
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
    begin
        SalesLine."Time Sheet Date ori" := TSDateMgt.GetTimeSheetDate(JobPlanningLine);
    end;
}
