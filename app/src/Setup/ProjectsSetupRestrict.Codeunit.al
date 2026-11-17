namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Prevents generic Data.Records.Set calls from changing the administrative company switch.</summary>
codeunit 70013503 "Projects Setup Restrict ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;
    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictSetupTable(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Projects Setup ori" then
            IsRestricted := true;
    end;
}
