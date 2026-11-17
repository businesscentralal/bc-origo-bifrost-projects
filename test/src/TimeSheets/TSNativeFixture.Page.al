namespace Origo.Bifrost.Projects.Test;

/// <summary>Creates isolated MCP fixtures only in the named worker-owned verification company.</summary>
page 97118 "TS Native Fixture"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Time Sheet Verification Fixture', Comment = 'is-IS=Prófunargögn tímaskýrslna';

    layout
    {
        area(Content)
        {
            field(FixtureCreated; FixtureCreated)
            {
                ApplicationArea = All;
                Caption = 'Fixture Created', Comment = 'is-IS=Prófunargögn stofnuð';
                ToolTip = 'Specifies whether this session created the isolated verification records.', Comment = 'is-IS=Tilgreinir hvort þessi seta stofnaði einangruðu prófunarfærslurnar.';
                Editable = false;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateFixture)
            {
                ApplicationArea = All;
                Caption = 'Create Fixture', Comment = 'is-IS=Stofna prófunargögn';
                ToolTip = 'Create new resources, time sheets and project planning for MCP verification in the owned test company.', Comment = 'is-IS=Stofna nýjar auðlindir, tímaskýrslur og verkáætlun fyrir MCP-prófun í eigin prófunarfyrirtæki.';
                Image = Create;

                trigger OnAction()
                var
                    NativeTests: Codeunit "TS Fill Sheet Tests";
                begin
                    NativeTests.SeedMcpFixtures(UserId());
                    FixtureCreated := true;
                end;
            }
        }
    }

    var
        FixtureCreated: Boolean;
}
