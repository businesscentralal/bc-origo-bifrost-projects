namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Combines the company switch with the caller's effective native table permissions.</summary>
codeunit 10078485 "Projects Gate ori"
{
    Access = Internal;
    /// <summary>Checks native read or write permission without elevating the caller.</summary>
    procedure IsEnabled(TableNo: Integer; NeedWrite: Boolean): Boolean
    var
        Setup: Record "Projects Setup ori";
        Target: RecordRef;
    begin
        if not Setup.IsEnabled() then
            exit(false);
        Target.Open(TableNo);
        if NeedWrite then
            exit(Target.WritePermission());
        exit(Target.ReadPermission());
    end;
    /// <summary>Returns a Bifrost error for disabled or unauthorized calls before reading input or writing data.</summary>
    procedure AssertEnabled(var Argument: Record "Message Argument ori"; TableNo: Integer; NeedWrite: Boolean): Boolean
    var
        Setup: Record "Projects Setup ori";
        DisabledErr: Label 'Projects messages are disabled for this company.', Comment = 'is-IS=Verkefnaskilaboð eru óvirk fyrir þetta fyrirtæki.';
        DeniedErr: Label 'Permission denied for this Projects message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa verkefnaskilaboðategund.';
        EnableTxt: Label 'Enable Projects in Projects Setup.', Comment = 'is-IS=Virkjaðu verkefni í uppsetningu verkefna.';
    begin
        if not Setup.IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DisabledErr, '', '', '', EnableTxt);
            exit(false);
        end;
        if IsEnabled(TableNo, NeedWrite) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedErr, '', '', '', '');
        exit(false);
    end;
}
