namespace Origo.Bifrost.Projects.Test;
using Microsoft.Projects.Project.Job;
/// <summary>Operator-only native fixture action in the test app. It does not execute the licensed shipping queue or prove MCP acceptance.</summary>
page 97111 "Projects UI Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Projects Native UI Fixtures', Comment = 'is-IS=Innbyggð prófunargögn verkefna';
    layout
    {
        area(Content)
        {
            label(NativeOnly)
            {
                ApplicationArea = All;
                Caption = 'Native component fixtures in the worker-owned environment only. Shipping licensing and MCP acceptance remain separate.', Comment = 'is-IS=Innbyggð prófunargögn aðeins í umhverfi starfsmanns. Leyfisprófun og MCP-samþykki eru aðskilin.';
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(CreateMcp1033)
            {
                ApplicationArea = All;
                Caption = 'Create MCP 1033 Fixtures', Comment = 'is-IS=Stofna MCP-prófunargögn 1033';
                ToolTip = 'Seeds isolated unposted WIP and unlinked usage data for the assigned language in the worker-owned environment.', Comment = 'is-IS=Stofnar aðskilin óbókuð VÍV-gögn og ótengda notkun fyrir umbeðið tungumál í umhverfi starfsmanns.';
                Image = New;
                Enabled = OwnedFixtureExists and not Mcp1033Exists;
                trigger OnAction()
                var
                    Fixture: Codeunit "Projects UI Fixture ori";
                begin
                    Fixture.SeedMcpFixture(1033);
                    CheckExistingFixture();
                    CurrPage.Update(false);
                end;
            }
            action(CreateMcp1039)
            {
                ApplicationArea = All;
                Caption = 'Create MCP 1039 Fixtures', Comment = 'is-IS=Stofna MCP-prófunargögn 1039';
                ToolTip = 'Seeds isolated unposted WIP and unlinked usage data for the assigned language in the worker-owned environment.', Comment = 'is-IS=Stofnar aðskilin óbókuð VÍV-gögn og ótengda notkun fyrir umbeðið tungumál í umhverfi starfsmanns.';
                Image = New;
                Enabled = OwnedFixtureExists and not Mcp1039Exists;
                trigger OnAction()
                var
                    Fixture: Codeunit "Projects UI Fixture ori";
                begin
                    Fixture.SeedMcpFixture(1039);
                    CheckExistingFixture();
                    CurrPage.Update(false);
                end;
            }
            action(CreateFixtures)
            {
                ApplicationArea = All;
                Caption = 'Create Owned Fixtures', Comment = 'is-IS=Stofna eigin prófunargögn';
                ToolTip = 'Creates isolated native project, planning, usage and WIP data for Web Client inspection. Never use in a customer environment.', Comment = 'is-IS=Stofnar aðskilin innbyggð verkefnis-, áætlunar-, notkunar- og VÍV-gögn til skoðunar í vefbiðlara. Aldrei nota í umhverfi viðskiptavinar.';
                Image = New;
                Enabled = not OwnedFixtureExists;
                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"Projects UI Fixture ori");
                    CheckExistingFixture();
                    CurrPage.Update(false);
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        CheckExistingFixture();
    end;
    var
        OwnedFixtureExists: Boolean;
        Mcp1033Exists: Boolean;
        Mcp1039Exists: Boolean;
    local procedure CheckExistingFixture()
    var
        Project: Record Job;
        Fixture: Codeunit "Projects UI Fixture ori";
    begin
        Mcp1033Exists := Fixture.McpFixtureExists(1033);
        Mcp1039Exists := Fixture.McpFixtureExists(1039);
        OwnedFixtureExists := Project.Get('XW4-PROJECT-UI');
    end;
}
