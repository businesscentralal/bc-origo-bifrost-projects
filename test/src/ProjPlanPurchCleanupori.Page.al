namespace Origo.Bifrost.Projects.Test;

/// <summary>Operator-only cleanup for the exact unposted fixture identified by its seed manifest.</summary>
page 97173 "Proj. Plan Purch Cleanup ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Project purchase acceptance cleanup';

    layout
    {
        area(Content)
        {
            field(Manifest; ManifestText)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest';
                ToolTip = 'Specifies the exact self-seeded fixture and original purchase numbering.';
                MultiLine = true;
            }
            field(Result; ResultText)
            {
                ApplicationArea = All;
                Caption = 'Cleanup result';
                ToolTip = 'Shows completion after the owned unposted fixture has been removed.';
                Editable = false;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PrepareFixtures)
            {
                ApplicationArea = All;
                Caption = 'Prepare owned test fixtures';
                ToolTip = 'Removes only the prior owned WIP fixture dimension defaults through the existing test library.';
                Image = Setup;
                trigger OnAction()
                var
                    Library: Codeunit "Projects Test Library ori";
                begin
                    Library.RemoveOwnedWIPDimensions();
                    ResultText := 'PREPARED';
                    CurrPage.Update(false);
                end;
            }
            action(CleanupFixture)
            {
                ApplicationArea = All;
                Caption = 'Clean owned fixture';
                ToolTip = 'Removes only the unposted owned fixture named by the manifest and restores purchase numbering.';
                Image = Delete;
                trigger OnAction()
                var
                    Fixture: Codeunit "Proj. Plan Purch Fixture ori";
                    Manifest: JsonObject;
                begin
                    Manifest.ReadFrom(ManifestText);
                    Fixture.Cleanup(Manifest);
                    ResultText := 'CLEAN';
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        ManifestText: Text;
        ResultText: Text;
}
