namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Closes ownership and decision fields to generic writes and freezes decided request content.</summary>
codeunit 70013455 "Proj. Follow-up Restrict ori"
{
    Access = Internal;
    var
        HintLbl: Label 'Use Projects.FollowUp.Request, Projects.FollowUp.Convert or Projects.FollowUp.Reject.', Comment = 'is-IS=Notaðu Projects.FollowUp.Request, Projects.FollowUp.Convert eða Projects.FollowUp.Reject.';
        OwnerLbl: Label 'Only the requesting technician or the responsible manager can edit this request.', Comment = 'is-IS=Aðeins tæknimaðurinn sem sendi beiðnina eða ábyrgur stjórnandi getur breytt henni.';
        ClosedLbl: Label 'Only an open follow-up request can be edited.', Comment = 'is-IS=Aðeins er hægt að breyta opinni eftirfylgnibeiðni.';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure Restrict(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if Managed(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure Hint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if Managed(TableNo, FieldNo) then
            Hint := HintLbl;
    end;

    local procedure Managed(TableNo: Integer; FieldNo: Integer): Boolean
    var
        Header: Record "Proj. Follow-up Request ori";
        Line: Record "Proj. Follow-up Req. Line ori";
    begin
        case TableNo of
            Database::"Proj. Follow-up Request ori":
                exit(not (FieldNo in [Header.FieldNo(Description), Header.FieldNo("Estimated Hours"), Header.FieldNo("Preferred Date"), Header.FieldNo(Urgency)]));
            Database::"Proj. Follow-up Req. Line ori":
                exit(not (FieldNo in [Line.FieldNo("Item No."), Line.FieldNo(Description), Line.FieldNo(Quantity)]));
        end;
        exit(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Proj. Follow-up Request ori", OnBeforeModifyEvent, '', false, false)]
    local procedure GuardHeader(var Rec: Record "Proj. Follow-up Request ori"; var xRec: Record "Proj. Follow-up Request ori"; RunTrigger: Boolean)
    var
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
    begin
        if Rec.IsTemporary() then
            exit;
        if not Mgt.CanEdit(Rec) then
            Error(OwnerLbl);
        if (xRec.Status <> xRec.Status::Open) and ((Rec.Description <> xRec.Description) or (Rec."Estimated Hours" <> xRec."Estimated Hours") or (Rec."Preferred Date" <> xRec."Preferred Date") or (Rec.Urgency <> xRec.Urgency)) then
            Error(ClosedLbl);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Proj. Follow-up Req. Line ori", OnBeforeModifyEvent, '', false, false)]
    local procedure GuardLine(var Rec: Record "Proj. Follow-up Req. Line ori"; var xRec: Record "Proj. Follow-up Req. Line ori"; RunTrigger: Boolean)
    var
        Header: Record "Proj. Follow-up Request ori";
        Mgt: Codeunit "Proj. Follow-up Mgt ori";
    begin
        if Rec.IsTemporary() then
            exit;
        Header.Get(Rec."Request No.");
        if not Mgt.CanEdit(Header) then
            Error(OwnerLbl);
        if Header.Status <> Header.Status::Open then
            Error(ClosedLbl);
    end;
}
