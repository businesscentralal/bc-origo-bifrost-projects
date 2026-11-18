namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the native time-sheet message types with Foundation (moved from Bifrost Timesheets, projects#33).</summary>
enumextension 70013579 "Projects TimeSheet Types ori" extends "Message Type ori"
{
    value(70013506; "Projects.PendingApproval.Get")
    {
        Caption = 'Projects.PendingApproval.Get', Locked = true;
        Implementation = "Msg Interface ori" = "TS Pending Approval ori", "Msg Contract ori" = "TS Pending Approval ori", "Msg Discovery ori" = "TS Pending Approval ori";
    }
    value(70013517; "Projects.TimeSheet.Approve")
    {
        Caption = 'Projects.TimeSheet.Approve', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Approve Impl ori", "Msg Contract ori" = "TS Sheet Approve Impl ori", "Msg Discovery ori" = "TS Sheet Approve Impl ori";
    }
    value(70013524; "Projects.TimeSheet.Reject")
    {
        Caption = 'Projects.TimeSheet.Reject', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Reject Impl ori", "Msg Contract ori" = "TS Sheet Reject Impl ori", "Msg Discovery ori" = "TS Sheet Reject Impl ori";
    }
    value(70013525; "Projects.TimeSheet.Submit")
    {
        Caption = 'Projects.TimeSheet.Submit', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Submit Impl ori", "Msg Contract ori" = "TS Sheet Submit Impl ori", "Msg Discovery ori" = "TS Sheet Submit Impl ori";
    }
    value(70013526; "Projects.TimeSheet.Create")
    {
        Caption = 'Projects.TimeSheet.Create', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Create Impl ori", "Msg Contract ori" = "TS Sheet Create Impl ori", "Msg Discovery ori" = "TS Sheet Create Impl ori";
    }
    value(70013527; "Projects.TimeSheet.Reopen")
    {
        Caption = 'Projects.TimeSheet.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Reopen Impl ori", "Msg Contract ori" = "TS Sheet Reopen Impl ori", "Msg Discovery ori" = "TS Sheet Reopen Impl ori";
    }
    value(70013528; "Projects.TimeSheet.Post")
    {
        Caption = 'Projects.TimeSheet.Post', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Post Impl ori", "Msg Contract ori" = "TS Sheet Post Impl ori", "Msg Discovery ori" = "TS Sheet Post Impl ori", "Msg Confirm ori" = "TS Post Confirm ori";
    }
    value(70013529; "Projects.TimeSheet.Archive")
    {
        Caption = 'Projects.TimeSheet.Archive', Locked = true;
        Implementation = "Msg Interface ori" = "TS Sheet Archive Impl ori", "Msg Contract ori" = "TS Sheet Archive Impl ori", "Msg Discovery ori" = "TS Sheet Archive Impl ori";
    }
    value(70013530; "Projects.TimeSheetLine.CopyFromPrevious")
    {
        Caption = 'Projects.TimeSheetLine.CopyFromPrevious', Locked = true;
        Implementation = "Msg Interface ori" = "TS Line CopyPrev Impl ori", "Msg Contract ori" = "TS Line CopyPrev Impl ori", "Msg Discovery ori" = "TS Line CopyPrev Impl ori";
    }
    value(70013531; "Projects.TimeSheetLine.CreateFromPlanning")
    {
        Caption = 'Projects.TimeSheetLine.CreateFromPlanning', Locked = true;
        Implementation = "Msg Interface ori" = "TS Line FromPlan Impl ori", "Msg Contract ori" = "TS Line FromPlan Impl ori", "Msg Discovery ori" = "TS Line FromPlan Impl ori";
    }
    value(70013532; "Projects.Absence.Register")
    {
        Caption = 'Projects.Absence.Register', Locked = true;
        Implementation = "Msg Interface ori" = "TS Absence Reg Impl ori", "Msg Contract ori" = "TS Absence Reg Impl ori", "Msg Discovery ori" = "TS Absence Reg Impl ori";
    }
    value(70013548; "Projects.TimeSheetLine.Set")
    {
        Caption = 'Projects.TimeSheetLine.Set', Locked = true;
        Implementation = "Msg Interface ori" = "TS Line Set Impl ori", "Msg Contract ori" = "TS Line Set Impl ori", "Msg Discovery ori" = "TS Line Set Impl ori";
    }
}
