namespace Origo.Bifrost.Projects;

/// <summary>Prevents changes to signed visit work, including writers added by other visit features.</summary>
codeunit 70013464 "Proj. Visit Lock Guard ori"
{
    Access = Internal;
    var
        LockedErr: Label 'The signed visit is locked. Ask the project manager to unlock it.', Comment = 'is-IS=Undirrituð heimsókn er læst. Biddu verkefnisstjóra að aflæsa henni.';

    [EventSubscriber(ObjectType::Table, Database::"Proj. Field Visit ori", OnBeforeModifyEvent, '', false, false)]
    local procedure CheckVisit(var Rec: Record "Proj. Field Visit ori"; var xRec: Record "Proj. Field Visit ori"; RunTrigger: Boolean)
    var
        Setup: Record "Projects Setup ori";
    begin
        if Rec.IsTemporary() or not xRec.Locked then
            exit;
        if not Rec.Locked and not Setup.WritePermission() then
            Error(ErrorInfo.Create(LockedErr));
        if (Rec.Status <> xRec.Status) or (Rec."Hours Written" <> xRec."Hours Written") or
           (Rec."Started At" <> xRec."Started At") or (Rec."Stopped At" <> xRec."Stopped At") or
           (Rec."Usage Entry No." <> xRec."Usage Entry No.") or (Rec.Outcome <> xRec.Outcome) or
           (Rec."Project No." <> xRec."Project No.") or (Rec."Task No." <> xRec."Task No.") or
           (Rec."Resource No." <> xRec."Resource No.") or (Rec.Date <> xRec.Date)
        then
            Error(ErrorInfo.Create(LockedErr));
    end;
    /// <summary>Checks the shared visit line/date boundary before a usage writer starts its transaction.</summary>
    procedure IsUsageLocked(SheetNo: Code[20]; LineNo: Integer; UsageDate: Date): Boolean
    var
        Visit: Record "Proj. Field Visit ori";
    begin
        Visit.SetRange("Time Sheet No.", SheetNo);
        Visit.SetRange("Time Sheet Line No.", LineNo);
        Visit.SetRange(Date, UsageDate);
        Visit.ReadIsolation := IsolationLevel::UpdLock;
        if Visit.FindSet() then
            repeat
                if Visit.Locked then
                    exit(true);
            until Visit.Next() = 0;
        exit(false);
    end;

    /// <summary>Gives the localized recovery action to usage implementations.</summary>
    procedure GetUnlockHint(): Text
    begin
        exit(LockedErr);
    end;

    [EventSubscriber(ObjectType::Table, Database::"TS Usage Line ori", OnBeforeInsertEvent, '', false, false)]
    local procedure GuardUsageInsert(var Rec: Record "TS Usage Line ori"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if IsUsageLocked(Rec."Time Sheet No.", Rec."Time Sheet Line No.", Rec.Date) then
            Error(ErrorInfo.Create(LockedErr));
    end;

    [EventSubscriber(ObjectType::Table, Database::"TS Usage Line ori", OnBeforeModifyEvent, '', false, false)]
    local procedure GuardUsageModify(var Rec: Record "TS Usage Line ori"; var xRec: Record "TS Usage Line ori"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if (Rec.Quantity = xRec.Quantity) and (Rec."No." = xRec."No.") and (Rec.Type = xRec.Type) and
           (Rec.Date = xRec.Date) and (Rec."Time Sheet No." = xRec."Time Sheet No.") and
           (Rec."Time Sheet Line No." = xRec."Time Sheet Line No.") and
           (Rec."Unit of Measure Code" = xRec."Unit of Measure Code") and (Rec.Description = xRec.Description)
        then
            exit;
        if IsUsageLocked(xRec."Time Sheet No.", xRec."Time Sheet Line No.", xRec.Date) or
           IsUsageLocked(Rec."Time Sheet No.", Rec."Time Sheet Line No.", Rec.Date)
        then
            Error(ErrorInfo.Create(LockedErr));
    end;
}
