namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Maps every Projects message type to its domain (#113). A type whose domain is off is hidden from discovery and refused on execution.</summary>
codeunit 70013481 "Projects Domain Gate ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    /// <summary>Reports whether the domain of this message type is on in this company. Reading the company switch needs no Projects Setup grant, so every role (also lowered test roles) gets the domain answer instead of a permission error.</summary>
    [InherentPermissions(PermissionObjectType::TableData, Database::"Projects Setup ori", 'R')]
    procedure IsTypeEnabled(MessageType: Enum "Message Type ori"): Boolean
    var
        Setup: Record "Projects Setup ori";
    begin
        exit(Setup.IsDomainEnabled(DomainOf(MessageType)));
    end;

    /// <summary>Refuses a message type whose domain is off with PreconditionFailed and a nextStep, before any input is read or data written.</summary>
    procedure AssertTypeEnabled(var Argument: Record "Message Argument ori"; MessageType: Enum "Message Type ori"): Boolean
    var
        Domain: Enum "Projects Domain ori";
        DomainOffErr: Label 'The Projects domain "%1" is turned off for this company.', Comment = '%1 = domain name, is-IS=Verkefnasviðið „%1“ er óvirkt í þessu fyrirtæki.';
        DomainOffNextStepTxt: Label 'Ask an administrator to turn on "%1" in Projects Setup or in the Set up Bifrost Projects guide.', Comment = '%1 = domain name, is-IS=Biddu kerfisstjóra að virkja „%1“ í uppsetningu verkefna eða í leiðarvísinum Setja upp Bifröst verkefni.';
    begin
        if IsTypeEnabled(MessageType) then
            exit(true);
        Domain := DomainOf(MessageType);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DomainOffErr, Format(Domain)), 'domain', Format(Domain), '', StrSubstNo(DomainOffNextStepTxt, Format(Domain)));
        exit(false);
    end;

    /// <summary>The single domain map for all Projects message types (Gunnar 27.11.2026, card d-20261127-projects-wizard-domains).</summary>
    procedure DomainOf(MessageType: Enum "Message Type ori"): Enum "Projects Domain ori"
    begin
        case MessageType of
            "Message Type ori"::"Projects.PendingApproval.Get",
            "Message Type ori"::"Projects.TimeSheet.Approve",
            "Message Type ori"::"Projects.TimeSheet.Reject",
            "Message Type ori"::"Projects.TimeSheet.Submit",
            "Message Type ori"::"Projects.TimeSheet.Create",
            "Message Type ori"::"Projects.TimeSheet.Reopen",
            "Message Type ori"::"Projects.TimeSheet.Post",
            "Message Type ori"::"Projects.TimeSheet.Archive",
            "Message Type ori"::"Projects.TimeSheetLine.CopyFromPrevious",
            "Message Type ori"::"Projects.TimeSheetLine.CreateFromPlanning",
            "Message Type ori"::"Projects.Absence.Register",
            "Message Type ori"::"Projects.MyTimeSheet.Get",
            "Message Type ori"::"Projects.MyTimeSheet.Submit",
            "Message Type ori"::"Projects.TimeSheetApproval.Get",
            "Message Type ori"::"Projects.TimeSheetApproval.Approve",
            "Message Type ori"::"Projects.TimeSheetApproval.Reject",
            "Message Type ori"::"Projects.MyTimeSheetLine.Set",
            "Message Type ori"::"Projects.MyTimeSheet.Create",
            "Message Type ori"::"Projects.TimeSheet.Get",
            "Message Type ori"::"Projects.TimeSheetLine.Set":
                exit("Projects Domain ori"::TimeSheets);
            "Message Type ori"::"Projects.Usage.Register",
            "Message Type ori"::"Projects.Usage.Submit",
            "Message Type ori"::"Projects.Usage.Approve",
            "Message Type ori"::"Projects.Usage.Reject",
            "Message Type ori"::"Projects.Usage.Transfer",
            "Message Type ori"::"Projects.Usage.Reverse",
            "Message Type ori"::"Projects.Usage.List":
                exit("Projects Domain ori"::TimeSheetUsage);
            "Message Type ori"::"Projects.MyDay.Get",
            "Message Type ori"::"Projects.VisitBrief.Get",
            "Message Type ori"::"Projects.Visit.Start",
            "Message Type ori"::"Projects.Visit.Stop",
            "Message Type ori"::"Projects.Visit.Complete",
            "Message Type ori"::"Projects.VisitItem.Register",
            "Message Type ori"::"Projects.VanStock.Get",
            "Message Type ori"::"Projects.VisitReport.Get",
            "Message Type ori"::"Projects.Visit.SignOff":
                exit("Projects Domain ori"::FieldService);
            "Message Type ori"::"Projects.FollowUp.Request",
            "Message Type ori"::"Projects.FollowUp.List",
            "Message Type ori"::"Projects.FollowUp.Convert",
            "Message Type ori"::"Projects.FollowUp.Reject":
                exit("Projects Domain ori"::FollowUpRequests);
            "Message Type ori"::"Projects.Statistics.Get",
            "Message Type ori"::"Projects.BudgetVsActual.Get",
            "Message Type ori"::"Projects.Report.Get",
            "Message Type ori"::"Projects.ResourceAllocation.Get",
            "Message Type ori"::"Projects.ResourceCapacity.Get":
                exit("Projects Domain ori"::Reports);
        end;
        exit("Projects Domain ori"::ProjectOperations);
    end;
}
