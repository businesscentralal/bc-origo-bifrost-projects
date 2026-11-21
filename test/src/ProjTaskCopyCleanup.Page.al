namespace Origo.Bifrost.Projects.Test;

/// <summary>Operator-only cleanup for the exact unposted fixture identified by its seed manifest.</summary>
page 97177 "Proj. Task Copy Cleanup ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Project task copy acceptance cleanup';

    layout
    {
        area(Content)
        {
            field(Manifest; ManifestText)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest';
                ToolTip = 'Specifies the exact self-seeded task-copy fixture manifest.';
                MultiLine = true;
            }
            field(Result; ResultText)
            {
                ApplicationArea = All;
                Caption = 'Cleanup result';
                ToolTip = 'Shows completion after the owned task-copy fixture has been removed.';
                Editable = false;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CleanupFixture)
            {
                ApplicationArea = All;
                Caption = 'Clean owned fixture';
                ToolTip = 'Removes only the owned copy fixture named by the manifest.';
                Image = Delete;
                trigger OnAction()
                var
                    Fixture: Codeunit "Proj. Task Copy Fixture ori";
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
