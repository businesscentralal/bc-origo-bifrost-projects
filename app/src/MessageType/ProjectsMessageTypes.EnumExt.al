namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the Projects lifecycle write messages with Foundation.</summary>
enumextension 10078485 "Projects Message Types ori" extends "Message Type ori"
{
    value(10078485; "Projects.Project.Create")
    {
        Caption = 'Projects.Project.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Create Impl ori", "Msg Discovery ori" = "Proj. Create Impl ori", "Msg Contract ori" = "Proj. Create Impl ori";
    }
    value(10078486; "Projects.Project.Update")
    {
        Caption = 'Projects.Project.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Update Impl ori", "Msg Discovery ori" = "Proj. Update Impl ori", "Msg Contract ori" = "Proj. Update Impl ori";
    }
    value(10078487; "Projects.Task.Create")
    {
        Caption = 'Projects.Task.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Create Impl ori", "Msg Discovery ori" = "Proj. Task Create Impl ori", "Msg Contract ori" = "Proj. Task Create Impl ori";
    }
    value(10078488; "Projects.Task.Update")
    {
        Caption = 'Projects.Task.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Update Impl ori", "Msg Discovery ori" = "Proj. Task Update Impl ori", "Msg Contract ori" = "Proj. Task Update Impl ori";
    }
    value(10078489; "Projects.PlanningLine.Create")
    {
        Caption = 'Projects.PlanningLine.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Create Impl ori", "Msg Discovery ori" = "Proj. Plan Create Impl ori", "Msg Contract ori" = "Proj. Plan Create Impl ori";
    }
    value(10078490; "Projects.PlanningLine.Update")
    {
        Caption = 'Projects.PlanningLine.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Update Impl ori", "Msg Discovery ori" = "Proj. Plan Update Impl ori", "Msg Contract ori" = "Proj. Plan Update Impl ori";
    }
    value(10078491; "Projects.PlanningLine.Delete")
    {
        Caption = 'Projects.PlanningLine.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Delete Impl ori", "Msg Discovery ori" = "Proj. Plan Delete Impl ori", "Msg Contract ori" = "Proj. Plan Delete Impl ori";
    }
}
