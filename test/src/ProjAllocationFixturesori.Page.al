namespace Origo.Bifrost.Projects.Test;

/// <summary>Explicit owned nonfinancial fixture actions; the real allocation message is exercised separately through the queue.</summary>
page 97128 "Proj Allocation Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Owned Allocation Fixtures', Comment = 'is-IS=Eigin prófunargögn ráðstöfunar';

    layout
    {
        area(Content)
        {
            label(OwnedOnly)
            {
                ApplicationArea = All;
                Caption = 'Use only in the worker-owned verification environment. Fixture creation does not prove shipping licensing or MCP acceptance.', Comment = 'is-IS=Notist aðeins í eigin sannprófunarumhverfi starfsmanns. Stofnun prófunargagna sannar hvorki leyfi né MCP-samþykki.';
            }
            field(Manifest; ManifestText)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest', Comment = 'is-IS=Yfirlit prófunargagna';
                ToolTip = 'Shows actual owned keys, expected read results and remaining owned records.', Comment = 'is-IS=Sýnir eigin lykla, væntanlegar lesniðurstöður og fjölda eigin færslna sem eftir eru.';
                MultiLine = true;
                Editable = false;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SeedAllocation)
            {
                ApplicationArea = All;
                Caption = 'Seed allocation fixture', Comment = 'is-IS=Stofna prófunargögn ráðstöfunar';
                ToolTip = 'Creates only unique owned nonfinancial resource/project capacity and allocation fixtures.', Comment = 'is-IS=Stofnar aðeins einkvæm eigin ófjárhagsleg prófunargögn afkastagetu og ráðstöfunar forða og verkefna.';
                Image = New;
                trigger OnAction()
                var
                    Fixture: Codeunit "Proj Allocation Fixture ori";
                begin
                    ManifestText := Fixture.Seed();
                    CurrPage.Update(false);
                end;
            }
            action(CleanupAllocation)
            {
                ApplicationArea = All;
                Caption = 'Clean allocation fixture', Comment = 'is-IS=Hreinsa prófunargögn ráðstöfunar';
                ToolTip = 'Deletes only this fixture instance records and reports the actual remaining count.', Comment = 'is-IS=Eyðir aðeins færslum þessa prófunartilviks og sýnir raunverulegan fjölda færslna sem eftir eru.';
                Image = Delete;
                trigger OnAction()
                var
                    Fixture: Codeunit "Proj Allocation Fixture ori";
                begin
                    ManifestText := Fixture.Cleanup();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Fixture: Codeunit "Proj Allocation Fixture ori";
    begin
        ManifestText := Fixture.State();
    end;

    var
        ManifestText: Text;
}
