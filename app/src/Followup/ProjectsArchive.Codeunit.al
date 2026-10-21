namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.Comment;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Journal;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Activity;
using Microsoft.Projects.Project.Archive;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Origo.Bifrost;
using System.Environment.Configuration;

/// <summary>Creates native project archive versions and reads immutable archived task/planning snapshots.</summary>
codeunit 70009234 "Projects Archive ori"
{
    Access = Internal;

    /// <summary>Declares the project selector and optional archived version.</summary>
    procedure Parameters(CreateVersion: Boolean) Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
        ProjectLbl: Label 'Exact project number to archive or list archived versions for.', Comment = 'is-IS=Nákvæmt verkefnisnúmer til að vista útgáfu af eða lesa vistaðar útgáfur fyrir.';
        VersionLbl: Label 'Optional positive archived version number; omitted lists all versions.', Comment = 'is-IS=Valfrjálst jákvætt númer vistaðrar útgáfu; ef því er sleppt birtast allar útgáfur.';
    begin
        Result.Add(Input.Parameter('projectNo', 'string', true, ProjectLbl, 20));
        if not CreateVersion then
            Result.Add(Input.Parameter('versionNo', 'integer', false, VersionLbl, 0));
    end;

    /// <summary>Checks native read rights and, for archiving, native source and destination rights.</summary>
    procedure IsEnabled(CreateVersion: Boolean): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        if not (Gate.IsEnabled(Database::"Job Archive", false) and Gate.IsEnabled(Database::"Job Task Archive", false) and Gate.IsEnabled(Database::"Job Planning Line Archive", false) and
                Gate.IsEnabled(Database::"Job Archive", CreateVersion) and Gate.IsEnabled(Database::"Job Task Archive", CreateVersion) and Gate.IsEnabled(Database::"Job Planning Line Archive", CreateVersion)) then
            exit(false);
        if not CreateVersion then
            exit(true);
        exit(Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::"Job Planning Line", false) and
             Gate.IsEnabled(Database::"Jobs Setup", false) and Gate.IsEnabled(Database::"Comment Line", false) and Gate.IsEnabled(Database::"Comment Line Archive", true) and
             Gate.IsEnabled(Database::"Job Ledger Entry", false) and Gate.IsEnabled(Database::"Purchase Line", false) and
             Gate.IsEnabled(Database::"Job Planning Line Invoice", false) and Gate.IsEnabled(Database::"Reservation Entry", false) and
             Gate.IsEnabled(Database::"Warehouse Activity Line", false) and Gate.IsEnabled(Database::"Job Journal Line", false) and Gate.IsEnabled(Database::"Record Link", true));
    end;

    /// <summary>Validates input and dispatches archive writes through a native rollback boundary.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; CreateVersion: Boolean)
    var
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        VersionStepLbl: Label 'List versions with Projects.ProjectArchive.Get.', Comment = 'is-IS=Sýndu útgáfur með Projects.ProjectArchive.Get.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori to archive, or BIFROST Read ori to read archives, and the native project permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori til að vista útgáfu eða BIFROST Read ori til að lesa vistaðar útgáfur og innbyggðar verkefnaheimildir.';
    begin
        Request := Argument.GetRequestJson();
        if not Input.Validate(Argument, Request, Parameters(CreateVersion)) then
            exit;
        if not IsEnabled(CreateVersion) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl);
            exit;
        end;
        if Request.Contains('versionNo') then
            if Request.GetInteger('versionNo') < 1 then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'versionNo', VersionStepLbl);
                exit;
            end;
        if not CreateVersion then begin
            ReadVersions(Argument, Request);
            exit;
        end;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Archive Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Archive Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Calls the noninteractive native archive action inside its owning transaction.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Setup: Record "Jobs Setup";
        Archive: Record "Job Archive";
        ArchiveManagement: Codeunit "Job Archive Management";
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Response: JsonObject;
        MissingLbl: Label 'List versions with Projects.ProjectArchive.Get.', Comment = 'is-IS=Sýndu útgáfur með Projects.ProjectArchive.Get.';
        SetupLbl: Label 'Turn on Archive Projects in Jobs Setup.', Comment = 'is-IS=Kveiktu á vistun verkefnaútgáfa í uppsetningu verkefna.';
    begin
        Request := Argument.GetRequestJson();
        if not Project.Get(Request.GetText('projectNo')) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl);
            exit;
        end;
        if not Setup.Get() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', SetupLbl);
            exit;
        end;
        if Setup."Archive Jobs" = Setup."Archive Jobs"::Never then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', SetupLbl);
            exit;
        end;
        // The native action locks the archive table while assigning the next version.
        ArchiveManagement.StoreJob(Project, false);
        Archive.SetRange("No.", Project."No.");
        Archive.FindLast();
        Response.Add('status', 'Success');
        Response.Add('projectNo', Project."No.");
        Response.Add('versionNo', Archive."Version No.");
        Argument.SetResponseJson(Response);
    end;

    local procedure ReadVersions(var Argument: Record "Message Argument ori"; Request: JsonObject)
    var
        Archive: Record "Job Archive";
        Input: Codeunit "Projects Followup Input ori";
        Response: JsonObject;
        Versions: JsonArray;
        VersionRow: JsonObject;
        MissingLbl: Label 'List versions with Projects.ProjectArchive.Get.', Comment = 'is-IS=Sýndu útgáfur með Projects.ProjectArchive.Get.';
    begin
        Archive.ReadIsolation := IsolationLevel::ReadCommitted;
        Archive.SetRange("No.", Request.GetText('projectNo'));
        if Request.Contains('versionNo') then
            Archive.SetRange("Version No.", Request.GetInteger('versionNo'));
        Archive.SetLoadFields("No.", "Version No.", Description, "Date Archived", "Time Archived");
        if not Archive.FindSet() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl);
            exit;
        end;
        repeat
            Clear(VersionRow);
            VersionRow.Add('projectNo', Archive."No.");
            VersionRow.Add('versionNo', Archive."Version No.");
            VersionRow.Add('description', Archive.Description);
            VersionRow.Add('dateArchived', Format(Archive."Date Archived", 0, 9));
            VersionRow.Add('timeArchived', Format(Archive."Time Archived", 0, 9));
            if Request.Contains('versionNo') then begin
                VersionRow.Add('tasks', ReadTasks(Archive."No.", Archive."Version No."));
                VersionRow.Add('planningLines', ReadPlanningLines(Archive."No.", Archive."Version No."));
            end;
            Versions.Add(VersionRow);
        until Archive.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('projectNo', Request.GetText('projectNo'));
        Response.Add('versions', Versions);
        Argument.SetResponseJson(Response);
    end;

    local procedure ReadTasks(ProjectNo: Code[20]; VersionNo: Integer) Result: JsonArray
    var
        Task: Record "Job Task Archive";
        Row: JsonObject;
    begin
        Task.ReadIsolation := IsolationLevel::ReadCommitted;
        Task.SetRange("Job No.", ProjectNo);
        Task.SetRange("Version No.", VersionNo);
        Task.SetLoadFields("Job No.", "Version No.", "Job Task No.", Description, "Job Task Type", Totaling);
        if Task.FindSet() then
            repeat
                Clear(Row);
                Row.Add('taskNo', Task."Job Task No.");
                Row.Add('description', Task.Description);
                Row.Add('taskType', EnumName(Task."Job Task Type".Names(), Task."Job Task Type".Ordinals(), Task."Job Task Type".AsInteger()));
                Row.Add('totaling', Task.Totaling);
                Result.Add(Row);
            until Task.Next() = 0;
    end;

    local procedure ReadPlanningLines(ProjectNo: Code[20]; VersionNo: Integer) Result: JsonArray
    var
        Planning: Record "Job Planning Line Archive";
        Row: JsonObject;
    begin
        Planning.ReadIsolation := IsolationLevel::ReadCommitted;
        Planning.SetRange("Job No.", ProjectNo);
        Planning.SetRange("Version No.", VersionNo);
        Planning.SetLoadFields("Job No.", "Version No.", "Job Task No.", "Line No.", "No.", Description, Quantity, "Planning Date", Type, "Line Type", "Unit of Measure Code", "Unit Cost", "Unit Price", "Total Cost (LCY)", "Line Amount (LCY)");
        if Planning.FindSet() then
            repeat
                Clear(Row);
                Row.Add('taskNo', Planning."Job Task No.");
                Row.Add('lineNo', Planning."Line No.");
                Row.Add('no', Planning."No.");
                Row.Add('description', Planning.Description);
                Row.Add('quantity', Planning.Quantity);
                Row.Add('type', EnumName(Planning.Type.Names(), Planning.Type.Ordinals(), Planning.Type.AsInteger()));
                Row.Add('lineType', EnumName(Planning."Line Type".Names(), Planning."Line Type".Ordinals(), Planning."Line Type".AsInteger()));
                Row.Add('unitOfMeasureCode', Planning."Unit of Measure Code");
                Row.Add('unitCost', Planning."Unit Cost");
                Row.Add('unitPrice', Planning."Unit Price");
                Row.Add('totalCostLCY', Planning."Total Cost (LCY)");
                Row.Add('lineAmountLCY', Planning."Line Amount (LCY)");
                Row.Add('planningDate', Format(Planning."Planning Date", 0, 9));
                Result.Add(Row);
            until Planning.Next() = 0;
    end;
    local procedure EnumName(Names: List of [Text]; Ordinals: List of [Integer]; Ordinal: Integer): Text
    begin
        exit(Names.Get(Ordinals.IndexOf(Ordinal)));
    end;
}
