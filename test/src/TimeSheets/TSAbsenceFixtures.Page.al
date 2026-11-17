namespace Origo.Bifrost.Projects.Test;

/// <summary>Runs the isolated absence fixture through an authenticated Web Client session.</summary>
page 97115 "TS Absence Fixtures"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Absence verification fixtures', Locked = true;

    actions
    {
        area(Processing)
        {
            action(CreateFixtures)
            {
                ApplicationArea = All;
                Caption = 'Create owned absence fixtures', Locked = true;
                ToolTip = 'Creates isolated absence data in a CRONUS verification company.', Locked = true;
                Image = New;

                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"TS Absence MCP Fixture");
                end;
            }
            action(DeleteFixtures)
            {
                ApplicationArea = All;
                Caption = 'Delete owned absence fixtures', Locked = true;
                ToolTip = 'Deletes the isolated absence data created by this fixture in a CRONUS verification company.', Locked = true;
                Image = Delete;

                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"TS Absence MCP Fixture Cleanup");
                end;
            }
        }
    }
}
