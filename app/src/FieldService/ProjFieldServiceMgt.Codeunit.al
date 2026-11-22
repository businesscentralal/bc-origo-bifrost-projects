namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Validates owner-scoped, read-only technician queries and assembles their results.</summary>
codeunit 70013429 "Proj. Field Service Mgt ori"
{
    Access = Internal;

    var
        RefusedLbl: Label 'The technician request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni tæknimanns.';
        PermissionLbl: Label 'Assign BIFROST Read ori and PROJ FIELD TECH.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori og PROJ FIELD TECH.';
        FormatLbl: Label 'Use the parameter type and ISO date documented in help.', Comment = 'is-IS=Notaðu gagnategund viðfangs og ISO-dagsetningu sem skráð eru í hjálp.';
        MissingLbl: Label 'Send projectNo and taskNo.', Comment = 'is-IS=Sendu projectNo og taskNo.';
        UnknownLbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        NotFoundLbl: Label 'Use an existing project and task.', Comment = 'is-IS=Notaðu fyrirliggjandi verkefni og verkhluta.';
        UnmappedLbl: Label 'Ask an administrator to set your user as Time Sheet Owner User ID on your resource.', Comment = 'is-IS=Biddu stjórnanda að skrá notandann þinn sem Time Sheet Owner User ID á forðann þinn.';
        ChooseLbl: Label 'You own more than one resource; send resourceNo.', Comment = 'is-IS=Þú átt fleiri en einn forða; sendu resourceNo.';
        OwnLbl: Label 'Use a resource whose Time Sheet Owner User ID is your user.', Comment = 'is-IS=Notaðu forða þar sem Time Sheet Owner User ID er notandinn þinn.';
        DaySummaryLbl: Label '%1 planned visits for %2.', Comment = '%1 = visit count, %2 = ISO date; is-IS=%1 áætlaðar heimsóknir fyrir %2.';
        BriefSummaryLbl: Label 'Visit brief for project %1, task %2.', Comment = '%1 = project number, %2 = task number; is-IS=Yfirlit heimsóknar fyrir verkefni %1, verkhluta %2.';

    /// <summary>Checks all native read permissions before querying technician data.</summary>
    procedure CanRead(): Boolean
    var
        Project: Record Job;
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Usage: Record "TS Usage Line ori";
    begin
        exit(Project.ReadPermission() and Task.ReadPermission() and Planning.ReadPermission() and
            Resource.ReadPermission() and Header.ReadPermission() and Line.ReadPermission() and
            Detail.ReadPermission() and Usage.ReadPermission());
    end;

    /// <summary>Runs one read after validating parameters and resolving an owned resource.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Brief: Boolean)
    var
        Resource: Record Resource;
        Project: Record Job;
        Task: Record "Job Task";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        KeyName: Text;
        RequestedDate: Date;
        ProjectNo: Text;
        TaskNo: Text;
        ResourceNo: Text;
    begin
        Argument.AssertVersion1();
        if not CanRead() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not ((KeyName in ['resourceNo', 'detail']) or
                (Brief and (KeyName in ['projectNo', 'taskNo'])) or
                (not Brief and (KeyName in ['date', 'include']))) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName, UnknownLbl);
                exit;
            end;
        if not ReadText(Argument, Request, 'resourceNo', false, 20, ResourceNo) then
            exit;
        if Request.Get('detail', Token) then
            if not IsText(Token, 4) or (Token.AsValue().AsText() <> 'full') then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'detail', FormatLbl);
                exit;
            end;
        RequestedDate := Today();
        if not Brief then begin
            if not ReadDate(Argument, Request, RequestedDate) then
                exit;
            if not ValidateInclude(Argument, Request) then
                exit;
        end else begin
            if not ReadText(Argument, Request, 'projectNo', true, 20, ProjectNo) then
                exit;
            if not ReadText(Argument, Request, 'taskNo', true, 20, TaskNo) then
                exit;
        end;
        if not ResolveResource(Argument, ResourceNo, Resource) then
            exit;
        if Brief then begin
            if not Project.Get(ProjectNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', NotFoundLbl);
                exit;
            end;
            if not Task.Get(ProjectNo, TaskNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', NotFoundLbl);
                exit;
            end;
            Response := BuildBrief(Project, Task, Resource);
        end else
            Response := BuildDay(Request, Resource, RequestedDate);
        Argument.SetResponseJson(Response);
    end;

    local procedure ResolveResource(var Argument: Record "Message Argument ori"; ResourceNo: Text; var Resource: Record Resource): Boolean
    var
        Caller: Code[50];
    begin
        Caller := CopyStr(UpperCase(UserId()), 1, 50);
        if ResourceNo <> '' then begin
            if not Resource.Get(ResourceNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo', OwnLbl);
                exit(false);
            end;
            if (Caller = '') or (Resource."Time Sheet Owner User ID" <> Caller) then begin
                Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, 'resourceNo', OwnLbl);
                exit(false);
            end;
            exit(true);
        end;
        Resource.SetRange("Time Sheet Owner User ID", Caller);
        if (Caller = '') or Resource.IsEmpty() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'resourceNo', UnmappedLbl);
            exit(false);
        end;
        if Resource.Count() > 1 then begin
            Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'resourceNo', ChooseLbl);
            exit(false);
        end;
        Resource.FindFirst();
        exit(true);
    end;

    local procedure BuildDay(Request: JsonObject; Resource: Record Resource; RequestedDate: Date) Response: JsonObject
    var
        Planning: Record "Job Planning Line";
        TempPlanning: Record "Job Planning Line" temporary;
        Technician: JsonObject;
        Steps: JsonArray;
        Visits: JsonArray;
        NextVisit: JsonToken;
    begin
        Technician.Add('resourceNo', Resource."No.");
        Technician.Add('name', Resource.Name);
        Planning.SetRange(Type, Planning.Type::Resource);
        Planning.SetRange("No.", Resource."No.");
        Planning.SetRange("Planning Date", RequestedDate);
        // Sort the temporary set by date/task/line across projects without depending on an installed secondary key.
        Planning.SetLoadFields("Job No.", "Job Task No.", "Line No.", "Planning Date", Type, "No.", Quantity, Description);
        if Planning.FindSet() then
            repeat
                TempPlanning := Planning;
                TempPlanning.Insert();
            until Planning.Next() = 0;
        SortVisits(TempPlanning, Resource, RequestedDate, Request, Visits, Steps);
        if Visits.Count() > 0 then
            Visits.Get(0, NextVisit)
        else
            NextVisit.AsValue().SetValueToNull();
        Response.Add('status', 'Success');
        Response.Add('technician', Technician);
        Response.Add('visits', Visits);
        Response.Add('nextVisit', NextVisit);
        Response.Add('summary', StrSubstNo(DaySummaryLbl, Visits.Count(), Format(RequestedDate, 0, 9)));
        Response.Add('nextSteps', Steps);
    end;

    local procedure SortVisits(var TempPlanning: Record "Job Planning Line" temporary; Resource: Record Resource; RequestedDate: Date; Request: JsonObject; var Visits: JsonArray; var Steps: JsonArray)
    var
        TempSelected: Record "Job Planning Line" temporary;
        Project: Record Job;
        Task: Record "Job Task";
        Visit: JsonObject;
        TimeNode: JsonObject;
        Planned: JsonObject;
        Token: JsonToken;
    begin
        while TempPlanning.FindSet() do begin
            TempSelected := TempPlanning;
            repeat
                if (TempPlanning."Job Task No." < TempSelected."Job Task No.") or
                   ((TempPlanning."Job Task No." = TempSelected."Job Task No.") and (TempPlanning."Line No." < TempSelected."Line No.")) or
                   ((TempPlanning."Job Task No." = TempSelected."Job Task No.") and (TempPlanning."Line No." = TempSelected."Line No.") and (TempPlanning."Job No." < TempSelected."Job No.")) then
                    TempSelected := TempPlanning;
            until TempPlanning.Next() = 0;
            if Project.Get(TempSelected."Job No.") and Task.Get(TempSelected."Job No.", TempSelected."Job Task No.") then begin
                Clear(Visit);
                Visit.Add('projectNo', Project."No.");
                Visit.Add('taskNo', Task."Job Task No.");
                Visit.Add('description', Task.Description);
                Visit.Add('customerName', Project."Sell-to Customer Name");
                Visit.Add('phone', Project."Ship-to Phone No.");
                Visit.Add('planningDate', Format(RequestedDate, 0, 9));
                Visit.Add('lineNo', TempSelected."Line No.");
                Visit.Add('plannedHours', TempSelected.Quantity);
                TimeNode := BuildTime(Resource, Project."No.", Task."Job Task No.", RequestedDate, Steps);
                Visit.Add('loggedHours', TimeNode.GetDecimal('loggedHours'));
                TimeNode.Get('timeSheetNo', Token);
                Visit.Add('timeSheetNo', Token);
                TimeNode.Get('timeSheetLineNo', Token);
                Visit.Add('timeSheetLineNo', Token);
                Visit.Add('openUsage', OpenUsage(Resource, Project."No.", Task."Job Task No.", RequestedDate));
                if Includes(Request, 'address', true) then
                    Visit.Add('address', Site(Project));
                if Includes(Request, 'items', false) then begin
                    Planned := BuildPlanned(Project."No.", Task."Job Task No.");
                    Visit.Add('items', Planned.GetArray('items'));
                end;
                Visits.Add(Visit);
            end;
            TempPlanning := TempSelected;
            TempPlanning.Delete();
        end;
    end;

    local procedure BuildBrief(Project: Record Job; Task: Record "Job Task"; Resource: Record Resource) Response: JsonObject
    var
        FollowUp: Codeunit "Proj. Follow-up Mgt ori";
        ProjectNode: JsonObject;
        TaskNode: JsonObject;
        Ids: JsonObject;
        Steps: JsonArray;
        TimeNode: JsonObject;
        Empty: JsonArray;
    begin
        ProjectNode.Add('projectNo', Project."No.");
        ProjectNode.Add('description', Project.Description);
        TaskNode.Add('taskNo', Task."Job Task No.");
        TaskNode.Add('description', Task.Description);
        Ids.Add('project', Format(Project.SystemId, 0, 4));
        Ids.Add('task', Format(Task.SystemId, 0, 4));
        TimeNode := BuildTime(Resource, Project."No.", Task."Job Task No.", 0D, Steps);
        Response.Add('status', 'Success');
        Response.Add('project', ProjectNode);
        Response.Add('task', TaskNode);
        Response.Add('site', Site(Project));
        Response.Add('planned', BuildPlanned(Project."No.", Task."Job Task No."));
        Response.Add('myTime', TimeNode);
        Response.Add('myUsage', MyUsage(Resource, Project."No.", Task."Job Task No."));
        Response.Add('history', Empty);
        Response.Add('followUps', FollowUp.Brief(Project."No.", Task."Job Task No."));
        Response.Add('recordIds', Ids);
        Response.Add('summary', StrSubstNo(BriefSummaryLbl, Project."No.", Task."Job Task No."));
        Response.Add('nextSteps', Steps);
    end;

    local procedure Site(Project: Record Job) Node: JsonObject
    begin
        Node.Add('name', Project."Ship-to Name");
        Node.Add('address', Project."Ship-to Address");
        Node.Add('address2', Project."Ship-to Address 2");
        Node.Add('city', Project."Ship-to City");
        Node.Add('postCode', Project."Ship-to Post Code");
        Node.Add('country', Project."Ship-to Country/Region Code");
        Node.Add('phone', Project."Ship-to Phone No.");
    end;

    local procedure BuildPlanned(ProjectNo: Code[20]; TaskNo: Code[20]) Node: JsonObject
    var
        Planning: Record "Job Planning Line";
        Resources: JsonArray;
        Items: JsonArray;
        Entry: JsonObject;
    begin
        Planning.SetRange("Job No.", ProjectNo);
        Planning.SetRange("Job Task No.", TaskNo);
        Planning.SetLoadFields("Job No.", "Job Task No.", "Line No.", Type, "No.", Description, "Remaining Qty.", "Unit of Measure Code");
        if Planning.FindSet() then
            repeat
                if (Planning.Type in [Planning.Type::Resource, Planning.Type::Item]) and (Planning."Remaining Qty." > 0) then begin
                    Clear(Entry);
                    Entry.Add('no', Planning."No.");
                    Entry.Add('description', Planning.Description);
                    Entry.Add('remainingQuantity', Planning."Remaining Qty.");
                    Entry.Add('unitOfMeasure', Planning."Unit of Measure Code");
                    Entry.Add('lineNo', Planning."Line No.");
                    if Planning.Type = Planning.Type::Resource then
                        Resources.Add(Entry)
                    else
                        Items.Add(Entry);
                end;
            until Planning.Next() = 0;
        Node.Add('resources', Resources);
        Node.Add('items', Items);
    end;

    local procedure BuildTime(Resource: Record Resource; ProjectNo: Code[20]; TaskNo: Code[20]; RequestedDate: Date; var Steps: JsonArray) Node: JsonObject
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        ResourcesSetup: Record "Resources Setup";
        SheetNo: Code[20];
        LineNo: Integer;
        Hours: Decimal;
        HasLine: Boolean;
        HasSheet: Boolean;
        CurrentSheet: Boolean;
        FirstWeekday: Integer;
        Step: JsonObject;
        Params: JsonObject;
        NullValue: JsonValue;
        StepDate: Date;
    begin
        SheetNo := '';
        Header.SetRange("Resource No.", Resource."No.");
        Header.SetRange("Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        if RequestedDate <> 0D then begin
            Header.SetFilter("Starting Date", '..%1', RequestedDate);
            Header.SetFilter("Ending Date", '%1..', RequestedDate);
        end;
        if Header.FindSet() then
            repeat
                CurrentSheet := (RequestedDate <> 0D) or
                    ((Header."Starting Date" <= Today()) and (Header."Ending Date" >= Today()));
                if CurrentSheet then begin
                    HasSheet := true;
                    if SheetNo = '' then
                        SheetNo := Header."No.";
                end;
                Line.SetRange("Time Sheet No.", Header."No.");
                Line.SetRange(Type, Line.Type::Job);
                Line.SetRange("Job No.", ProjectNo);
                Line.SetRange("Job Task No.", TaskNo);
                if Line.FindSet() then
                    repeat
                        if CurrentSheet then begin
                            if not HasLine then begin
                                SheetNo := Header."No.";
                                LineNo := Line."Line No.";
                            end;
                            HasLine := true;
                        end;
                        Detail.SetRange("Time Sheet No.", Header."No.");
                        Detail.SetRange("Time Sheet Line No.", Line."Line No.");
                        if RequestedDate <> 0D then
                            Detail.SetRange(Date, RequestedDate);
                        Detail.CalcSums(Quantity);
                        Hours += Detail.Quantity;
                    until Line.Next() = 0;
            until Header.Next() = 0;
        NullValue.SetValueToNull();
        Node.Add('loggedHours', Hours);
        if HasSheet then
            Node.Add('timeSheetNo', SheetNo)
        else
            Node.Add('timeSheetNo', NullValue);
        if HasLine then
            Node.Add('timeSheetLineNo', LineNo)
        else begin
            Node.Add('timeSheetLineNo', NullValue);
            if HasSheet then begin
                Step.Add('type', 'Projects.MyTimeSheetLine.Set');
                Params.Add('timeSheetNo', SheetNo);
                Params.Add('type', 'Job');
                Params.Add('projectNo', ProjectNo);
                Params.Add('taskNo', TaskNo);
            end else begin
                Step.Add('type', 'Projects.MyTimeSheet.Create');
                StepDate := RequestedDate;
                if StepDate = 0D then
                    StepDate := Today();
                FirstWeekday := 1;
                if ResourcesSetup.Get() then
                    FirstWeekday := ResourcesSetup."Time Sheet First Weekday" + 1;
                StepDate -= (Date2DWY(StepDate, 1) - FirstWeekday + 7) mod 7;
                Params.Add('startingDate', Format(StepDate, 0, 9));
                Params.Add('resourceNo', Resource."No.");
            end;
            Step.Add('parameters', Params);
            Steps.Add(Step);
        end;
    end;

    local procedure OpenUsage(Resource: Record Resource; ProjectNo: Code[20]; TaskNo: Code[20]; RequestedDate: Date): Integer
    var
        Lines: JsonArray;
        Entry: JsonToken;
        Count: Integer;
    begin
        Lines := MyUsage(Resource, ProjectNo, TaskNo);
        foreach Entry in Lines do
            if (Entry.AsObject().GetText('date') = Format(RequestedDate, 0, 9)) and
               (Entry.AsObject().GetText('status') = 'Open') and not Entry.AsObject().GetBoolean('reversed') then
                Count += 1;
        exit(Count);
    end;

    local procedure MyUsage(Resource: Record Resource; ProjectNo: Code[20]; TaskNo: Code[20]) Entries: JsonArray
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        UsageMgt: Codeunit "TS Usage Mgt ori";
    begin
        Header.SetRange("Resource No.", Resource."No.");
        Header.SetRange("Owner User ID", CopyStr(UpperCase(UserId()), 1, 50));
        if Header.FindSet() then
            repeat
                Line.SetRange("Time Sheet No.", Header."No.");
                Line.SetRange("Job No.", ProjectNo);
                Line.SetRange("Job Task No.", TaskNo);
                if Line.FindSet() then
                    repeat
                        Usage.SetRange("Time Sheet No.", Header."No.");
                        Usage.SetRange("Time Sheet Line No.", Line."Line No.");
                        Usage.SetRange("Resource No.", Resource."No.");
                        if Usage.FindSet() then
                            repeat
                                Entries.Add(UsageMgt.LineNode(Usage, false));
                            until Usage.Next() = 0;
                    until Line.Next() = 0;
            until Header.Next() = 0;
    end;

    local procedure IsText(Token: JsonToken; MaxLength: Integer): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        exit((Token.AsValue().AsText() <> '') and (StrLen(Token.AsValue().AsText()) <= MaxLength) and
            (Format(Token).StartsWith('"')));
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Required: Boolean; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Request.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName, MissingLbl);
            exit(false);
        end;
        if not IsText(Token, MaxLength) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, FormatLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadDate(var Argument: Record "Message Argument ori"; Request: JsonObject; var RequestedDate: Date): Boolean
    var
        Token: JsonToken;
    begin
        if not Request.Get('date', Token) then
            exit(true);
        if IsText(Token, 10) then
            if Evaluate(RequestedDate, Token.AsValue().AsText(), 9) then
                if (RequestedDate <> 0D) and (Format(RequestedDate, 0, 9) = Token.AsValue().AsText()) then
                    exit(true);
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'date', FormatLbl);
        exit(false);
    end;

    local procedure ValidateInclude(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Token: JsonToken;
        Entry: JsonToken;
    begin
        if not Request.Get('include', Token) then
            exit(true);
        if Token.IsArray() then begin
            foreach Entry in Token.AsArray() do
                if not IsText(Entry, 7) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'include', FormatLbl);
                    exit(false);
                end else
                    if not (Entry.AsValue().AsText() in ['items', 'address']) then begin
                        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'include', FormatLbl);
                        exit(false);
                    end;
            exit(true);
        end;
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'include', FormatLbl);
        exit(false);
    end;

    local procedure Includes(Request: JsonObject; Name: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
        Entry: JsonToken;
    begin
        if not Request.Get('include', Token) then begin
            if Request.Contains('detail') then
                exit(true);
            exit(DefaultValue);
        end;
        foreach Entry in Token.AsArray() do
            if Entry.AsValue().AsText() = Name then
                exit(true);
        exit(false);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, RefusedLbl, Parameter, '', '', NextStep);
    end;
}
