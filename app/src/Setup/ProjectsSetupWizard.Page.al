namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>Guides an administrator through HTTP, access and the Projects domains (#113).</summary>
page 70013482 "Projects Setup Wizard ori"
{
    PageType = NavigatePage;
    Caption = 'Set up Bifrost Projects', Comment = 'is-IS=Setja upp Bifröst verkefni';
    ApplicationArea = All;
    UsageCategory = Administration;
    ContextSensitiveHelpPage = 'projects';
    SourceTable = "Projects Setup ori";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            group(Welcome)
            {
                Caption = 'Welcome', Comment = 'is-IS=Velkomin';
                Visible = CurrentStep = 1;
                InstructionalText = 'Bifrost Projects adds message types for projects, tasks, planning lines, WIP and invoicing, time sheets and their approval, time sheet usage, field service visits and van stock, follow-up requests, and project reports and statistics. Each group is a domain that you turn on for this company.', Comment = 'is-IS=Bifröst verkefni bæta við skilaboðategundum fyrir verkefni, verkþætti, áætlunarlínur, VÍV og reikningagerð, tímaskýrslur og samþykkt þeirra, notkun á tímaskýrslum, heimsóknir vettvangsþjónustu og bílabirgðir, eftirfylgnibeiðnir og verkefnaskýrslur og tölfræði. Hver hópur er svið sem þú virkjar fyrir þetta fyrirtæki.';
                group(AccessExplanation)
                {
                    ShowCaption = false;
                    InstructionalText = 'AI assistants and other systems use these message types through Bifrost as the signed-in user and within that user’s permissions. The installed message types are listed on Bifrost Message Types.', Comment = 'is-IS=Gervigreindaraðstoðarmenn og önnur kerfi nota þessar skilaboðategundir í gegnum Bifröst sem innskráður notandi og innan heimilda hans. Uppsettar skilaboðategundir eru á síðunni Skilaboðategundir Bifröst.';
                }
            }
            group(Http)
            {
                Caption = 'HTTP', Comment = 'is-IS=HTTP';
                Visible = CurrentStep = 2;
                InstructionalText = 'Bifrost Projects needs outbound HTTP for licensing. HTTP is enabled in the Bifrost Setup Wizard of Bifrost Foundation; this guide only shows the status.', Comment = 'is-IS=Bifröst verkefni þurfa útleið HTTP fyrir leyfisveitingar. HTTP er virkjað í uppsetningarleiðsögn Bifröst í Bifröst Foundation; þessi leiðsögn sýnir aðeins stöðuna.';
                field(HttpStatus; HttpStatusText)
                {
                    Caption = 'Allow HttpClient Requests', Comment = 'is-IS=Leyfa HttpClient-beiðnir';
                    ToolTip = 'Shows whether the Bifrost Projects extension may make outbound HTTP requests.', Comment = 'is-IS=Sýnir hvort Bifröst verkefnaviðbótin megi senda HTTP-beiðnir út.';
                    Editable = false;
                }
                group(HttpOff)
                {
                    ShowCaption = false;
                    Visible = not HttpEnabled;
                    InstructionalText = 'Open the Bifrost Setup Wizard to enable HTTP.', Comment = 'is-IS=Opnaðu uppsetningarleiðsögn Bifröst til að virkja HTTP.';
                }
            }
            group(AccessStep)
            {
                Caption = 'Access', Comment = 'is-IS=Aðgangur';
                Visible = CurrentStep = 3;
                InstructionalText = 'Users need BIFROST Read ori or BIFROST Full ori from Bifrost Foundation. Add the Projects role sets that match the work: PROJ TS SELF ori for employees, PROJ TS APPROVER ori for approvers, PROJ TS POST ori for posting, PROJ TS ADMIN ori for time sheet administration, PROJ USAGE ori for usage, and PROJ FIELD TECH ori for field technicians. Assign them to users or through a Microsoft Entra security group.', Comment = 'is-IS=Notendur þurfa BIFROST Read ori eða BIFROST Full ori úr Bifröst Foundation. Bættu við verkefnahlutverkasamstæðum sem passa við verkin: PROJ TS SELF ori fyrir starfsmenn, PROJ TS APPROVER ori fyrir samþykkjendur, PROJ TS POST ori fyrir bókun, PROJ TS ADMIN ori fyrir umsjón tímaskýrslna, PROJ USAGE ori fyrir notkun og PROJ FIELD TECH ori fyrir tæknimenn á vettvangi. Úthlutaðu þeim til notenda eða með Microsoft Entra öryggishópi.';
            }
            group(Domains)
            {
                Caption = 'Domains', Comment = 'is-IS=Svið';
                Visible = CurrentStep = 4;
                InstructionalText = 'Turn on the Projects domains this company uses. A domain that is off hides its message types, and a call to one of them is refused. Your choices are saved when you choose Finish.', Comment = 'is-IS=Virkjaðu verkefnasviðin sem þetta fyrirtæki notar. Svið sem er óvirkt felur skilaboðategundir sínar og köllum á þær er hafnað. Val þitt vistast þegar þú velur Ljúka.';
                field(ProjectOperations; Rec."Project Operations")
                {
                }
                field(TimeSheets; Rec."Time Sheets")
                {
                }
                field(TimeSheetUsage; Rec."Time Sheet Usage")
                {
                }
                field(FieldServiceAndVan; Rec."Field Service and Van")
                {
                }
                field(FollowUpRequests; Rec."Follow-up Requests")
                {
                }
                field(ReportsAndStatistics; Rec."Reports and Statistics")
                {
                }
            }
            group(FieldService)
            {
                Caption = 'Field service', Comment = 'is-IS=Vettvangsþjónusta';
                Visible = CurrentStep = 5;
                InstructionalText = 'Set how field service visits record travel, kilometres and time.', Comment = 'is-IS=Stilltu hvernig heimsóknir vettvangsþjónustu skrá ferðir, kílómetra og tíma.';
                field(TravelWorkTypeCode; Rec."Travel Work Type Code")
                {
                    ToolTip = 'Specifies the work type used when a visit records travel time.', Comment = 'is-IS=Tilgreinir vinnutegundina sem notuð er þegar heimsókn skráir ferðatíma.';
                }
                field(MileageResourceNo; Rec."Mileage Resource No.")
                {
                    ToolTip = 'Specifies the resource used when a visit records kilometres.', Comment = 'is-IS=Tilgreinir forðann sem notaður er þegar heimsókn skráir kílómetra.';
                }
                field(RoundingMinutes; Rec."Rounding Minutes")
                {
                    ToolTip = 'Specifies how visit minutes are rounded. Zero or one uses one minute.', Comment = 'is-IS=Tilgreinir hvernig mínútur heimsóknar eru námundaðar. Núll eða einn notar eina mínútu.';
                }
                field(ClientTimeToleranceHours; Rec."Client Time Tolerance Hours")
                {
                    ToolTip = 'Specifies how many hours a client time may be in the past. Zero uses 24 hours.', Comment = 'is-IS=Tilgreinir hversu margar klukkustundir tími biðlara má vera aftur í tímann. Núll notar 24 klukkustundir.';
                }
                field(AllowUnplannedTasks; Rec."Allow Unplanned Tasks")
                {
                    ToolTip = 'Specifies whether a technician can start a visit on a task they are not planned on.', Comment = 'is-IS=Tilgreinir hvort tæknimaður megi hefja heimsókn á verkþætti sem hann er ekki skipulagður á.';
                }
                field(FollowUpTaskIncrement; Rec."Follow-up Task Increment")
                {
                }
            }
            group(FinishStep)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                Visible = CurrentStep = 6;
                InstructionalText = 'Choose Finish to save the domains and field service settings for this company.', Comment = 'is-IS=Veldu Ljúka til að vista sviðin og stillingar vettvangsþjónustu fyrir þetta fyrirtæki.';
                field(HttpSummary; HttpStatusText)
                {
                    Caption = 'HTTP', Comment = 'is-IS=HTTP';
                    ToolTip = 'Shows whether HTTP is enabled for Bifrost Projects.', Comment = 'is-IS=Sýnir hvort HTTP sé virkt fyrir Bifröst verkefni.';
                    Editable = false;
                }
                field(DomainSummary; DomainSummaryText)
                {
                    Caption = 'Domains turned on', Comment = 'is-IS=Virk svið';
                    ToolTip = 'Shows how many of the six Projects domains will be on.', Comment = 'is-IS=Sýnir hve mörg af sex verkefnasviðum verða virk.';
                    Editable = false;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ShowOperations)
            {
                Caption = 'Show message types', Comment = 'is-IS=Sýna skilaboðategundir';
                ToolTip = 'Opens Bifrost Message Types.', Comment = 'is-IS=Opnar Skilaboðategundir Bifröst.';
                Image = List;
                InFooterBar = true;
                Visible = CurrentStep = 1;
                trigger OnAction()
                begin
                    Page.RunModal(Page::"Message Type List ori");
                end;
            }
            action(OpenBifrostSetupWizard)
            {
                Caption = 'Open Bifrost Setup Wizard', Comment = 'is-IS=Opna uppsetningarleiðsögn Bifröst';
                ToolTip = 'Opens the Bifrost Setup Wizard of Bifrost Foundation, where HTTP is enabled.', Comment = 'is-IS=Opnar uppsetningarleiðsögn Bifröst í Bifröst Foundation, þar sem HTTP er virkjað.';
                Image = Setup;
                InFooterBar = true;
                Visible = (CurrentStep = 2) and not HttpEnabled;
                trigger OnAction()
                begin
                    WizardMgt.OpenBifrostSetupWizard();
                    RefreshStatus();
                end;
            }
            action(OpenUsers)
            {
                Caption = 'Open Users', Comment = 'is-IS=Opna notendur';
                ToolTip = 'Opens Users for an administrator to manage access.', Comment = 'is-IS=Opnar Notendur svo kerfisstjóri geti stjórnað aðgangi.';
                Image = Users;
                InFooterBar = true;
                Visible = CurrentStep = 3;
                trigger OnAction()
                begin
                    Page.RunModal(Page::Users);
                end;
            }
            action(OpenPermissionSets)
            {
                Caption = 'Open Permission Sets', Comment = 'is-IS=Opna heimildasamstæður';
                ToolTip = 'Opens the standard Permission Sets page.', Comment = 'is-IS=Opnar staðlaða síðu heimildasamstæðna.';
                Image = Permission;
                InFooterBar = true;
                Visible = CurrentStep = 3;
                trigger OnAction()
                begin
                    Page.RunModal(Page::"Permission Sets");
                end;
            }
            action(BackStep)
            {
                Caption = 'Back', Comment = 'is-IS=Til baka';
                ToolTip = 'Returns to the previous step.', Comment = 'is-IS=Fer í fyrra skref.';
                Image = PreviousRecord;
                InFooterBar = true;
                Visible = CurrentStep > 1;
                trigger OnAction()
                begin
                    CurrentStep -= 1;
                    if (CurrentStep = 5) and not Rec."Field Service and Van" then
                        CurrentStep := 4;
                    RefreshStatus();
                end;
            }
            action(NextStep)
            {
                Caption = 'Next', Comment = 'is-IS=Áfram';
                ToolTip = 'Continues to the next step.', Comment = 'is-IS=Fer í næsta skref.';
                Image = NextRecord;
                InFooterBar = true;
                Visible = CurrentStep < 6;
                trigger OnAction()
                begin
                    CurrentStep += 1;
                    if (CurrentStep = 5) and not Rec."Field Service and Van" then
                        CurrentStep := 6;
                    RefreshStatus();
                end;
            }
            action(Finish)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                ToolTip = 'Saves the domains and field service settings and marks this assisted setup complete.', Comment = 'is-IS=Vistar sviðin og stillingar vettvangsþjónustu og merkir þessa leiðsögðu uppsetningu lokna.';
                Image = Approve;
                InFooterBar = true;
                Visible = CurrentStep = 6;
                trigger OnAction()
                begin
                    WizardMgt.Finish(Rec);
                    CurrPage.Close();
                end;
            }
        }
    }
    var
        WizardMgt: Codeunit "Projects Wizard Mgt ori";
        CurrentStep: Integer;
        HttpEnabled: Boolean;
        HttpStatusText: Text;
        DomainSummaryText: Text;
        EnabledLbl: Label 'Enabled', Comment = 'is-IS=Virkt';
        DisabledLbl: Label 'Disabled', Comment = 'is-IS=Óvirkt';
        UnknownLbl: Label 'Cannot read the setting. Ask an administrator to verify it.', Comment = 'is-IS=Ekki er hægt að lesa stillinguna. Biddu kerfisstjóra að staðfesta hana.';
        DomainCountLbl: Label '%1 of 6', Comment = '%1 = number of domains turned on, is-IS=%1 af 6';

    trigger OnOpenPage()
    begin
        WizardMgt.LoadSetup(Rec);
        CurrentStep := 1;
        RefreshStatus();
    end;

    /// <summary>Returns the step the guide shows; used by tests.</summary>
    internal procedure GetCurrentStep(): Integer
    begin
        exit(CurrentStep);
    end;

    local procedure RefreshStatus()
    var
        Ordinal: Integer;
        OnCount: Integer;
    begin
        if WizardMgt.ReadHttpStatus(HttpEnabled) then begin
            if HttpEnabled then
                HttpStatusText := EnabledLbl
            else
                HttpStatusText := DisabledLbl;
        end else
            HttpStatusText := UnknownLbl;
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            if Rec.GetDomain(Enum::"Projects Domain ori".FromInteger(Ordinal)) then
                OnCount += 1;
        DomainSummaryText := StrSubstNo(DomainCountLbl, OnCount);
    end;
}
