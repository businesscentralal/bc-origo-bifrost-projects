namespace Origo.Bifrost.Projects.Test;

/// <summary>Creates and removes the fixed usage verification records. Own tenant only.</summary>
page 97155 "TS Usage Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Usage Verification Fixture', Comment = 'is-IS=Prófunargögn notkunar';

    actions
    {
        area(Processing)
        {
            action(CreateFixture)
            {
                Caption = 'Create Fixture', Comment = 'is-IS=Stofna prófunargögn';
                ToolTip = 'Create the fixture sheet, item and resource.', Comment = 'is-IS=Stofna prófunartímaskýrslu, vöru og aðfang.';
                Image = Create;

                trigger OnAction()
                var
                    Fixture: Codeunit "TS Usage Fixture ori";
                begin
                    Fixture.Create();
                end;
            }
            action(SwapToApprover)
            {
                Caption = 'Become Approver', Comment = 'is-IS=Verða samþykktaraðili';
                ToolTip = 'Make the current user approver of the fixture sheet.', Comment = 'is-IS=Gera núverandi notanda að samþykktaraðila prófunartímaskýrslunnar.';
                Image = Approve;

                trigger OnAction()
                var
                    Fixture: Codeunit "TS Usage Fixture ori";
                begin
                    Fixture.SwapToApprover();
                end;
            }
            action(RemoveFixture)
            {
                Caption = 'Remove Fixture', Comment = 'is-IS=Eyða prófunargögnum';
                ToolTip = 'Remove the fixture records.', Comment = 'is-IS=Eyða prófunargögnum.';
                Image = Delete;

                trigger OnAction()
                var
                    Fixture: Codeunit "TS Usage Fixture ori";
                begin
                    Fixture.Remove();
                end;
            }
        }
    }
}
