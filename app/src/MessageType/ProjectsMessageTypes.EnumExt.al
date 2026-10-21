namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the Projects lifecycle write messages with Foundation.</summary>
enumextension 70009200 "Projects Message Types ori" extends "Message Type ori"
{
    value(70009200; "Projects.Project.Create")
    {
        Caption = 'Projects.Project.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Create Impl ori", "Msg Discovery ori" = "Proj. Create Impl ori", "Msg Contract ori" = "Proj. Create Impl ori";
    }
    value(70009201; "Projects.Project.Update")
    {
        Caption = 'Projects.Project.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Update Impl ori", "Msg Discovery ori" = "Proj. Update Impl ori", "Msg Contract ori" = "Proj. Update Impl ori";
    }
    value(70009202; "Projects.Task.Create")
    {
        Caption = 'Projects.Task.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Create Impl ori", "Msg Discovery ori" = "Proj. Task Create Impl ori", "Msg Contract ori" = "Proj. Task Create Impl ori";
    }
    value(70009203; "Projects.Task.Update")
    {
        Caption = 'Projects.Task.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Update Impl ori", "Msg Discovery ori" = "Proj. Task Update Impl ori", "Msg Contract ori" = "Proj. Task Update Impl ori";
    }
    value(70009204; "Projects.PlanningLine.Create")
    {
        Caption = 'Projects.PlanningLine.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Create Impl ori", "Msg Discovery ori" = "Proj. Plan Create Impl ori", "Msg Contract ori" = "Proj. Plan Create Impl ori";
    }
    value(70009205; "Projects.PlanningLine.Update")
    {
        Caption = 'Projects.PlanningLine.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Update Impl ori", "Msg Discovery ori" = "Proj. Plan Update Impl ori", "Msg Contract ori" = "Proj. Plan Update Impl ori";
    }
    value(70009206; "Projects.PlanningLine.Delete")
    {
        Caption = 'Projects.PlanningLine.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Delete Impl ori", "Msg Discovery ori" = "Proj. Plan Delete Impl ori", "Msg Contract ori" = "Proj. Plan Delete Impl ori";
    }
    value(70009207; "Projects.Project.Copy")
    {
        Caption = 'Projects.Project.Copy', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Copy Impl ori", "Msg Discovery ori" = "Proj. Copy Impl ori", "Msg Contract ori" = "Proj. Copy Impl ori";
    }

    value(70009208; "Projects.Project.SetStatus")
    {
        Caption = 'Projects.Project.SetStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Status Impl ori", "Msg Discovery ori" = "Proj. Status Impl ori", "Msg Contract ori" = "Proj. Status Impl ori";
    }

    value(70009209; "Projects.WIP.Get")
    {
        Caption = 'Projects.WIP.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Get Impl ori", "Msg Discovery ori" = "Proj. WIP Get Impl ori", "Msg Contract ori" = "Proj. WIP Get Impl ori";
    }

    value(70009210; "Projects.WIP.Calculate")
    {
        Caption = 'Projects.WIP.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Calc Impl ori", "Msg Discovery ori" = "Proj. WIP Calc Impl ori", "Msg Contract ori" = "Proj. WIP Calc Impl ori";
    }


    value(70009211; "Projects.WIP.Post")
    {
        Caption = 'Projects.WIP.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Post Impl ori", "Msg Discovery ori" = "Proj. WIP Post Impl ori", "Msg Contract ori" = "Proj. WIP Post Impl ori";
    }
    value(70009212; "Projects.Statistics.Get")
    {
        Caption = 'Projects.Statistics.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Statistics Impl ori", "Msg Discovery ori" = "Proj. Statistics Impl ori", "Msg Contract ori" = "Proj. Statistics Impl ori";
    }
    value(70009213; "Projects.BudgetVsActual.Get")
    {
        Caption = 'Projects.BudgetVsActual.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Budget Actual Impl ori", "Msg Discovery ori" = "Proj. Budget Actual Impl ori", "Msg Contract ori" = "Proj. Budget Actual Impl ori";
    }
    value(70009214; "Projects.Usage.Get")
    {
        Caption = 'Projects.Usage.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Usage Get Impl ori", "Msg Discovery ori" = "Proj. Usage Get Impl ori", "Msg Contract ori" = "Proj. Usage Get Impl ori";
    }
    value(70009215; "Projects.Usage.Link")
    {
        Caption = 'Projects.Usage.Link', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Usage Link Impl ori", "Msg Discovery ori" = "Proj. Usage Link Impl ori", "Msg Contract ori" = "Proj. Usage Link Impl ori";
    }
}
