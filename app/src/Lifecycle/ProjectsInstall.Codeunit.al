namespace Origo.Bifrost.Projects;

/// <summary>Creates the initial company switch on installation.</summary>
codeunit 70009202 "Projects Install ori"
{
    Access = Internal;
    Subtype = Install;
    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Projects Setup ori";
    begin
        Setup.InsertIfNotExists();
    end;
}
