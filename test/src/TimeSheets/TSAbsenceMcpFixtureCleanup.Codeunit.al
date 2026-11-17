namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;

/// <summary>Removes only records created by the owned absence MCP fixture. User Setup is left in place because it may predate the fixture; the owned container teardown removes it.</summary>
codeunit 97138 "TS Absence MCP Fixture Cleanup"
{
    Access = Internal;

    trigger OnRun()
    var
        TimeSheetDetail: Record "Time Sheet Detail";
        TimeSheetLine: Record "Time Sheet Line";
        TimeSheetHeader: Record "Time Sheet Header";
        Employee: Record Employee;
        Resource: Record Resource;
        CauseOfAbsence: Record "Cause of Absence";
        HumanResourceUnitOfMeasure: Record "Human Resource Unit of Measure";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if CopyStr(CompanyName(), 1, 6) <> 'CRONUS' then
            Error(WrongCompanyErr);

        TimeSheetDetail.SetFilter("Time Sheet No.", '%1|%2', FixtureCode(), FixtureCode() + 'N');
        TimeSheetDetail.DeleteAll(true);
        TimeSheetLine.SetFilter("Time Sheet No.", '%1|%2', FixtureCode(), FixtureCode() + 'N');
        TimeSheetLine.DeleteAll(true);
        TimeSheetHeader.SetFilter("No.", '%1|%2', FixtureCode(), FixtureCode() + 'N');
        TimeSheetHeader.DeleteAll(true);
        Employee.SetRange("No.", FixtureCode());
        Employee.DeleteAll(true);
        Resource.SetFilter("No.", '%1|%2', FixtureCode(), FixtureCode() + 'N');
        Resource.DeleteAll(true);
        if CauseOfAbsence.Get(UnitCode()) then
            CauseOfAbsence.Delete(true);
        if HumanResourceUnitOfMeasure.Get(UnitCode()) then
            HumanResourceUnitOfMeasure.Delete(true);
        if UnitOfMeasure.Get(UnitCode()) then
            UnitOfMeasure.Delete(true);
    end;

    var
        WrongCompanyErr: Label 'Run fixture cleanup in the isolated CRONUS verification company.', Locked = true;

    local procedure FixtureCode(): Code[20]
    begin
        exit('XTS65-MCP');
    end;

    local procedure UnitCode(): Code[10]
    begin
        exit('XTS65');
    end;
}
