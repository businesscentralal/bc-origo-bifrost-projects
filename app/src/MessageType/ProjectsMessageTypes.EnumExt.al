namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the Projects lifecycle write messages with Foundation.</summary>
enumextension 70013500 "Projects Message Types ori" extends "Message Type ori"
{
    /// <summary>Appends tasks and native planning lines into an existing project.</summary>
    value(70013425; "Projects.Task.CopyFrom")
    {
        Caption = 'Projects.Task.CopyFrom', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Copy Impl ori", "Msg Discovery ori" = "Proj. Task Copy Impl ori", "Msg Contract ori" = "Proj. Task Copy Impl ori", "Msg Confirm ori" = "Proj. Task Copy Impl ori";
    }

    /// <summary>Reverses posted WIP through correcting general ledger entries.</summary>
    value(70013400; "Projects.WIP.Reverse")
    {
        Caption = 'Projects.WIP.Reverse', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Reverse Impl ori", "Msg Discovery ori" = "Proj. WIP Reverse Impl ori", "Msg Contract ori" = "Proj. WIP Reverse Impl ori", "Msg Confirm ori" = "Proj. WIP Reverse Impl ori";
    }

    value(70013500; "Projects.Project.Create")
    {
        Caption = 'Projects.Project.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Create Impl ori", "Msg Discovery ori" = "Proj. Create Impl ori", "Msg Contract ori" = "Proj. Create Impl ori";
    }
    value(70013501; "Projects.Project.Update")
    {
        Caption = 'Projects.Project.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Update Impl ori", "Msg Discovery ori" = "Proj. Update Impl ori", "Msg Contract ori" = "Proj. Update Impl ori";
    }
    value(70013502; "Projects.Task.Create")
    {
        Caption = 'Projects.Task.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Create Impl ori", "Msg Discovery ori" = "Proj. Task Create Impl ori", "Msg Contract ori" = "Proj. Task Create Impl ori";
    }
    value(70013503; "Projects.Task.Update")
    {
        Caption = 'Projects.Task.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Update Impl ori", "Msg Discovery ori" = "Proj. Task Update Impl ori", "Msg Contract ori" = "Proj. Task Update Impl ori";
    }
    value(70013504; "Projects.PlanningLine.Create")
    {
        Caption = 'Projects.PlanningLine.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Create Impl ori", "Msg Discovery ori" = "Proj. Plan Create Impl ori", "Msg Contract ori" = "Proj. Plan Create Impl ori";
    }
    value(70013505; "Projects.PlanningLine.Update")
    {
        Caption = 'Projects.PlanningLine.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Update Impl ori", "Msg Discovery ori" = "Proj. Plan Update Impl ori", "Msg Contract ori" = "Proj. Plan Update Impl ori";
    }
    value(70013507; "Projects.Project.Copy")
    {
        Caption = 'Projects.Project.Copy', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Copy Impl ori", "Msg Discovery ori" = "Proj. Copy Impl ori", "Msg Contract ori" = "Proj. Copy Impl ori";
    }

    value(70013508; "Projects.Project.SetStatus")
    {
        Caption = 'Projects.Project.SetStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Status Impl ori", "Msg Discovery ori" = "Proj. Status Impl ori", "Msg Contract ori" = "Proj. Status Impl ori";
    }

    value(70013509; "Projects.WIP.Get")
    {
        Caption = 'Projects.WIP.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Get Impl ori", "Msg Discovery ori" = "Proj. WIP Get Impl ori", "Msg Contract ori" = "Proj. WIP Get Impl ori";
    }

    value(70013510; "Projects.WIP.Calculate")
    {
        Caption = 'Projects.WIP.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Calc Impl ori", "Msg Discovery ori" = "Proj. WIP Calc Impl ori", "Msg Contract ori" = "Proj. WIP Calc Impl ori";
    }


    value(70013511; "Projects.WIP.Post")
    {
        Caption = 'Projects.WIP.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Post Impl ori", "Msg Discovery ori" = "Proj. WIP Post Impl ori", "Msg Contract ori" = "Proj. WIP Post Impl ori";
    }
    value(70013512; "Projects.Statistics.Get")
    {
        Caption = 'Projects.Statistics.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Statistics Impl ori", "Msg Discovery ori" = "Proj. Statistics Impl ori", "Msg Contract ori" = "Proj. Statistics Impl ori";
    }
    value(70013513; "Projects.BudgetVsActual.Get")
    {
        Caption = 'Projects.BudgetVsActual.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Budget Actual Impl ori", "Msg Discovery ori" = "Proj. Budget Actual Impl ori", "Msg Contract ori" = "Proj. Budget Actual Impl ori";
    }
    value(70013514; "Projects.Usage.Get")
    {
        Caption = 'Projects.Usage.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Usage Get Impl ori", "Msg Discovery ori" = "Proj. Usage Get Impl ori", "Msg Contract ori" = "Proj. Usage Get Impl ori";
    }
    value(70013515; "Projects.Usage.Link")
    {
        Caption = 'Projects.Usage.Link', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Usage Link Impl ori", "Msg Discovery ori" = "Proj. Usage Link Impl ori", "Msg Contract ori" = "Proj. Usage Link Impl ori";
    }
    value(70013518; "Projects.Project.Archive")
    {
        Caption = 'Projects.Project.Archive', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Archive Impl ori", "Msg Discovery ori" = "Proj. Archive Impl ori", "Msg Contract ori" = "Proj. Archive Impl ori";
    }
    value(70013519; "Projects.PurchaseLine.Link")
    {
        Caption = 'Projects.PurchaseLine.Link', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Purchase Impl ori", "Msg Discovery ori" = "Proj. Purchase Impl ori", "Msg Contract ori" = "Proj. Purchase Impl ori";
    }
    value(70013520; "Projects.ItemUsage.Post")
    {
        Caption = 'Projects.ItemUsage.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Item Usage Impl ori", "Msg Discovery ori" = "Proj. Item Usage Impl ori", "Msg Contract ori" = "Proj. Item Usage Impl ori";
    }
    value(70013523; "Projects.ProjectArchive.Get")
    {
        Caption = 'Projects.ProjectArchive.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Archive Get Impl ori", "Msg Discovery ori" = "Proj. Archive Get Impl ori", "Msg Contract ori" = "Proj. Archive Get Impl ori";
    }
    value(70013540; "Projects.WIPMethod.Get")
    {
        Caption = 'Projects.WIPMethod.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Method Get ori", "Msg Discovery ori" = "Proj. WIP Method Get ori", "Msg Contract ori" = "Proj. WIP Method Get ori";
    }
    value(70013541; "Projects.WIPMethod.Set")
    {
        Caption = 'Projects.WIPMethod.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. WIP Method Set ori", "Msg Discovery ori" = "Proj. WIP Method Set ori", "Msg Contract ori" = "Proj. WIP Method Set ori";
    }
    value(70013516; "Projects.ResourceAllocation.Get")
    {
        Caption = 'Projects.ResourceAllocation.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Allocation Impl ori", "Msg Discovery ori" = "Proj. Allocation Impl ori", "Msg Contract ori" = "Proj. Allocation Impl ori";
    }
    value(70013521; "Projects.Report.Get")
    {
        Caption = 'Projects.Report.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Report Impl ori", "Msg Discovery ori" = "Proj. Report Impl ori", "Msg Contract ori" = "Proj. Report Impl ori";
    }
    value(70013522; "Projects.Quote.Send")
    {
        Caption = 'Projects.Quote.Send', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Quote Send Impl ori", "Msg Discovery ori" = "Proj. Quote Send Impl ori", "Msg Contract ori" = "Proj. Quote Send Impl ori";
    }
    /// <summary>Reads resource capacity, time-sheet hours and usage per period.</summary>
    value(70013550; "Projects.ResourceCapacity.Get")
    {
        Caption = 'Projects.ResourceCapacity.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Capacity Impl ori", "Msg Discovery ori" = "Proj. Capacity Impl ori", "Msg Contract ori" = "Proj. Capacity Impl ori";
    }
    value(70013406; "Projects.Task.Indent")
    {
        Caption = 'Projects.Task.Indent', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Task Indent Impl ori", "Msg Discovery ori" = "Proj. Task Indent Impl ori", "Msg Contract ori" = "Proj. Task Indent Impl ori";
    }
    /// <summary>Moves dates across a project or task range.</summary>
    value(70013533; "Projects.PlanningLine.ShiftDates")
    {
        Caption = 'Projects.PlanningLine.ShiftDates', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Shift Dates Impl ori", "Msg Discovery ori" = "Proj. Shift Dates Impl ori", "Msg Contract ori" = "Proj. Shift Dates Impl ori";
    }
}
