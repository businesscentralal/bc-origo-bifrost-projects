namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;

/// <summary>Creates and removes only Sindri's isolated Submit acceptance fixtures.</summary>
page 97135 "TS Submit Fixtures"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Submit verification fixtures', Comment = 'is-IS=Prófunargögn innsendingar';

    layout
    {
        area(Content)
        {
            group(OwnedData)
            {
                Caption = 'Owned data', Comment = 'is-IS=Eigin gögn';
                field(Sheet; SheetNo)
                {
                    ApplicationArea = All;
                    Caption = 'Time sheet', Comment = 'is-IS=Tímaskýrsla';
                    ToolTip = 'Specifies the owned sheet used by the Submit verification.', Comment = 'is-IS=Tilgreinir eigin tímaskýrslu sem er notuð við prófun innsendingar.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateOwnedFixtures)
            {
                Image = New;
                ApplicationArea = All;
                Caption = 'Create owned fixtures', Comment = 'is-IS=Stofna eigin prófunargögn';
                ToolTip = 'Creates isolated resource and time sheet records for this acceptance check.', Comment = 'is-IS=Stofnar einangruð auðlinda- og tímaskýrslugögn fyrir prófunina.';
                trigger OnAction()
                begin
                    CreateFixtures();
                end;
            }
            action(CleanupOwnedFixtures)
            {
                Image = Delete;
                ApplicationArea = All;
                Caption = 'Clean owned fixtures', Comment = 'is-IS=Hreinsa eigin prófunargögn';
                ToolTip = 'Removes only the exact resource and time sheets created by this fixture.', Comment = 'is-IS=Fjarlægir aðeins þá auðlind og tímaskýrslur sem þessi prófun stofnaði.';
                trigger OnAction()
                begin
                    CleanupFixtures();
                end;
            }
        }
    }

    var
        SheetNo: Code[20];
        ResourceNoTok: Label 'XSINDRI60', Locked = true;
        ExistingErr: Label 'Owned fixtures already exist. Inspect and clean them before creating again.', Comment = 'is-IS=Eigin prófunargögn eru þegar til. Skoðaðu þau og hreinsaðu áður en þau eru stofnuð aftur.';

    local procedure CreateFixtures()
    var
        Resource: Record Resource;
        Setup: Record "Resources Setup";
    begin
        if Resource.Get(ResourceNoTok) then
            Error(ExistingErr);
        Setup.Get();
        Resource.Init();
        Resource."No." := ResourceNoTok;
        Resource.Type := Resource.Type::Person;
        Resource."Use Time Sheet" := true;
        Resource."Time Sheet Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Resource."Time Sheet Owner User ID"));
        Resource."Time Sheet Approver User ID" := Resource."Time Sheet Owner User ID";
        Resource.Insert(false);
        CreateSheet('XSINDRI60-OK', false, false, false);
        CreateSheet('XSINDRI60-BAD', true, false, false);
        CreateSheet('XSINDRI60-OWNER', false, true, false);
        CreateSheet('XSINDRI60-EMPTY', false, false, true);
        SheetNo := 'XSINDRI60-OK';
    end;

    local procedure CreateSheet(NewSheetNo: Code[20]; Invalid: Boolean; OtherOwner: Boolean; Empty: Boolean)
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
    begin
        Header.Init();
        Header."No." := NewSheetNo;
        Header."Resource No." := ResourceNoTok;
        Header."Starting Date" := CalcDate('<-CW>', WorkDate());
        case NewSheetNo of
            'XSINDRI60-BAD':
                Header."Starting Date" -= 7;
            'XSINDRI60-OWNER':
                Header."Starting Date" -= 14;
            'XSINDRI60-EMPTY':
                Header."Starting Date" -= 21;
        end;
        Header."Ending Date" := Header."Starting Date" + 6;
        Header."Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Owner User ID"));
        if OtherOwner then
            Header."Owner User ID" := 'XSINDRI60-OTHER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Insert(false);
        if Empty then
            exit;
        Line.Init();
        Line."Time Sheet No." := NewSheetNo;
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        if Invalid then
            Line.Type := Line.Type::Job;
        Line.Insert(false);
        Detail.Init();
        Detail."Time Sheet No." := NewSheetNo;
        Detail."Time Sheet Line No." := Line."Line No.";
        Detail.Date := Header."Starting Date";
        Detail.Quantity := 8;
        Detail.Insert(false);
    end;

    local procedure CleanupFixtures()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
        OwnedSheets: List of [Code[20]];
        OwnedSheet: Code[20];
    begin
        OwnedSheets.Add('XSINDRI60-OK');
        OwnedSheets.Add('XSINDRI60-BAD');
        OwnedSheets.Add('XSINDRI60-OWNER');
        OwnedSheets.Add('XSINDRI60-EMPTY');
        foreach OwnedSheet in OwnedSheets do
            if Header.Get(OwnedSheet) then begin
                Header.TestField("Resource No.", ResourceNoTok);
                Detail.SetRange("Time Sheet No.", OwnedSheet);
                Detail.DeleteAll(false);
                Line.SetRange("Time Sheet No.", OwnedSheet);
                Line.DeleteAll(false);
                Header.Delete(false);
            end;
        if Resource.Get(ResourceNoTok) then
            Resource.Delete(false);
        Clear(SheetNo);
    end;
}
