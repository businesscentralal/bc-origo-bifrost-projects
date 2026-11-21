namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the Projects lifecycle write messages with Foundation.</summary>
enumextension 70013500 "Projects Message Types ori" extends "Message Type ori"
{
    /// <summary>Follow-up request operation.</summary>
    value(70013444; "Projects.FollowUp.Request")
    {
        Caption = 'Projects.FollowUp.Request', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. FU Req Impl ori", "Msg Discovery ori" = "Proj. FU Req Impl ori", "Msg Contract ori" = "Proj. FU Req Impl ori";
    }
    /// <summary>Follow-up list operation.</summary>
    value(70013445; "Projects.FollowUp.List")
    {
        Caption = 'Projects.FollowUp.List', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. FU List Impl ori", "Msg Discovery ori" = "Proj. FU List Impl ori", "Msg Contract ori" = "Proj. FU List Impl ori";
    }
    /// <summary>Follow-up convert operation.</summary>
    value(70013446; "Projects.FollowUp.Convert")
    {
        Caption = 'Projects.FollowUp.Convert', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. FU Conv Impl ori", "Msg Discovery ori" = "Proj. FU Conv Impl ori", "Msg Contract ori" = "Proj. FU Conv Impl ori";
    }
    /// <summary>Follow-up reject operation.</summary>
    value(70013447; "Projects.FollowUp.Reject")
    {
        Caption = 'Projects.FollowUp.Reject', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. FU Reject Impl ori", "Msg Discovery ori" = "Proj. FU Reject Impl ori", "Msg Contract ori" = "Proj. FU Reject Impl ori";
    }

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

    /// <summary>Creates project-linked purchase orders, or previews without retaining changes.</summary>
    value(70013420; "Projects.PlanningLine.CreatePurchaseOrder")
    {
        Caption = 'Projects.PlanningLine.CreatePurchaseOrder', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Purchase Impl ori", "Msg Discovery ori" = "Proj. Plan Purchase Impl ori", "Msg Contract ori" = "Proj. Plan Purchase Impl ori", "Msg Confirm ori" = "Proj. Plan Purchase Impl ori";
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
    /// <summary>Brings project item cost up to the adjusted item cost.</summary>
    value(70013552; "Projects.ItemCost.Update")
    {
        Caption = 'Projects.ItemCost.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Item Cost Impl ori", "Msg Discovery ori" = "Proj. Item Cost Impl ori", "Msg Contract ori" = "Proj. Item Cost Impl ori", "Msg Confirm ori" = "Proj. Item Cost Confirm ori";
    }
    /// <summary>Reads owner-scoped technician project information.</summary>
    value(70013427; "Projects.MyDay.Get")
    {
        Caption = 'Projects.MyDay.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. My Day Impl ori", "Msg Discovery ori" = "Proj. My Day Impl ori", "Msg Contract ori" = "Proj. My Day Impl ori";
    }
    /// <summary>Reads owner-scoped technician project information.</summary>
    value(70013428; "Projects.VisitBrief.Get")
    {
        Caption = 'Projects.VisitBrief.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Brief Impl ori", "Msg Discovery ori" = "Proj. Visit Brief Impl ori", "Msg Contract ori" = "Proj. Visit Brief Impl ori";
    }
    /// <summary>Creates linked project journal lines from budget planning lines.</summary>
    value(70013426; "Projects.PlanningLine.TransferToJournal")
    {
        Caption = 'Projects.PlanningLine.TransferToJournal', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Plan Journal Impl ori", "Msg Discovery ori" = "Proj. Plan Journal Impl ori", "Msg Contract ori" = "Proj. Plan Journal Impl ori";
    }
    /// <summary>Starts a travel or work visit on the caller's time sheet.</summary>
    value(70013433; "Projects.Visit.Start")
    {
        Caption = 'Projects.Visit.Start', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Start Impl ori", "Msg Discovery ori" = "Proj. Visit Start Impl ori", "Msg Contract ori" = "Proj. Visit Start Impl ori";
    }
    /// <summary>Stops a running visit and adds the rounded hours.</summary>
    value(70013434; "Projects.Visit.Stop")
    {
        Caption = 'Projects.Visit.Stop', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Stop Impl ori", "Msg Discovery ori" = "Proj. Visit Stop Impl ori", "Msg Contract ori" = "Proj. Visit Stop Impl ori";
    }
    /// <summary>Completes a visit and can write open mileage usage.</summary>
    value(70013435; "Projects.Visit.Complete")
    {
        Caption = 'Projects.Visit.Complete', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Complete Impl ori", "Msg Discovery ori" = "Proj. Visit Complete Impl ori", "Msg Contract ori" = "Proj. Visit Complete Impl ori";
    }
    /// <summary>Registers van parts as open usage lines for a task.</summary>
    value(70013470; "Projects.VisitItem.Register")
    {
        Caption = 'Projects.VisitItem.Register', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. VisitItem Reg Impl ori", "Msg Discovery ori" = "Proj. VisitItem Reg Impl ori", "Msg Contract ori" = "Proj. VisitItem Reg Impl ori";
    }
    /// <summary>Shows van stock after pending usage.</summary>
    value(70013471; "Projects.VanStock.Get")
    {
        Caption = 'Projects.VanStock.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. VanStock Get Impl ori", "Msg Discovery ori" = "Proj. VanStock Get Impl ori", "Msg Contract ori" = "Proj. VanStock Get Impl ori";
    }
    /// <summary>Customer sign-off and visit report.</summary>
    value(70013460; "Projects.VisitReport.Get")
    {
        Caption = 'Projects.VisitReport.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Report Impl ori", "Msg Discovery ori" = "Proj. Visit Report Impl ori", "Msg Contract ori" = "Proj. Visit Report Impl ori";
    }
    /// <summary>Customer sign-off and visit report.</summary>
    value(70013461; "Projects.Visit.SignOff")
    {
        Caption = 'Projects.Visit.SignOff', Locked = true;
        Implementation = "Msg Interface ori" = "Proj. Visit Sign Impl ori", "Msg Discovery ori" = "Proj. Visit Sign Impl ori", "Msg Contract ori" = "Proj. Visit Sign Impl ori";
    }
}
