namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;

/// <summary>Test-extension-only seed adapter; no delete operation is registered.</summary>
codeunit 97182 "Proj. Plan Journal Seed ori" implements "Msg Interface ori"
{
    Access = Internal;

    /// <summary>Limits fixture discovery to the CRONUS test companies.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(CompanyName().StartsWith('CRONUS'));
    end;

    /// <summary>No native filter table is exposed.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Describes the test-only seed operation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Seed owned project planning journal acceptance fixtures.');
    end;

    /// <summary>Declares fixture creation.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Seeds raw resource and stocked-item demand and returns the cleanup manifest.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Fixture: Codeunit "Proj. Plan Journal Fixture ori";
    begin
        if not IsEnabled() then
            Error('Only CRONUS test companies are allowed.');
        Argument.SetResponseJson(Fixture.Seed());
    end;
}
