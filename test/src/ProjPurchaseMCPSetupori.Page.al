namespace Origo.Bifrost.Projects.Test;

/// <summary>Operator-only test page exposes the self-seeded fixture identifiers for shipping MCP verification.</summary>
page 97132 "Proj. Purchase MCP Setup ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Projects Purchase MCP Fixtures';

    layout
    {
        area(Content)
        {
            field(ManifestControl; ManifestText)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest';
                ToolTip = 'Shows unique owned fixture identifiers; delete the disposable verification container to clean posted data.';
                Editable = false;
                MultiLine = true;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(SeedFixtures)
            {
                ApplicationArea = All;
                Caption = 'Seed purchase fixtures';
                ToolTip = 'Creates native purchase, project and tracked stock data only in the owner disposable test environment.';
                Image = New;
                Enabled = ManifestText = '';
                trigger OnAction()
                begin
                    SeedOwnedFixtures();
                end;
            }
        }
    }

    var
        ManifestText: Text;

    local procedure SeedOwnedFixtures()
    var
        Fixture: Codeunit "Proj. Purchase MCP Fixture ori";
        Manifest: JsonObject;
    begin
        if ManifestText <> '' then
            exit;
        Manifest := Fixture.Seed();
        Manifest.WriteTo(ManifestText);
        CurrPage.Update(false);
    end;
}
