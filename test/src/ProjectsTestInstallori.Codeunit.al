namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost.Projects;

/// <summary>Turns on every Projects domain in the test company (#113): new companies start with all domains off, and the component tests exercise every domain. Domain tests switch domains off themselves.</summary>
codeunit 97192 "Projects Test Install ori"
{
    Access = Internal;
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Projects Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.SetAllDomains(true);
        Setup.Modify(true);
    end;
}
