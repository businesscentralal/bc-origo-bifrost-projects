namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Origo.Bifrost;

/// <summary>Validates and runs the native Update Project Item Cost for Projects.ItemCost.Update (#77).</summary>
codeunit 70013408 "Projects Item Cost ori"
{
    Access = Internal;

    var
        MissingLbl: Label 'Send projectNos with 1 to 100 project numbers, or allOpen as true.', Comment = 'is-IS=Sendu projectNos með 1 til 100 verkefnisnúmerum, eða allOpen sem true.';
        ConflictLbl: Label 'Send either projectNos or allOpen, not both.', Comment = 'is-IS=Sendu annaðhvort projectNos eða allOpen, ekki bæði.';
        NotFoundLbl: Label 'Send the numbers of existing projects.', Comment = 'is-IS=Sendu númer verkefna sem eru til.';
        CompletedLbl: Label 'A completed project is not updated. Change its status with Projects.Project.SetStatus first, or leave it out.', Comment = 'is-IS=Lokið verkefni er ekki uppfært. Breyttu stöðu þess með Projects.Project.SetStatus fyrst, eða slepptu því.';
        FormatLbl: Label 'Send allOpen as true or false and projectNos as an array of at most 100 project numbers of at most 20 characters each.', Comment = 'is-IS=Sendu allOpen sem true eða false og projectNos sem fylki með í mesta lagi 100 verkefnisnúmerum, hvert með í mesta lagi 20 stöfum.';
        DatesLbl: Label 'Send postingDateFrom on or before postingDateTo.', Comment = 'is-IS=Sendu postingDateFrom sama dag og postingDateTo eða fyrr.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and the native permissions to change project ledger entries.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar heimildir til að breyta verkefnisfærslum.';

    /// <summary>Declares the request keys.</summary>
    procedure Parameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Result.Add(Input.Parameter('projectNos', 'array', false, 'Array of 1 to 100 exact project numbers (strings of at most 20 characters). Send either projectNos or allOpen.', 0));
        Result.Add(Input.Parameter('allOpen', 'boolean', false, 'true updates every project in status Planning, Quote or Open. Send either projectNos or allOpen.', 0));
        Result.Add(Input.Parameter('postingDateFrom', 'date', false, 'Optional ISO date (YYYY-MM-DD): only usage with this posting date or later is updated.', 0));
        Result.Add(Input.Parameter('postingDateTo', 'date', false, 'Optional ISO date (YYYY-MM-DD): only usage with this posting date or earlier is updated.', 0));
        Result.Add(Input.Parameter('expectedCount', 'integer', false, 'expectedCount counts the projects in scope: the projects named in projectNos, or every project in status Planning, Quote or Open for allOpen. Required only when Require Confirmation for Irreversible Messages is enabled in Bifrost Setup; always checked when sent. Preview without a side effect: send the request without expectedCount and read expected.', 0));
    end;

    /// <summary>Checks the posting token and the native rights to read and change the project ledger.</summary>
    procedure IsEnabled(): Boolean
    var
        Posting: Codeunit "Proj. Posting Gate ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Posting.HasPostingPermission() and Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Ledger Entry", false) and
             Gate.IsEnabled(Database::"Job Ledger Entry", true) and Gate.IsEnabled(Database::"Job Planning Line", false) and
             Gate.IsEnabled(Database::"Job Planning Line", true));
    end;

    /// <summary>Counts the projects in scope without refusing; false when the request is unusable.</summary>
    /// <param name="Argument">The request carrier; nothing is answered.</param>
    /// <param name="Projects">Receives the project numbers in scope.</param>
    procedure CountScope(var Argument: Record "Message Argument ori"; var Projects: List of [Code[20]]): Boolean
    var
        Request: JsonObject;
        FromDate: Date;
        ToDate: Date;
    begin
        Request := Argument.GetRequestJson();
        if not ReadDates(Request, FromDate, ToDate) then
            exit(false);
        exit(ResolveScope(Argument, Request, false, Projects));
    end;

    /// <summary>Runs the isolated write; a native error answers the Business Central error and rolls back.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Projects: List of [Code[20]];
    begin
        if not Validate(Argument, Argument.GetRequestJson(), Projects) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Item Cost Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Item Cost Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Checks keys, types, rights and scope; answers the first refusal.</summary>
    procedure Validate(var Argument: Record "Message Argument ori"; Request: JsonObject; var Projects: List of [Code[20]]): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
        Token: JsonToken;
        Raw: Text;
        FromDate: Date;
        ToDate: Date;
    begin
        if not Input.Validate(Argument, Request, Parameters()) then
            exit(false);
        if Request.Get('allOpen', Token) then begin
            Token.WriteTo(Raw);
            if not (Raw in ['true', 'false']) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'allOpen', FormatLbl));
        end;
        if not IsEnabled() then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl));
        if not ReadDates(Request, FromDate, ToDate) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'postingDateFrom', DatesLbl));
        exit(ResolveScope(Argument, Request, true, Projects));
    end;

    local procedure ReadDates(Request: JsonObject; var FromDate: Date; var ToDate: Date): Boolean
    var
        Token: JsonToken;
    begin
        FromDate := 0D;
        ToDate := 0D;
        if Request.Get('postingDateFrom', Token) then
            if not (Token.IsValue() and Evaluate(FromDate, Token.AsValue().AsText(), 9)) then
                exit(false);
        if Request.Get('postingDateTo', Token) then
            if not (Token.IsValue() and Evaluate(ToDate, Token.AsValue().AsText(), 9)) then
                exit(false);
        if (FromDate <> 0D) and (ToDate <> 0D) and (FromDate > ToDate) then
            exit(false);
        exit(true);
    end;

    local procedure IsAllOpen(Request: JsonObject): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get('allOpen', Token) then
            exit(false);
        Token.WriteTo(Raw);
        exit(Raw = 'true');
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; Refuse: Boolean; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; NextStep: Text): Boolean
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        if Refuse then
            Input.Refuse(Argument, ErrorCode, ParameterName, NextStep);
        exit(false);
    end;

    /// <summary>Resolves the projects in scope; Refuse false answers nothing and only reports usability.</summary>
    local procedure ResolveScope(var Argument: Record "Message Argument ori"; Request: JsonObject; Refuse: Boolean; var Projects: List of [Code[20]]): Boolean
    var
        Project: Record Job;
        Token: JsonToken;
        Items: JsonArray;
        Raw: Text;
        ProjectNo: Text;
        HasNos: Boolean;
        AllOpen: Boolean;
    begin
        Clear(Projects);
        HasNos := Request.Contains('projectNos');
        AllOpen := IsAllOpen(Request);
        if HasNos and AllOpen then
            exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::ConflictingIdentifiers, 'allOpen', ConflictLbl));
        if not (HasNos or AllOpen) then
            exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::MissingParameter, 'projectNos', MissingLbl));
        Project.ReadIsolation := IsolationLevel::ReadCommitted;
        if AllOpen then begin
            Project.SetFilter(Status, '<>%1', Project.Status::Completed);
            if Project.FindSet() then
                repeat
                    Projects.Add(Project."No.");
                until Project.Next() = 0;
            exit(true);
        end;
        if not Request.Get('projectNos', Token) or not Token.IsArray() then
            exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::InvalidParameterFormat, 'projectNos', FormatLbl));
        Items := Token.AsArray();
        if Items.Count() = 0 then
            exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::MissingParameter, 'projectNos', MissingLbl));
        if Items.Count() > 100 then
            exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::InvalidParameterFormat, 'projectNos', FormatLbl));
        foreach Token in Items do begin
            if not Token.IsValue() then
                exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::InvalidParameterFormat, 'projectNos', FormatLbl));
            Token.WriteTo(Raw);
            ProjectNo := Token.AsValue().AsText();
            if not Raw.StartsWith('"') or (ProjectNo.Trim() = '') or (StrLen(ProjectNo) > MaxStrLen(Project."No.")) then
                exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::InvalidParameterFormat, 'projectNos', FormatLbl));
            if not Project.Get(CopyStr(ProjectNo, 1, MaxStrLen(Project."No."))) then
                exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::RecordNotFound, 'projectNos', NotFoundLbl));
            if Project.Status = Project.Status::Completed then
                exit(Fail(Argument, Refuse, "Bifrost Error Code ori"::PreconditionFailed, 'projectNos', CompletedLbl));
            if not Projects.Contains(Project."No.") then
                Projects.Add(Project."No.");
        end;
        exit(true);
    end;

    /// <summary>Runs the native Update Project Item Cost once for the scope and answers the per-project change.</summary>
    [CommitBehavior(CommitBehavior::Error)]
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Ledger: Record "Job Ledger Entry";
        Before: Record "Job Ledger Entry" temporary;
        UpdateCost: Report "Update Job Item Cost";
        Request: JsonObject;
        Response: JsonObject;
        Entry: JsonObject;
        Rows: JsonArray;
        Projects: List of [Code[20]];
        Counts: Dictionary of [Code[20], Integer];
        Changes: Dictionary of [Code[20], Decimal];
        ProjectNo: Code[20];
        FromDate: Date;
        ToDate: Date;
        ProjectFilter: Text;
        Total: Integer;
        SummaryLbl: Label 'Updated the item cost on %1 project ledger entries in %2 projects.', Comment = '%1 = entries, %2 = projects, is-IS=Vörukostnaður uppfærður á %1 verkefnisfærslum í %2 verkefnum.';
    begin
        Request := Argument.GetRequestJson();
        Project.LockTable();
        if not Validate(Argument, Request, Projects) then
            exit;
        ReadDates(Request, FromDate, ToDate);
        foreach ProjectNo in Projects do begin
            Counts.Add(ProjectNo, 0);
            Changes.Add(ProjectNo, 0);
            SetScope(Ledger, ProjectNo, FromDate, ToDate);
            if Ledger.FindSet() then
                repeat
                    Before := Ledger;
                    Before.Insert();
                until Ledger.Next() = 0;
            if ProjectFilter <> '' then
                ProjectFilter += '|';
            Project.SetFilter("No.", '%1', ProjectNo);
            ProjectFilter += Project.GetFilter("No.");
        end;
        if Projects.Count() > 0 then begin
            Project.Reset();
            Project.SetFilter("No.", ProjectFilter);
            SetScope(Ledger, '', FromDate, ToDate);
            UpdateCost.SetTableView(Project);
            UpdateCost.SetTableView(Ledger);
            UpdateCost.SetProperties(true);
            UpdateCost.UseRequestPage(false);
            UpdateCost.Run();
        end;
        if Before.FindSet() then
            repeat
                Ledger.Get(Before."Entry No.");
                if (Ledger."Total Cost (LCY)" <> Before."Total Cost (LCY)") or (Ledger."Total Cost" <> Before."Total Cost") then begin
                    Counts.Set(Before."Job No.", Counts.Get(Before."Job No.") + 1);
                    Changes.Set(Before."Job No.", Changes.Get(Before."Job No.") + Ledger."Total Cost (LCY)" - Before."Total Cost (LCY)");
                    Total += 1;
                end;
            until Before.Next() = 0;
        foreach ProjectNo in Projects do begin
            Clear(Entry);
            Entry.Add('projectNo', ProjectNo);
            Entry.Add('entriesUpdated', Counts.Get(ProjectNo));
            Entry.Add('costChangeLCY', Changes.Get(ProjectNo));
            Rows.Add(Entry);
        end;
        Response.Add('status', 'Success');
        Response.Add('projects', Rows);
        Response.Add('totalEntriesUpdated', Total);
        Response.Add('summary', StrSubstNo(SummaryLbl, Total, Projects.Count()));
        Argument.SetResponseJson(Response);
    end;

    local procedure SetScope(var Ledger: Record "Job Ledger Entry"; ProjectNo: Code[20]; FromDate: Date; ToDate: Date)
    begin
        Ledger.Reset();
        if ProjectNo <> '' then
            Ledger.SetRange("Job No.", ProjectNo);
        Ledger.SetRange(Type, Ledger.Type::Item);
        Ledger.SetRange("Entry Type", Ledger."Entry Type"::Usage);
        if (FromDate <> 0D) and (ToDate <> 0D) then
            Ledger.SetRange("Posting Date", FromDate, ToDate)
        else
            if FromDate <> 0D then
                Ledger.SetFilter("Posting Date", '%1..', FromDate)
            else
                if ToDate <> 0D then
                    Ledger.SetFilter("Posting Date", '..%1', ToDate);
    end;
}
