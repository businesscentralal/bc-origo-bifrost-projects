namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Opens Projects setup from the Bifröst Related menu.</summary>
pageextension 70013504 "Bifrost Projects Setup ori" extends "Bifrost ori"
{
    actions
    {
        addafter(BifrostSetup)
        {
            action(ProjectsSetup)
            {
                ApplicationArea = All;
                Caption = 'Projects Setup', Comment = 'is-IS=Uppsetning verkefna';
                ToolTip = 'Open the Projects setup for this company.', Comment = 'is-IS=Opna uppsetningu verkefna fyrir þetta fyrirtæki.';
                Image = Setup;
                RunObject = page "Projects Setup ori";
            }
        }
    }
}
