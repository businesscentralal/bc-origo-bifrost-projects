namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Absence;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using System.Security.User;

/// <summary>
/// Creates isolated native records for Projects.Absence.Register MCP verification.
/// Invoked explicitly by the owner in an ephemeral development environment. It does
/// not change generic write guards, licensing, consent or Foundation setup.
/// </summary>
codeunit 97137 "TS Absence MCP Fixture"
{
    Access = Internal;

    trigger OnRun()
    var
        UnitOfMeasure: Record "Unit of Measure";
        HumanResourceUnitOfMeasure: Record "Human Resource Unit of Measure";
        Cause: Record "Cause of Absence";
        Employee: Record Employee;
        UserSetup: Record "User Setup";
    begin
        if CopyStr(CompanyName(), 1, 6) <> 'CRONUS' then
            Error(WrongCompanyErr);
        // Refuse an existing fixture rather than silently replaying a setup write.
        if UnitOfMeasure.Get('XTS65') then
            Error(FixtureExistsErr);
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := 'XTS65';
        UnitOfMeasure.Description := 'Timesheets absence fixture hours';
        UnitOfMeasure.Insert(true);
        HumanResourceUnitOfMeasure.Init();
        HumanResourceUnitOfMeasure.Validate(Code, UnitOfMeasure.Code);
        HumanResourceUnitOfMeasure.Validate("Qty. per Unit of Measure", 1);
        HumanResourceUnitOfMeasure.Insert(true);
        Cause.Init();
        Cause.Code := 'XTS65';
        Cause.Description := 'Timesheets absence fixture';
        Cause.Insert(true);
        // Use the authenticated Web Client owner; never bind fixtures to another worker.
        if not UserSetup.Get(CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID"))) then begin
            UserSetup.Init();
            UserSetup.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(UserSetup."User ID")));
            UserSetup.Insert(true);
        end;
        CreateResource('XTS65-MCP');
        CreateResource('XTS65-MCPN');
        Employee.Init();
        Employee."No." := 'XTS65-MCP';
        Employee."First Name" := 'Test';
        Employee.Validate("Resource No.", 'XTS65-MCP');
        Employee.Insert(true);
        CreateSheet('XTS65-MCP', 'XTS65-MCP');
        CreateSheet('XTS65-MCPN', 'XTS65-MCPN');
    end;

    var
        WrongCompanyErr: Label 'Run the fixture in an isolated CRONUS verification company.', Locked = true;
        FixtureExistsErr: Label 'The owned absence fixture already exists. Inspect it before continuing.', Locked = true;

    local procedure CreateResource(ResourceNo: Code[20])
    var
        Resource: Record Resource;
    begin
        Resource.Init();
        Resource."No." := ResourceNo;
        Resource.Name := 'Timesheets MCP fixture resource';
        Resource.Insert(true);
        Resource.Validate(Type, Resource.Type::Person);
        Resource.Validate("Base Unit of Measure", 'XTS65');
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Validate("Use Time Sheet", true);
        Resource.Modify(true);
    end;

    local procedure CreateSheet(SheetNo: Code[20]; ResourceNo: Code[20])
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Init();
        Header."No." := SheetNo;
        Header.Validate("Resource No.", ResourceNo);
        Header.Validate("Starting Date", 20261102D);
        Header.Validate("Ending Date", 20261108D);
        Header.Insert(true);
    end;
}
