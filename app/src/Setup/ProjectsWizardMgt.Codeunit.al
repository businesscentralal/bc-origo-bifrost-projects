namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using System.Apps;
using System.Environment.Configuration;
using System.Media;

/// <summary>Registers the Projects guide in Assisted Setup, reads and enables this app's HTTP setting and saves the guide's choices (#113).</summary>
codeunit 70013483 "Projects Wizard Mgt ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", OnRegisterAssistedSetup, '', false, false)]
    local procedure OnRegisterAssistedSetup()
    begin
        Register();
    end;

    /// <summary>Idempotently registers the Projects assisted setup.</summary>
    procedure Register()
    var
        GuidedExperience: Codeunit "Guided Experience";
        TitleLbl: Label 'Set up Bifrost Projects', Comment = 'is-IS=Setja upp Bifröst verkefni';
        ShortTitleLbl: Label 'Bifrost Projects', Comment = 'is-IS=Bifröst verkefni';
        DescriptionLbl: Label 'Review outbound HTTP, user access and the Projects domains this company uses.', Comment = 'is-IS=Farðu yfir útleið HTTP, aðgang notenda og verkefnasviðin sem þetta fyrirtæki notar.';
    begin
        GuidedExperience.InsertAssistedSetup(TitleLbl, ShortTitleLbl, DescriptionLbl, 5,
            ObjectType::Page, Page::"Projects Setup Wizard ori", Enum::"Assisted Setup Group"::Extensions,
            '', Enum::"Video Category"::Uncategorized, '', false);
    end;

    /// <summary>Reads only this extension's Allow HttpClient Requests. False means the caller cannot read it. Never writes the setting.</summary>
    procedure ReadHttpStatus(var Enabled: Boolean): Boolean
    var
        AppSetting: Record "NAV App Setting";
        Module: ModuleInfo;
    begin
        Enabled := false;
        if not AppSetting.ReadPermission() then
            exit(false);
        NavApp.GetCurrentModuleInfo(Module);
        if AppSetting.Get(Module.Id()) then
            Enabled := AppSetting."Allow HttpClient Requests";
        exit(true);
    end;

    /// <summary>Opens the Bifrost Setup Wizard of Bifrost Foundation, which owns the HTTP step.</summary>
    procedure OpenBifrostSetupWizard()
    begin
        Page.RunModal(Page::"Setup Wizard ori");
    end;

    /// <summary>Loads the company setup into the guide's buffer; a missing row shows every domain off.</summary>
    procedure LoadSetup(var Buffer: Record "Projects Setup ori" temporary)
    var
        Setup: Record "Projects Setup ori";
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if Setup.Get() then
            Buffer := Setup
        else
            Buffer.Init();
        Buffer.Insert();
    end;

    /// <summary>Saves the domains and field service settings the user chose and completes the assisted setup.</summary>
    procedure Finish(var Buffer: Record "Projects Setup ori" temporary)
    var
        Setup: Record "Projects Setup ori";
        GuidedExperience: Codeunit "Guided Experience";
        NoPermissionErr: Label 'You do not have permission to change Projects Setup. Ask an administrator with BIFROST Full ori to finish this guide.', Comment = 'is-IS=Þú hefur ekki heimild til að breyta uppsetningu verkefna. Biddu kerfisstjóra með BIFROST Full ori að ljúka þessum leiðarvísi.';
    begin
        if not Setup.WritePermission() then
            Error(NoPermissionErr);
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Project Operations" := Buffer."Project Operations";
        Setup."Time Sheets" := Buffer."Time Sheets";
        Setup."Time Sheet Usage" := Buffer."Time Sheet Usage";
        Setup."Field Service and Van" := Buffer."Field Service and Van";
        Setup."Follow-up Requests" := Buffer."Follow-up Requests";
        Setup."Reports and Statistics" := Buffer."Reports and Statistics";
        if Buffer."Field Service and Van" then begin
            Setup.Validate("Travel Work Type Code", Buffer."Travel Work Type Code");
            Setup.Validate("Mileage Resource No.", Buffer."Mileage Resource No.");
            Setup.Validate("Rounding Minutes", Buffer."Rounding Minutes");
            Setup.Validate("Client Time Tolerance Hours", Buffer."Client Time Tolerance Hours");
            Setup.Validate("Allow Unplanned Tasks", Buffer."Allow Unplanned Tasks");
            Setup.Validate("Follow-up Task Increment", Buffer."Follow-up Task Increment");
        end;
        Setup.Modify(true);
        Register();
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"Projects Setup Wizard ori");
    end;
}
