namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using System.Utilities;

/// <summary>Own-tenant browser fixture for a real second-session staging owner check. Test app only.</summary>
page 97197 "Proj. Visit Owner Probe ori"
{
    PageType = Card;
    Caption = 'Synthetic signature ownership check';
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            group(Probe)
            {
                field(StagingId; StagingId)
                {
                    ApplicationArea = All;
                    Caption = 'Synthetic staging id';
                    ToolTip = 'Specifies the synthetic upload created by this browser session.';
                    Editable = false;
                }
                field(OwnerId; OwnerId)
                {
                    ApplicationArea = All;
                    Caption = 'Fixture owner id';
                    ToolTip = 'Specifies the platform audit owner for comparing test sessions.';
                    Editable = false;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Stage)
            {
                ApplicationArea = All;
                Caption = 'Stage synthetic signature';
                    ToolTip = 'Creates an isolated synthetic PNG in Foundation staging.';
                Image = Import;
                trigger OnAction()
                begin
                    StagingId := Fixture.StageImage('image/png', true);
                    OwnerId := UserSecurityId();
                end;
            }
            action(Consume)
            {
                ApplicationArea = All;
                Caption = 'Consume synthetic signature';
                    ToolTip = 'Consumes only the synthetic upload owned by this browser session.';
                Image = Export;
                trigger OnAction()
                begin
                    Staging.Take(StagingId, Blob);
                    Clear(StagingId);
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        if not CompanyName().StartsWith('CRONUS') then
            Error('Only synthetic CRONUS test companies are allowed.');
    end;
    var
        Fixture: Codeunit "Proj. Visit Sign Fixture ori";
        Staging: Codeunit "Blob Staging ori";
        Blob: Codeunit "Temp Blob";
        StagingId: Guid;
        OwnerId: Guid;
}
