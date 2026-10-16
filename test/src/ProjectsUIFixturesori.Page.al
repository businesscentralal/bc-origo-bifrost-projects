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
    local procedure CheckExistingFixture()
    var
        Project: Record Job;
    begin
        OwnedFixtureExists := Project.Get('XW4-PROJECT-UI');
    end;
}
