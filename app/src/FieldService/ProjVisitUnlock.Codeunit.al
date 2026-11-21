namespace Origo.Bifrost.Projects;

/// <summary>Manager-only native unlock entry point. Execute permission is granted only through Projects Full.</summary>
codeunit 70013466 "Proj. Visit Unlock ori"
{
    Access = Internal;
    TableNo = "Proj. Field Visit ori";

    trigger OnRun()
    var
        Visit: Record "Proj. Field Visit ori";
        Setup: Record "Projects Setup ori";
        DeniedLbl: Label 'Only a project manager can unlock a signed visit.', Comment = 'is-IS=Aðeins verkefnisstjóri getur aflæst undirritaðri heimsókn.';
    begin
        if not Setup.WritePermission() then
            Error(ErrorInfo.Create(DeniedLbl));
        Visit.LockTable();
        Visit.Get(Rec."Entry No.");
        Visit.Locked := false;
        Visit.Signed := false;
        Visit.Modify(true);
        Rec := Visit;
    end;
}
