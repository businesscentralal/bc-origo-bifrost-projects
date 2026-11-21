namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>Validates Projects.Visit.Start, Stop and Complete. A refusal writes nothing.</summary>
codeunit 70013439 "Proj. Visit Mgt ori"
{
    Access = Internal;

    /// <summary>True when the caller can read the visit context and write a visit, a time sheet line and a usage line.</summary>
    procedure CanRun(): Boolean
    var
        Visit: Record "Proj. Field Visit ori";
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Usage: Record "TS Usage Line ori";
        Job: Record Job;
        JobTask: Record "Job Task";
        Planning: Record "Job Planning Line";
        WorkType: Record "Work Type";
        Resource: Record Resource;
        Setup: Record "Projects Setup ori";
    begin
        exit(Visit.ReadPermission() and Visit.WritePermission() and Header.ReadPermission() and Line.ReadPermission() and Line.WritePermission() and Detail.ReadPermission() and Detail.WritePermission() and Usage.ReadPermission() and Usage.WritePermission() and Job.ReadPermission() and JobTask.ReadPermission() and Planning.ReadPermission() and WorkType.ReadPermission() and Resource.ReadPermission() and Setup.ReadPermission());
    end;

    /// <summary>Starts a travel or work visit for the caller's resource.</summary>
    procedure ExecuteStart(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        ResourceNo: Code[20];
        RequestId: Text;
    begin
        if not Open(Argument, Request, ResourceNo, RequestId, 1) then
            exit;
        WriteStart(Argument, Request, ResourceNo, RequestId);
    end;

    /// <summary>Stops the caller's running visit and adds the rounded hours.</summary>
    procedure ExecuteStop(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        ResourceNo: Code[20];
        RequestId: Text;
    begin
        if not Open(Argument, Request, ResourceNo, RequestId, 2) then
            exit;
        WriteStop(Argument, Request, ResourceNo, RequestId);
    end;

    /// <summary>Completes a visit and, when asked, writes an open mileage usage line.</summary>
    procedure ExecuteComplete(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        ResourceNo: Code[20];
        RequestId: Text;
    begin
        if not Open(Argument, Request, ResourceNo, RequestId, 3) then
            exit;
        WriteComplete(Argument, Request, ResourceNo, RequestId);
    end;

    /// <summary>Rounds elapsed time with the company rounding minutes. Negative means the stop is before the start.</summary>
    procedure RoundedHours(StartedAt: DateTime; StoppedAt: DateTime): Decimal
    var
        Minutes: Decimal;
        Rounding: Integer;
    begin
        if StoppedAt < StartedAt then
            exit(-1);
        Minutes := (StoppedAt - StartedAt) / 60000;
        Rounding := RoundingMinutes();
        exit(Round(Round(Minutes, Rounding, '=') / 60, 0.00001, '='));
    end;

    local procedure WriteStart(var Argument: Record "Message Argument ori"; Request: JsonObject; ResourceNo: Code[20]; RequestId: Text)
    var
        Running: Record "Proj. Field Visit ori";
        Payload: JsonObject;
        ProjectNo: Code[20];
        TaskNo: Code[20];
        SheetNo: Code[20];
        StoppedSheetNo: Code[20];
        Kind: Code[20];
        StartedAt: DateTime;
        Hours: Decimal;
        AutoStop: Boolean;
    begin
        if not ReadRequiredText(Request, 'projectNo', Argument, MaxStrLen(ProjectNo), ProjectNo) then
            exit;
        if not ReadRequiredText(Request, 'taskNo', Argument, MaxStrLen(TaskNo), TaskNo) then
            exit;
        if not ReadRequiredText(Request, 'kind', Argument, 10, Kind) then
            exit;
        if not (Kind in ['travel', 'work']) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'kind', FormatNext());
            exit;
        end;
        if not CheckJobTask(Argument, ProjectNo, TaskNo) then
            exit;
        if not ReadAt(Request, Argument, StartedAt) then
            exit;
        if not WithinTolerance(Argument, StartedAt) then
            exit;
        if not ReadAutoStop(Request, Argument, AutoStop) then
            exit;
        if Kind = 'travel' then
            if not TravelReady(Argument) then
                exit;
        if not FindSheet(Argument, ResourceNo, DT2Date(StartedAt), SheetNo) then
            exit;
        if not AcceptStartLine(Argument, ResourceNo, SheetNo, ProjectNo, TaskNo, WorkTypeOf(Kind)) then
            exit;
        if FindRunning(ResourceNo, Running) then begin
            if not AutoStop then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'autoStop', RunningNext());
                exit;
            end;
            if StartedAt < Running."Started At" then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'at', BeforeStartNext());
                exit;
            end;
            if Running.Kind = Running.Kind::Travel then
                if not TravelReady(Argument) then
                    exit;
            if not FindSheet(Argument, ResourceNo, Running.Date, StoppedSheetNo) then
                exit;
            if not AcceptWriteLine(Argument, StoppedSheetNo, Running."Project No.", Running."Task No.", WorkTypeOf(Running)) then
                exit;
            Hours := RoundedHours(Running."Started At", StartedAt);
            if not WithinDay(Argument, StoppedSheetNo, Running.Date, Hours) then
                exit;
            Payload.Add('autoStopVisitId', Running."Entry No.");
            Payload.Add('stoppedHours', Hours);
            Payload.Add('stoppedSheetNo', StoppedSheetNo);
        end;
        Payload.Add('resourceNo', ResourceNo);
        Payload.Add('projectNo', ProjectNo);
        Payload.Add('taskNo', TaskNo);
        Payload.Add('kind', LowerCase(Kind));
        Payload.Add('sheetNo', SheetNo);
        Payload.Add('at', Format(StartedAt, 0, 9));
        Payload.Add('clientRequestId', RequestId);
        Payload.Add('travelWorkType', Format(TravelWorkType()));
        RunWriter(Argument, 1, Payload);
    end;

    local procedure WriteStop(var Argument: Record "Message Argument ori"; Request: JsonObject; ResourceNo: Code[20]; RequestId: Text)
    var
        Visit: Record "Proj. Field Visit ori";
        Payload: JsonObject;
        SheetNo: Code[20];
        Note: Text;
        StoppedAt: DateTime;
        Hours: Decimal;
        VisitId: Integer;
        HasVisitId: Boolean;
    begin
        if not ReadVisitId(Request, Argument, VisitId, HasVisitId) then
            exit;
        if not ReadOptionalText(Request, 'note', Argument, 250, Note) then
            exit;
        if not ReadAt(Request, Argument, StoppedAt) then
            exit;
        if not WithinTolerance(Argument, StoppedAt) then
            exit;
        if not LoadRunning(Argument, ResourceNo, VisitId, HasVisitId, Visit) then
            exit;
        if StoppedAt < Visit."Started At" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'at', BeforeStartNext());
            exit;
        end;
        if Visit.Kind = Visit.Kind::Travel then
            if not TravelReady(Argument) then
                exit;
        if not FindSheet(Argument, ResourceNo, Visit.Date, SheetNo) then
            exit;
        if not AcceptWriteLine(Argument, SheetNo, Visit."Project No.", Visit."Task No.", WorkTypeOf(Visit)) then
            exit;
        Hours := RoundedHours(Visit."Started At", StoppedAt);
        if not WithinDay(Argument, SheetNo, Visit.Date, Hours) then
            exit;
        Payload.Add('visitId', Visit."Entry No.");
        Payload.Add('hours', Hours);
        Payload.Add('sheetNo', SheetNo);
        Payload.Add('at', Format(StoppedAt, 0, 9));
        Payload.Add('note', Note);
        Payload.Add('clientRequestId', RequestId);
        Payload.Add('travelWorkType', Format(TravelWorkType()));
        Payload.Add('mayCreateLine', true);
        RunWriter(Argument, 2, Payload);
    end;

    local procedure WriteComplete(var Argument: Record "Message Argument ori"; Request: JsonObject; ResourceNo: Code[20]; RequestId: Text)
    var
        Visit: Record "Proj. Field Visit ori";
        MileageResource: Record Resource;
        Payload: JsonObject;
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Outcome: Text;
        SheetNo: Code[20];
        MileageText: Text;
        StoppedAt: DateTime;
        Hours: Decimal;
        Mileage: Decimal;
        VisitId: Integer;
        HasVisitId: Boolean;
        HasProject: Boolean;
        HasMileage: Boolean;
    begin
        if not ReadVisitId(Request, Argument, VisitId, HasVisitId) then
            exit;
        HasProject := Request.Contains('projectNo') or Request.Contains('taskNo');
        if HasProject then begin
            if not ReadRequiredText(Request, 'projectNo', Argument, MaxStrLen(ProjectNo), ProjectNo) then
                exit;
            if not ReadRequiredText(Request, 'taskNo', Argument, MaxStrLen(TaskNo), TaskNo) then
                exit;
            if not CheckJobTask(Argument, ProjectNo, TaskNo) then
                exit;
        end else
            if not HasVisitId then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'visitId', MissingNext());
                exit;
            end;
        if not ReadOptionalText(Request, 'outcome', Argument, 250, Outcome) then
            exit;
        if not ReadMileage(Request, Argument, HasMileage, MileageText, Mileage) then
            exit;
        if not SelectVisit(Argument, ResourceNo, VisitId, HasVisitId, ProjectNo, TaskNo, HasProject, Visit) then
            exit;
        if Visit.Status = Visit.Status::Completed then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'visitId', AlreadyDoneNext());
            exit;
        end;
        StoppedAt := CurrentDateTime();
        SheetNo := '';
        Hours := 0;
        if Visit.Status = Visit.Status::Running then begin
            if Visit.Kind = Visit.Kind::Travel then
                if not TravelReady(Argument) then
                    exit;
            if StoppedAt < Visit."Started At" then
                StoppedAt := Visit."Started At";
            if not FindSheet(Argument, ResourceNo, Visit.Date, SheetNo) then
                exit;
            if not AcceptWriteLine(Argument, SheetNo, Visit."Project No.", Visit."Task No.", WorkTypeOf(Visit)) then
                exit;
            Hours := RoundedHours(Visit."Started At", StoppedAt);
            if not WithinDay(Argument, SheetNo, Visit.Date, Hours) then
                exit;
        end else
            if not FindSheet(Argument, ResourceNo, Visit.Date, SheetNo) then
                exit;
        if HasMileage then begin
            if not MileageReady(Argument, MileageResource) then
                exit;
            if not AcceptWriteLine(Argument, SheetNo, Visit."Project No.", Visit."Task No.", '') then
                exit;
            Payload.Add('mileageKm', MileageText);
            Payload.Add('mileageResource', MileageResource."No.");
            Payload.Add('mileageUnit', MileageResource."Base Unit of Measure");
        end;
        Payload.Add('visitId', Visit."Entry No.");
        Payload.Add('outcome', Outcome);
        Payload.Add('hours', Hours);
        Payload.Add('sheetNo', SheetNo);
        Payload.Add('at', Format(StoppedAt, 0, 9));
        Payload.Add('clientRequestId', RequestId);
        Payload.Add('travelWorkType', Format(TravelWorkType()));
        Payload.Add('mayCreateLine', true);
        Payload.Add('running', Visit.Status = Visit.Status::Running);
        RunWriter(Argument, 3, Payload);
    end;

    local procedure Open(var Argument: Record "Message Argument ori"; var Request: JsonObject; var ResourceNo: Code[20]; var RequestId: Text; Operation: Integer): Boolean
    begin
        Argument.AssertVersion1();
        if not CanRun() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionNext());
            exit(false);
        end;
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', IsolatedNext());
            exit(false);
        end;
        Request := Argument.GetRequestJson();
        if not ResolveResource(Argument, ResourceNo) then
            exit(false);
        if not ReadRequestId(Request, Argument, RequestId) then
            exit(false);
        if Replay(Argument, ResourceNo, RequestId) then
            exit(false);
        exit(AllowOnly(Argument, Request, Operation));
    end;

    local procedure AcceptStartLine(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; SheetNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20]; WorkType: Code[10]): Boolean
    begin
        if not (Planned(ResourceNo, ProjectNo, TaskNo) or UnplannedAllowed()) then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', UnplannedNext());
            exit(false);
        end;
        exit(AcceptWriteLine(Argument, SheetNo, ProjectNo, TaskNo, WorkType));
    end;

    local procedure AcceptWriteLine(var Argument: Record "Message Argument ori"; SheetNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20]; WorkType: Code[10]): Boolean
    var
        Line: Record "Time Sheet Line";
    begin
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Job);
        Line.SetRange("Job No.", ProjectNo);
        Line.SetRange("Job Task No.", TaskNo);
        Line.SetRange("Work Type Code", WorkType);
        Line.SetFilter(Status, '%1|%2', Line.Status::Open, Line.Status::Rejected);
        if not Line.IsEmpty() then
            exit(true);
        Line.SetRange(Status);
        if not Line.IsEmpty() then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', LockedLineNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure WithinDay(var Argument: Record "Message Argument ori"; SheetNo: Code[20]; Day: Date; Hours: Decimal): Boolean
    begin
        if Hours < 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'at', BeforeStartNext());
            exit(false);
        end;
        if (Hours > 0) and (DayQuantity(SheetNo, Day) + Hours > 24) then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'at', TooManyHoursNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure DayQuantity(SheetNo: Code[20]; Day: Date): Decimal
    var
        Detail: Record "Time Sheet Detail";
    begin
        Detail.SetRange("Time Sheet No.", SheetNo);
        Detail.SetRange(Date, Day);
        Detail.CalcSums(Quantity);
        exit(Detail.Quantity);
    end;

    local procedure Planned(ResourceNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20]): Boolean
    var
        Planning: Record "Job Planning Line";
    begin
        Planning.SetRange("Job No.", ProjectNo);
        Planning.SetRange("Job Task No.", TaskNo);
        Planning.SetRange(Type, Planning.Type::Resource);
        Planning.SetRange("No.", ResourceNo);
        exit(not Planning.IsEmpty());
    end;

    local procedure UnplannedAllowed(): Boolean
    var
        Setup: Record "Projects Setup ori";
    begin
        if not Setup.Get() then
            exit(false);
        exit(Setup."Allow Unplanned Tasks");
    end;

    local procedure FindSheet(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; Day: Date; var SheetNo: Code[20]): Boolean
    var
        Header: Record "Time Sheet Header";
    begin
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetRange("Owner User ID", CallerId());
        Header.SetFilter("Starting Date", '..%1', Day);
        Header.SetFilter("Ending Date", '%1..', Day);
        if not Header.FindFirst() then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', NoSheetNext());
            exit(false);
        end;
        SheetNo := Header."No.";
        exit(true);
    end;

    local procedure FindRunning(ResourceNo: Code[20]; var Visit: Record "Proj. Field Visit ori"): Boolean
    begin
        Visit.SetRange("Resource No.", ResourceNo);
        Visit.SetRange(Status, Visit.Status::Running);
        exit(Visit.FindFirst());
    end;

    local procedure LoadRunning(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; VisitId: Integer; HasVisitId: Boolean; var Visit: Record "Proj. Field Visit ori"): Boolean
    begin
        if HasVisitId then begin
            if not OwnVisit(Argument, ResourceNo, VisitId, Visit) then
                exit(false);
        end else
            if not FindRunning(ResourceNo, Visit) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'visitId', NotFoundNext());
                exit(false);
            end;
        if Visit.Status <> Visit.Status::Running then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'visitId', NotRunningNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure SelectVisit(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; VisitId: Integer; HasVisitId: Boolean; ProjectNo: Code[20]; TaskNo: Code[20]; HasProject: Boolean; var Visit: Record "Proj. Field Visit ori"): Boolean
    begin
        if HasVisitId then begin
            if not OwnVisit(Argument, ResourceNo, VisitId, Visit) then
                exit(false);
            if HasProject then
                if (Visit."Project No." <> ProjectNo) or (Visit."Task No." <> TaskNo) then begin
                    Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'visitId', ConflictNext());
                    exit(false);
                end;
            exit(true);
        end;
        Visit.SetCurrentKey("Entry No.");
        Visit.SetRange("Resource No.", ResourceNo);
        Visit.SetRange("Project No.", ProjectNo);
        Visit.SetRange("Task No.", TaskNo);
        Visit.SetRange(Status, Visit.Status::Running);
        if Visit.FindFirst() then
            exit(true);
        Visit.SetRange(Status, Visit.Status::Stopped);
        if Visit.FindLast() then
            exit(true);
        Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', NotFoundNext());
        exit(false);
    end;

    local procedure OwnVisit(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; VisitId: Integer; var Visit: Record "Proj. Field Visit ori"): Boolean
    var
        Any: Record "Proj. Field Visit ori";
    begin
        if not Any.Get(VisitId) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'visitId', NotFoundNext());
            exit(false);
        end;
        if Any."Resource No." <> ResourceNo then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'visitId', OtherVisitNext());
            exit(false);
        end;
        Visit := Any;
        exit(true);
    end;

    local procedure CheckJobTask(var Argument: Record "Message Argument ori"; ProjectNo: Code[20]; TaskNo: Code[20]): Boolean
    var
        Job: Record Job;
        JobTask: Record "Job Task";
    begin
        if not Job.Get(ProjectNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', NotFoundNext());
            exit(false);
        end;
        if not JobTask.Get(ProjectNo, TaskNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', NotFoundNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure TravelReady(var Argument: Record "Message Argument ori"): Boolean
    var
        WorkType: Record "Work Type";
        Setup: Record "Projects Setup ori";
    begin
        if not Setup.Get() then
            Setup.Init();
        if (Setup."Travel Work Type Code" = '') or not WorkType.Get(Setup."Travel Work Type Code") then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'kind', TravelSetupNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure MileageReady(var Argument: Record "Message Argument ori"; var MileageResource: Record Resource): Boolean
    var
        Setup: Record "Projects Setup ori";
    begin
        if not Setup.Get() then
            Setup.Init();
        if (Setup."Mileage Resource No." = '') or not MileageResource.Get(Setup."Mileage Resource No.") then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'mileageKm', MileageSetupNext());
            exit(false);
        end;
        if MileageResource.Blocked or (MileageResource."Base Unit of Measure" = '') then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'mileageKm', MileageSetupNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure WithinTolerance(var Argument: Record "Message Argument ori"; At: DateTime): Boolean
    var
        Limit: Duration;
    begin
        Limit := ToleranceHours() * 60 * 60 * 1000;
        if CurrentDateTime() - At > Limit then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'at', OldTimeNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure ResolveResource(var Argument: Record "Message Argument ori"; var ResourceNo: Code[20]): Boolean
    var
        Resource: Record Resource;
    begin
        Resource.SetRange("Time Sheet Owner User ID", CallerId());
        Resource.SetRange("Use Time Sheet", true);
        if not Resource.FindSet() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', UnmappedNext());
            exit(false);
        end;
        ResourceNo := Resource."No.";
        if Resource.Next() <> 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', ManyResourcesNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure Replay(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; RequestId: Text): Boolean
    var
        Visit: Record "Proj. Field Visit ori";
        Response: JsonObject;
        Stored: Text;
    begin
        if RequestId = '' then
            exit(false);
        Visit.SetRange("Resource No.", ResourceNo);
        if Visit.FindSet() then
            repeat
                if Visit.TryGetRequest(RequestId, Stored) then begin
                    Response.ReadFrom(Stored);
                    Argument.SetResponseJson(Response);
                    exit(true);
                end;
            until Visit.Next() = 0;
        exit(false);
    end;

    local procedure RunWriter(var Argument: Record "Message Argument ori"; Operation: Integer; Payload: JsonObject)
    var
        Runner: Codeunit "Proj. Visit Runner ori";
        Response: JsonObject;
        Err: Text;
    begin
        if Database.IsInWriteTransaction() then
            Commit();
        Runner.SetCall(Operation, Payload);
        if not Runner.Run() then begin
            Err := CopyStr(GetLastErrorText(), 1, 250);
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, RetryMessage(), '', Err, '', RetryNext());
            exit;
        end;
        Response.ReadFrom(Runner.GetResult());
        Argument.SetResponseJson(Response);
    end;

    local procedure WorkTypeOf(Kind: Text): Code[10]
    begin
        // Callers pass a Code. BC uppercases it, so the text compare must ignore case.
        if LowerCase(Kind) = 'travel' then
            exit(TravelWorkType());
    end;

    local procedure WorkTypeOf(Visit: Record "Proj. Field Visit ori"): Code[10]
    begin
        if Visit.Kind = Visit.Kind::Travel then
            exit(TravelWorkType());
    end;

    local procedure TravelWorkType(): Code[10]
    var
        Setup: Record "Projects Setup ori";
    begin
        if Setup.Get() then
            exit(Setup."Travel Work Type Code");
    end;

    local procedure RoundingMinutes(): Integer
    var
        Setup: Record "Projects Setup ori";
    begin
        if not Setup.Get() then
            exit(1);
        if Setup."Rounding Minutes" < 1 then
            exit(1);
        exit(Setup."Rounding Minutes");
    end;

    local procedure ToleranceHours(): Integer
    var
        Setup: Record "Projects Setup ori";
    begin
        if not Setup.Get() then
            exit(24);
        if Setup."Client Time Tolerance Hours" <= 0 then
            exit(24);
        exit(Setup."Client Time Tolerance Hours");
    end;

    local procedure AllowOnly(var Argument: Record "Message Argument ori"; Request: JsonObject; Operation: Integer): Boolean
    var
        Allowed: List of [Text];
        KeyName: Text;
    begin
        case Operation of
            1:
                Allowed.AddRange('projectNo', 'taskNo', 'kind', 'at', 'autoStop', 'clientRequestId');
            2:
                Allowed.AddRange('visitId', 'at', 'note', 'clientRequestId');
            3:
                Allowed.AddRange('visitId', 'projectNo', 'taskNo', 'mileageKm', 'outcome', 'clientRequestId');
        end;
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName, UnknownNext());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadRequestId(Request: JsonObject; var Argument: Record "Message Argument ori"; var RequestId: Text): Boolean
    begin
        RequestId := '';
        if not Request.Contains('clientRequestId') then
            exit(true);
        exit(ReadOptionalText(Request, 'clientRequestId', Argument, 100, RequestId));
    end;

    local procedure ReadRequiredText(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; MaxLength: Integer; var Value: Code[20]): Boolean
    var
        Token: JsonToken;
        TextValue: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName, MissingNext());
            exit(false);
        end;
        if not JsonText(Token, MaxLength, false, TextValue) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, FormatNext());
            exit(false);
        end;
        Value := CopyStr(TextValue, 1, MaxStrLen(Value));
        exit(true);
    end;

    local procedure ReadOptionalText(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        if not Request.Contains(KeyName) then
            exit(true);
        if not Request.Get(KeyName, Token) then
            exit(true);
        if not JsonText(Token, MaxLength, true, Value) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, FormatNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadAutoStop(Request: JsonObject; var Argument: Record "Message Argument ori"; var AutoStop: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        AutoStop := false;
        if not Request.Contains('autoStop') then
            exit(true);
        if not Request.Get('autoStop', Token) then
            exit(true);
        if not Token.IsValue() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'autoStop', FormatNext());
            exit(false);
        end;
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        if not (Raw in ['true', 'false']) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'autoStop', FormatNext());
            exit(false);
        end;
        AutoStop := Raw = 'true';
        exit(true);
    end;

    local procedure ReadVisitId(Request: JsonObject; var Argument: Record "Message Argument ori"; var VisitId: Integer; var HasVisitId: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        HasVisitId := false;
        VisitId := 0;
        if not Request.Contains('visitId') then
            exit(true);
        if not Request.Get('visitId', Token) then
            exit(true);
        if not JsonNumber(Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'visitId', FormatNext());
            exit(false);
        end;
        Token.WriteTo(Raw);
        if StrPos(Raw, '.') > 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'visitId', FormatNext());
            exit(false);
        end;
        if not Evaluate(VisitId, DelChr(Raw, '<>', ' '), 9) or (VisitId <= 0) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'visitId', FormatNext());
            exit(false);
        end;
        HasVisitId := true;
        exit(true);
    end;

    local procedure ReadAt(Request: JsonObject; var Argument: Record "Message Argument ori"; var At: DateTime): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Contains('at') then begin
            At := CurrentDateTime();
            exit(true);
        end;
        if not Request.Get('at', Token) then begin
            At := CurrentDateTime();
            exit(true);
        end;
        if not JsonText(Token, 40, false, Raw) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'at', FormatNext());
            exit(false);
        end;
        if Raw.EndsWith('Z') then
            Raw := CopyStr(Raw, 1, StrLen(Raw) - 1);
        if not Evaluate(At, Raw, 9) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'at', FormatNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadMileage(Request: JsonObject; var Argument: Record "Message Argument ori"; var HasMileage: Boolean; var MileageText: Text; var Mileage: Decimal): Boolean
    var
        Token: JsonToken;
    begin
        HasMileage := false;
        Mileage := 0;
        MileageText := '';
        if not Request.Contains('mileageKm') then
            exit(true);
        if not Request.Get('mileageKm', Token) then
            exit(true);
        if not JsonNumber(Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'mileageKm', FormatNext());
            exit(false);
        end;
        Token.WriteTo(MileageText);
        MileageText := DelChr(MileageText, '<>', ' ');
        if not Evaluate(Mileage, MileageText, 9) or (Mileage <= 0) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'mileageKm', FormatNext());
            exit(false);
        end;
        HasMileage := true;
        exit(true);
    end;

    local procedure JsonText(Token: JsonToken; MaxLength: Integer; AllowEmpty: Boolean; var Value: Text): Boolean
    var
        Raw: Text;
    begin
        Value := '';
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        if CopyStr(DelChr(Raw, '<>', ' '), 1, 1) <> '"' then
            exit(false);
        Value := Token.AsValue().AsText();
        if (not AllowEmpty) and (Value = '') then
            exit(false);
        exit(StrLen(Value) <= MaxLength);
    end;

    local procedure JsonNumber(Token: JsonToken): Boolean
    var
        First: Text[1];
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        Raw := DelChr(Raw, '<>', ' ');
        First := CopyStr(Raw, 1, 1);
        exit(First in ['-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    end;

    local procedure CallerId(): Code[50]
    begin
        exit(CopyStr(UpperCase(UserId()), 1, 50));
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Parameter: Text; NextStep: Text)
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        Argument.RespondWithError(ErrorCode, Texts.RefusedText(), Parameter, '', '', NextStep);
    end;

    local procedure UnmappedNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.UnmappedNext());
    end;

    local procedure ManyResourcesNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.ManyResourcesNext());
    end;

    local procedure PermissionNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.PermissionNext());
    end;

    local procedure MissingNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.MissingNext());
    end;

    local procedure FormatNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.FormatNext());
    end;

    local procedure UnknownNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.UnknownNext());
    end;

    local procedure NotFoundNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.NotFoundNext());
    end;

    local procedure ConflictNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.ConflictNext());
    end;

    local procedure RunningNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.RunningNext());
    end;

    local procedure OldTimeNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.OldTimeNext());
    end;

    local procedure NoSheetNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.NoSheetNext());
    end;

    local procedure LockedLineNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.LockedLineNext());
    end;

    local procedure UnplannedNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.UnplannedNext());
    end;

    local procedure TravelSetupNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.TravelSetupNext());
    end;

    local procedure MileageSetupNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.MileageSetupNext());
    end;

    local procedure NotRunningNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.NotRunningNext());
    end;

    local procedure BeforeStartNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.BeforeStartNext());
    end;

    local procedure TooManyHoursNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.TooManyHoursNext());
    end;

    local procedure AlreadyDoneNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.AlreadyDoneNext());
    end;

    local procedure OtherVisitNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.OtherVisitNext());
    end;

    local procedure IsolatedNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.IsolatedNext());
    end;

    local procedure RetryNext(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.RetryNext());
    end;

    local procedure RetryMessage(): Text
    var
        Texts: Codeunit "Proj. Visit Contract ori";
    begin
        exit(Texts.RefusedText());
    end;
}
