namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;

/// <summary>Reads resource capacity and project allocations in bounded calendar periods.</summary>
codeunit 70009231 "Projects Allocation ori"
{
    Access = Internal;

    var
        Text1Lbl: Label 'Optional exact project number; capacity remains the resource capacity.', Comment = 'is-IS=Valfrjálst nákvæmt verkefnisnúmer; afkastageta helst afkastageta forðans.';
        Text2Lbl: Label 'Optional exact resource number.', Comment = 'is-IS=Valfrjálst nákvæmt forðanúmer.';
        Text3Lbl: Label 'Optional exact resource group number; combines with resourceNo.', Comment = 'is-IS=Valfrjálst nákvæmt forðaflokksnúmer; er notað ásamt resourceNo.';
        Text4Lbl: Label 'Calendar period: day, week, month, quarter or year.', Comment = 'is-IS=Almanakstímabil: day, week, month, quarter eða year.';
        Text5Lbl: Label 'Inclusive first date in ISO YYYY-MM-DD format.', Comment = 'is-IS=Fyrsti dagur, meðtalinn, á ISO-sniðinu YYYY-MM-DD.';
        Text6Lbl: Label 'Inclusive last date in ISO YYYY-MM-DD format.', Comment = 'is-IS=Síðasti dagur, meðtalinn, á ISO-sniðinu YYYY-MM-DD.';
        Text7Lbl: Label 'Ask an administrator for BIFROST Read ori and the Projects read permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Read ori og lesheimildir fyrir verkefni.';
        Text8Lbl: Label 'Use day, week, month, quarter or year.', Comment = 'is-IS=Notaðu day, week, month, quarter eða year.';
        Text9Lbl: Label 'Use a date range ending on or after fromDate.', Comment = 'is-IS=Notaðu dagsetningabil sem endar á eða eftir fromDate.';
        Text10Lbl: Label 'Narrow the date range.', Comment = 'is-IS=Þrengdu dagsetningabilið.';
        Text11Lbl: Label 'Pass an existing project number.', Comment = 'is-IS=Sendu verkefnisnúmer sem er til.';
        Text12Lbl: Label 'Pass an existing resource number.', Comment = 'is-IS=Sendu forðanúmer sem er til.';
        Text13Lbl: Label 'Pass an existing resource group number.', Comment = 'is-IS=Sendu forðaflokksnúmer sem er til.';
        Text14Lbl: Label 'Use a resource belonging to the selected resource group.', Comment = 'is-IS=Notaðu forða sem tilheyrir völdum forðaflokki.';

    /// <summary>Declares exact identifiers and an inclusive ISO date range.</summary>
    procedure Parameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Result.Add(Input.Parameter('projectNo', 'string', false, Text1Lbl, 20));
        Result.Add(Input.Parameter('resourceNo', 'string', false, Text2Lbl, 20));
        Result.Add(Input.Parameter('resourceGroupNo', 'string', false, Text3Lbl, 20));
        Result.Add(Input.Parameter('periodType', 'string', true, Text4Lbl, 0));
        Result.Add(Input.Parameter('fromDate', 'date', true, Text5Lbl, 0));
        Result.Add(Input.Parameter('toDate', 'date', true, Text6Lbl, 0));
    end;

    /// <summary>Checks every native table without elevating the caller.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Resource, false) and Gate.IsEnabled(Database::"Resource Group", false) and
             Gate.IsEnabled(Database::"Res. Capacity Entry", false) and Gate.IsEnabled(Database::"Job Planning Line", false) and Gate.IsEnabled(Database::Job, false));
    end;

    /// <summary>Returns per-resource/per-period capacity, project allocation and availability.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Resource: Record Resource;
        ResourceGroup: Record "Resource Group";
        Project: Record Job;
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        Response: JsonObject;
        Rows: JsonArray;
        FirstDate: Date;
        LastDate: Date;
        PeriodDate: Date;
        EndDate: Date;
        PeriodType: Text;
        PeriodCount: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not Input.Validate(Argument, Request, Parameters()) then
            exit;
        if not IsEnabled() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', Text7Lbl);
            exit;
        end;
        PeriodType := Request.GetText('periodType');
        if not (PeriodType in ['day', 'week', 'month', 'quarter', 'year']) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'periodType', Text8Lbl);
            exit;
        end;
        Evaluate(FirstDate, Request.GetText('fromDate'), 9);
        Evaluate(LastDate, Request.GetText('toDate'), 9);
        if (FirstDate = 0D) or (LastDate < FirstDate) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'toDate', Text9Lbl);
            exit;
        end;
        PeriodDate := FirstDate;
        repeat
            PeriodCount += 1;
            if PeriodCount > 53 then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::LimitExceeded, 'toDate', Text10Lbl);
                exit;
            end;
            EndDate := PeriodEnd(PeriodDate, PeriodType);
            if EndDate >= LastDate then
                break;
            PeriodDate := EndDate + 1;
        until false;
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        ResourceGroup.ReadIsolation := IsolationLevel::ReadCommitted;
        Project.ReadIsolation := IsolationLevel::ReadCommitted;
        if Input.TextValue(Request, 'projectNo') <> '' then
            if not Project.Get(Request.GetText('projectNo')) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', Text11Lbl);
                exit;
            end;
        if Input.TextValue(Request, 'resourceNo') <> '' then begin
            if not Resource.Get(Request.GetText('resourceNo')) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo', Text12Lbl);
                exit;
            end;
            Resource.SetRange("No.", Resource."No.");
        end;
        if Input.TextValue(Request, 'resourceGroupNo') <> '' then begin
            if not ResourceGroup.Get(Request.GetText('resourceGroupNo')) then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceGroupNo', Text13Lbl);
                exit;
            end;
            if (Input.TextValue(Request, 'resourceNo') <> '') and (Resource."Resource Group No." <> ResourceGroup."No.") then begin
                Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'resourceGroupNo', Text14Lbl);
                exit;
            end;
            Resource.SetRange("Resource Group No.", ResourceGroup."No.");
        end;
        Resource.SetLoadFields("No.", "Resource Group No.");
        if Resource.FindSet() then
            repeat
                PeriodDate := FirstDate;
                repeat
                    EndDate := PeriodEnd(PeriodDate, PeriodType);
                    if EndDate > LastDate then
                        EndDate := LastDate;
                    Rows.Add(Allocation(Resource."No.", Input.TextValue(Request, 'projectNo'), PeriodDate, EndDate));
                    if EndDate = LastDate then
                        break;
                    PeriodDate := EndDate + 1;
                until false;
            until Resource.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('periodType', PeriodType);
        Response.Add('rows', Rows);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Returns the inclusive end of the calendar period containing the date.</summary>
    procedure PeriodEnd(FirstDate: Date; PeriodType: Text): Date
    begin
        case PeriodType of
            'day': exit(FirstDate);
            'week': exit(CalcDate('<CW>', FirstDate));
            'month': exit(CalcDate('<CM>', FirstDate));
            'quarter': exit(CalcDate('<CQ>', FirstDate));
            'year': exit(CalcDate('<CY>', FirstDate));
        end;
    end;

    local procedure Allocation(ResourceNo: Code[20]; ProjectNo: Text; FirstDate: Date; LastDate: Date) Result: JsonObject
    var
        Capacity: Record "Res. Capacity Entry";
        Planning: Record "Job Planning Line";
        ProjectTotals: Dictionary of [Code[20], Decimal];
        Projects: JsonArray;
        ProjectRow: JsonObject;
        ProjectKey: Code[20];
        Allocated: Decimal;
        PerProject: Decimal;
    begin
        Capacity.ReadIsolation := IsolationLevel::ReadCommitted;
        Capacity.SetRange("Resource No.", ResourceNo);
        Capacity.SetRange(Date, FirstDate, LastDate);
        Capacity.CalcSums(Capacity);
        Planning.ReadIsolation := IsolationLevel::ReadCommitted;
        Planning.SetRange(Type, Planning.Type::Resource);
        Planning.SetRange("No.", ResourceNo);
        Planning.SetRange("Planning Date", FirstDate, LastDate);
        Planning.SetRange("Schedule Line", true);
        Planning.SetRange(Status, Planning.Status::Order);
        if ProjectNo <> '' then
            Planning.SetRange("Job No.", ProjectNo);
        Planning.SetLoadFields("Job No.", "Quantity (Base)");
        if Planning.FindSet() then
            repeat
                Allocated += Planning."Quantity (Base)";
                PerProject := 0;
                if not ProjectTotals.Get(Planning."Job No.", PerProject) then
                    PerProject := 0;
                ProjectTotals.Set(Planning."Job No.", PerProject + Planning."Quantity (Base)");
            until Planning.Next() = 0;
        foreach ProjectKey in ProjectTotals.Keys() do begin
            Clear(ProjectRow);
            ProjectRow.Add('projectNo', ProjectKey);
            ProjectRow.Add('allocated', ProjectTotals.Get(ProjectKey));
            Projects.Add(ProjectRow);
        end;
        Result.Add('resourceNo', ResourceNo);
        Result.Add('fromDate', Format(FirstDate, 0, 9));
        Result.Add('toDate', Format(LastDate, 0, 9));
        Result.Add('capacity', Capacity.Capacity);
        Result.Add('allocated', Allocated);
        Result.Add('availability', Capacity.Capacity - Allocated);
        Result.Add('projects', Projects);
    end;
}
