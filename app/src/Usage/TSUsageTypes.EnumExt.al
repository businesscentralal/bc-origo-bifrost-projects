namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Registers the time sheet usage message types with Foundation (projects#52).</summary>
enumextension 70013400 "TS Usage Types ori" extends "Message Type ori"
{
    value(70013410; "Projects.Usage.Register")
    {
        Caption = 'Projects.Usage.Register', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Register Impl ori", "Msg Contract ori" = "TS Usage Register Impl ori", "Msg Discovery ori" = "TS Usage Register Impl ori";
    }
    value(70013411; "Projects.Usage.Submit")
    {
        Caption = 'Projects.Usage.Submit', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Submit Impl ori", "Msg Contract ori" = "TS Usage Submit Impl ori", "Msg Discovery ori" = "TS Usage Submit Impl ori";
    }
    value(70013412; "Projects.Usage.Approve")
    {
        Caption = 'Projects.Usage.Approve', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Approve Impl ori", "Msg Contract ori" = "TS Usage Approve Impl ori", "Msg Discovery ori" = "TS Usage Approve Impl ori";
    }
    value(70013413; "Projects.Usage.Reject")
    {
        Caption = 'Projects.Usage.Reject', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Reject Impl ori", "Msg Contract ori" = "TS Usage Reject Impl ori", "Msg Discovery ori" = "TS Usage Reject Impl ori";
    }
    value(70013414; "Projects.Usage.Transfer")
    {
        Caption = 'Projects.Usage.Transfer', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Transfer Impl ori", "Msg Contract ori" = "TS Usage Transfer Impl ori", "Msg Discovery ori" = "TS Usage Transfer Impl ori";
    }
    value(70013415; "Projects.Usage.Reverse")
    {
        Caption = 'Projects.Usage.Reverse', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage Reverse Impl ori", "Msg Contract ori" = "TS Usage Reverse Impl ori", "Msg Discovery ori" = "TS Usage Reverse Impl ori";
    }
    value(70013416; "Projects.Usage.List")
    {
        Caption = 'Projects.Usage.List', Locked = true;
        Implementation = "Msg Interface ori" = "TS Usage List Impl ori", "Msg Contract ori" = "TS Usage List Impl ori", "Msg Discovery ori" = "TS Usage List Impl ori";
    }
}
