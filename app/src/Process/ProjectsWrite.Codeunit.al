namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Validates complete write requests and dispatches isolated native transactions.</summary>
codeunit 10078499 "Projects Write ori"
{
    Access = Internal;
    /// <summary>Validates a request before running its transactional native operation.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Kind: Text; Operation: Text)
    var
        Contract: Codeunit "Projects Contract ori";
        Input: Codeunit "Projects Input ori";
        Gate: Codeunit "Projects Gate ori";
        Request: JsonObject;
        InvalidErr: Label 'Projects data must be a JSON object.', Comment = 'is-IS=Verkefnisgögn verða að vera JSON-hlutur.';
        MissingChangeErr: Label 'Send status or blocked to change the project state.', Comment = 'is-IS=Sendu status eða blocked til að breyta stöðu verkefnis.';
        SummaryErr: Label 'Correct the invalid Projects parameters.', Comment = 'is-IS=Leiðréttu ógild viðföng verkefnis.';
    begin
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'data', '', 'object', '');
            exit;
        end;
        if not Input.ValidateRequest(Argument, Request, Contract.Parameters(Kind, Operation, false), '') then begin
            Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, SummaryErr);
            exit;
        end;
        if (Operation = 'SetStatus') and not Request.Contains('status') and not Request.Contains('blocked') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingChangeErr, 'status', '', '', '');
            exit;
        end;
        if Operation = 'Copy' then begin
            if not Gate.AssertEnabled(Argument, Database::"Job Task", true) then
                exit;
            if not Gate.AssertEnabled(Argument, Database::"Job Planning Line", true) then
                exit;
        end;
        if not CheckNestedPermissions(Argument, Request) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Projects Write Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Projects Write Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    local procedure CheckNestedPermissions(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        Token: JsonToken;
        TaskToken: JsonToken;
    begin
        if Request.Get('tasks', Token) then begin
            if not Gate.AssertEnabled(Argument, Database::"Job Task", true) then
                exit(false);
            foreach TaskToken in Token.AsArray() do
                if not CheckNestedPermissions(Argument, TaskToken.AsObject()) then
                    exit(false);
        end;
        if Request.Get('planningLines', Token) then
            if not Gate.AssertEnabled(Argument, Database::"Job Planning Line", true) then
                exit(false);
        exit(true);
    end;

    /// <summary>Executes validated input inside the process codeunit's rollback boundary.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        WIP: Codeunit "Projects WIP ori";
        Request: JsonObject;
        Response: JsonObject;
        ProjectNo: Code[20];
        TaskNo: Code[20];
        LineNo: Integer;
    begin
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        if Argument.Type in ["Message Type ori"::"Projects.WIP.Get", "Message Type ori"::"Projects.WIP.Calculate"] then begin
            WIP.Execute(Argument);
            exit;
        end;
        case Argument.Type of
            "Message Type ori"::"Projects.Project.SetStatus":
                ChangeStatus(Request, ProjectNo);
            "Message Type ori"::"Projects.Project.Copy":
                begin
                    CopyProject(Request, ProjectNo);
                    Response.Add('sourceProjectNo', ProjectNo);
                    ProjectNo := CopyStr(Request.GetText('targetProjectNo'), 1, MaxStrLen(ProjectNo));
                end;
            "Message Type ori"::"Projects.Project.Create":
                WriteProject(Request, ProjectNo, true);
            "Message Type ori"::"Projects.Project.Update":
                WriteProject(Request, ProjectNo, false);
            "Message Type ori"::"Projects.Task.Create", "Message Type ori"::"Projects.Task.Update":
                begin
                    TaskNo := CopyStr(Request.GetText('taskNo'), 1, MaxStrLen(TaskNo));
                    WriteTask(Request, ProjectNo, TaskNo, Argument.Type = "Message Type ori"::"Projects.Task.Create");
                end;
            "Message Type ori"::"Projects.PlanningLine.Create", "Message Type ori"::"Projects.PlanningLine.Update", "Message Type ori"::"Projects.PlanningLine.Delete":
                begin
                    TaskNo := CopyStr(Request.GetText('taskNo'), 1, MaxStrLen(TaskNo));
                    LineNo := Request.GetInteger('lineNo');
                    WritePlanningLine(Request, ProjectNo, TaskNo, LineNo, Argument.Type);
                end;
        end;
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        if TaskNo <> '' then
            Response.Add('taskNo', TaskNo);
        if LineNo <> 0 then
            Response.Add('lineNo', LineNo);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ChangeStatus(Request: JsonObject; ProjectNo: Code[20])
    var
        Project: Record Job;
        ProjectRef: RecordRef;
        StateField: FieldRef;
        Token: JsonToken;
    begin
        Project.Get(ProjectNo);
        Project.SetHideValidationDialog(true);
        if Request.Get('status', Token) then begin
            ProjectRef.GetTable(Project);
            StateField := ProjectRef.Field(Project.FieldNo(Status));
            ValidateEnum(StateField, Token.AsValue().AsText());
            ProjectRef.SetTable(Project);
        end;
        if Request.Get('blocked', Token) then
            case Token.AsValue().AsText() of
                'None':
                    Project.Validate(Blocked, Project.Blocked::" ");
                'Posting':
                    Project.Validate(Blocked, Project.Blocked::Posting);
                'All':
                    Project.Validate(Blocked, Project.Blocked::All);
            end;
        Project.Modify(true);
    end;

    local procedure CopyProject(Request: JsonObject; SourceProjectNo: Code[20])
    var
        SourceProject: Record Job;
        CopyJob: Codeunit "Copy Job";
        PlanType: Option " ",Budget,Billable;
        Token: JsonToken;
        RangeErr: Label 'The first task number must not exceed the last task number.', Comment = 'is-IS=Fyrsta verkþáttanúmerið má ekki vera hærra en það síðasta.';
    begin
        SourceProject.Get(SourceProjectNo);
        if (GetOptionalText(Request, 'fromTaskNo') <> '') and (GetOptionalText(Request, 'toTaskNo') <> '') then
            if GetOptionalText(Request, 'fromTaskNo') > GetOptionalText(Request, 'toTaskNo') then
                Error(ErrorInfo.Create(RangeErr));
        if Request.Get('planningLineType', Token) then
            case Token.AsValue().AsText() of
                'Budget':
                    PlanType := PlanType::Budget;
                'Billable':
                    PlanType := PlanType::Billable;
            end;
        CopyJob.SetCopyOptions(GetOptionalBoolean(Request, 'copyPrices', true), GetOptionalBoolean(Request, 'copyQuantity', true), GetOptionalBoolean(Request, 'copyDimensions', true), 0, PlanType, 0);
        CopyJob.SetJobTaskRange(CopyStr(GetOptionalText(Request, 'fromTaskNo'), 1, 20), CopyStr(GetOptionalText(Request, 'toTaskNo'), 1, 20));
        CopyJob.CopyJob(SourceProject, CopyStr(Request.GetText('targetProjectNo'), 1, 20), CopyStr(GetOptionalText(Request, 'description'), 1, 100), CopyStr(GetOptionalText(Request, 'sellToCustomerNo'), 1, 20), CopyStr(GetOptionalText(Request, 'billToCustomerNo'), 1, 20));
    end;

    local procedure GetOptionalText(Request: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Request.Get(Name, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure GetOptionalBoolean(Request: JsonObject; Name: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        if Request.Get(Name, Token) then
            exit(Token.AsValue().AsBoolean());
        exit(DefaultValue);
    end;

    local procedure IsNestedCreate(Request: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Request.Get('operation', Token) then
            exit(true);
        exit(Token.AsValue().AsText() = 'Create');
    end;

    local procedure WriteProject(Request: JsonObject; ProjectNo: Code[20]; CreateNew: Boolean)
    var
        Project: Record Job;
        Child: JsonToken;
        Token: JsonToken;
        TaskRequest: JsonObject;
        TaskNo: Code[20];
    begin
        if CreateNew then begin
            Project.Init();
            Project.Validate("No.", ProjectNo);
        end else
            Project.Get(ProjectNo);
        ApplyProjectFields(Project, Request);
        if CreateNew then
            Project.Insert(true)
        else
            Project.Modify(true);
        if Request.Get('tasks', Token) then
            foreach Child in Token.AsArray() do begin
                TaskRequest := Child.AsObject();
                TaskNo := CopyStr(TaskRequest.GetText('taskNo'), 1, MaxStrLen(TaskNo));
                WriteTask(TaskRequest, ProjectNo, TaskNo, IsNestedCreate(TaskRequest));
            end;
    end;

    local procedure WriteTask(Request: JsonObject; ProjectNo: Code[20]; TaskNo: Code[20]; CreateNew: Boolean)
    var
        Project: Record Job;
        Task: Record "Job Task";
        Child: JsonToken;
        Token: JsonToken;
        PlanningRequest: JsonObject;
    begin
        Project.Get(ProjectNo);
        if CreateNew then begin
            Task.Init();
            Task.Validate("Job No.", ProjectNo);
            Task.Validate("Job Task No.", TaskNo);
        end else
            Task.Get(ProjectNo, TaskNo);
        ApplyTaskFields(Task, Request);
        if CreateNew then
            Task.Insert(true)
        else
            Task.Modify(true);
        if Request.Get('planningLines', Token) then
            foreach Child in Token.AsArray() do begin
                PlanningRequest := Child.AsObject();
                if IsNestedCreate(PlanningRequest) then
                    WritePlanningLine(PlanningRequest, ProjectNo, TaskNo, PlanningRequest.GetInteger('lineNo'), "Message Type ori"::"Projects.PlanningLine.Create")
                else
                    WritePlanningLine(PlanningRequest, ProjectNo, TaskNo, PlanningRequest.GetInteger('lineNo'), "Message Type ori"::"Projects.PlanningLine.Update");
            end;
    end;

    local procedure WritePlanningLine(Request: JsonObject; ProjectNo: Code[20]; TaskNo: Code[20]; LineNo: Integer; MessageType: Enum "Message Type ori")
    var
        PlanningLine: Record "Job Planning Line";
        Task: Record "Job Task";
    begin
        Task.Get(ProjectNo, TaskNo);
        if MessageType = "Message Type ori"::"Projects.PlanningLine.Create" then begin
            PlanningLine.Init();
            PlanningLine.Validate("Job No.", ProjectNo);
            PlanningLine.Validate("Job Task No.", TaskNo);
            PlanningLine.Validate("Line No.", LineNo);
        end else
            PlanningLine.Get(ProjectNo, TaskNo, LineNo);
        if MessageType = "Message Type ori"::"Projects.PlanningLine.Delete" then begin
            PlanningLine.Delete(true);
            exit;
        end;
        ApplyPlanningLineFields(PlanningLine, Request);
        if MessageType = "Message Type ori"::"Projects.PlanningLine.Create" then
            PlanningLine.Insert(true)
        else
            PlanningLine.Modify(true);
    end;

    local procedure ApplyProjectFields(var Target: Record "Job"; Request: JsonObject)
    var
        Token: JsonToken;
        DateValue: Date;
    begin
        if Request.Get('description', Token) then
            Target.Validate("Description", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Description")));
        if Request.Get('billToCustomerNo', Token) then
            Target.Validate("Bill-to Customer No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Bill-to Customer No.")));
        if Request.Get('personResponsible', Token) then
            Target.Validate("Person Responsible", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Person Responsible")));
        if Request.Get('startingDate', Token) then begin
            Evaluate(DateValue, Token.AsValue().AsText(), 9);
            Target.Validate("Starting Date", DateValue);
        end;
        if Request.Get('endingDate', Token) then begin
            Evaluate(DateValue, Token.AsValue().AsText(), 9);
            Target.Validate("Ending Date", DateValue);
        end;
        if Request.Get('currencyCode', Token) then
            Target.Validate("Currency Code", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Currency Code")));
    end;

    local procedure ApplyTaskFields(var Target: Record "Job Task"; Request: JsonObject)
    var
        TargetRef: RecordRef;
        EnumField: FieldRef;
        Token: JsonToken;
    begin
        if Request.Get('taskType', Token) then begin
            TargetRef.GetTable(Target);
            EnumField := TargetRef.Field(Target.FieldNo("Job Task Type"));
            ValidateEnum(EnumField, Token.AsValue().AsText());
            TargetRef.SetTable(Target);
        end;
        if Request.Get('description', Token) then
            Target.Validate("Description", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Description")));
        if Request.Get('totaling', Token) then
            Target.Validate("Totaling", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Totaling")));
        if Request.Get('indentation', Token) then
            Target.Validate("Indentation", Token.AsValue().AsInteger());
    end;

    local procedure ApplyPlanningLineFields(var Target: Record "Job Planning Line"; Request: JsonObject)
    var
        TargetRef: RecordRef;
        EnumField: FieldRef;
        Token: JsonToken;
        DateValue: Date;
    begin
        if Request.Get('lineType', Token) then begin
            TargetRef.GetTable(Target);
            EnumField := TargetRef.Field(Target.FieldNo("Line Type"));
            ValidateEnum(EnumField, Token.AsValue().AsText());
            TargetRef.SetTable(Target);
        end;
        if Request.Get('type', Token) then begin
            TargetRef.GetTable(Target);
            EnumField := TargetRef.Field(Target.FieldNo("Type"));
            ValidateEnum(EnumField, Token.AsValue().AsText());
            TargetRef.SetTable(Target);
        end;
        if Request.Get('no', Token) then
            Target.Validate("No.", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."No.")));
        if Request.Get('description', Token) then
            Target.Validate("Description", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Description")));
        if Request.Get('planningDate', Token) then begin
            Evaluate(DateValue, Token.AsValue().AsText(), 9);
            Target.Validate("Planning Date", DateValue);
        end;
        if Request.Get('unitOfMeasureCode', Token) then
            Target.Validate("Unit of Measure Code", CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Target."Unit of Measure Code")));
        if Request.Get('quantity', Token) then
            Target.Validate("Quantity", Token.AsValue().AsDecimal());
        if Request.Get('unitCost', Token) then
            Target.Validate("Unit Cost", Token.AsValue().AsDecimal());
        if Request.Get('unitPrice', Token) then
            Target.Validate("Unit Price", Token.AsValue().AsDecimal());
    end;

    local procedure ValidateEnum(var Target: FieldRef; Name: Text)
    var
        Index: Integer;
        EnumErr: Label 'The native field does not support the enum value %1.', Comment = '%1 = enum name, is-IS=Innbyggði reiturinn styður ekki upptalningargildið %1.';
    begin
        for Index := 1 to Target.EnumValueCount() do
            if Target.GetEnumValueName(Index) = Name then begin
                Target.Validate(Target.GetEnumValueOrdinal(Index));
                exit;
            end;
        Error(ErrorInfo.Create(StrSubstNo(EnumErr, Name)));
    end;
}
