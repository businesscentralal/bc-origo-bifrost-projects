namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Origo.Bifrost;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>Validates follow-up calls and scopes every read and decision to the caller.</summary>
codeunit 70013452 "Proj. Follow-up Mgt ori"
{
    Access = Internal;
    var
        RefusedLbl: Label 'The follow-up request could not be processed.', Comment = 'is-IS=Ekki tókst að vinna úr eftirfylgnibeiðninni.';
        NextLbl: Label 'Correct the indicated field and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu tilgreindan reit og reyndu aftur. Engu var breytt.';
        PermissionLbl: Label 'Use BIFROST Read with PROJ FIELD TECH ori for your own requests. Managers need BIFROST Full, native project rights and responsibility for the project.', Comment = 'is-IS=Notaðu BIFROST Read með PROJ FIELD TECH ori fyrir eigin beiðnir. Stjórnendur þurfa BIFROST Full, innbyggðar verkefnaheimildir og ábyrgð á verkefninu.';
        OpenLbl: Label 'Use an open request on an unblocked, unfinished project.', Comment = 'is-IS=Notaðu opna beiðni á óloknu verkefni sem er ekki lokað.';
        ListLbl: Label '%1 follow-up requests returned.', Comment = '%1 = count; is-IS=%1 eftirfylgnibeiðnum skilað.';

    /// <summary>Checks app and native rights without elevating the caller.</summary>
    procedure CanRun(Operation: Integer): Boolean
    var
        Setup: Record "Projects Setup ori";
        Request: Record "Proj. Follow-up Request ori";
        Line: Record "Proj. Follow-up Req. Line ori";
        Resource: Record Resource;
        Project: Record Job;
        Task: Record "Job Task";
    begin
        if not Setup.ReadPermission() then
            exit(false);
        if not Setup.IsEnabled() then
            exit(false);
        if not (Request.ReadPermission() and CanWrite(Database::"Proj. Follow-up Request ori") and Line.ReadPermission() and CanWrite(Database::"Proj. Follow-up Req. Line ori") and Resource.ReadPermission() and Project.ReadPermission() and Task.ReadPermission()) then
            exit(false);
        if Operation in [3, 4] then
            exit(IsManager());
        exit(true);
    end;

    local procedure CanWrite(TableId: Integer): Boolean
    var
        TempPermission: Record "Expanded Permission" temporary;
        UserPermissions: Codeunit "User Permissions";
    begin
        // WritePermission also requires delete; follow-up roles deliberately grant only RIM.
        TempPermission := UserPermissions.GetEffectivePermission(TempPermission."Object Type"::"Table Data", TableId);
        exit((TempPermission."Insert Permission" = TempPermission."Insert Permission"::Yes) and (TempPermission."Modify Permission" = TempPermission."Modify Permission"::Yes));
    end;

    /// <summary>Tests effective manager write rights, not licence entitlement.</summary>
    procedure IsManager(): Boolean
    var
        Task: Record "Job Task";
        Planning: Record "Job Planning Line";
    begin
        exit(Task.WritePermission() and Planning.WritePermission());
    end;

    /// <summary>Executes a read or starts one atomic write boundary.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Operation: Integer)
    var
        Result: Codeunit "Proj. Follow-up Result ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Argument.AssertVersion1();
        if not CanRun(Operation) then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl);
            exit;
        end;
        if not TryRead(Argument, Request) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'data', NextLbl);
            exit;
        end;
        if not Validate(Argument, Request, Operation) then
            exit;
        if Operation = 1 then
            if Replay(Argument, Request) then
                exit;
        if Operation = 2 then begin
            Response := ListRequests(Request);
            Argument.SetResponseJson(Response);
            exit;
        end;
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', NextLbl);
            exit;
        end;
        if Database.IsInWriteTransaction() then
            Commit();
        Result.Reset();
        if not Codeunit.Run(Codeunit::"Proj. Follow-up Runner ori", Argument) then
            if Result.Take(Response) then
                Argument.SetResponseJson(Response)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NextLbl);
        Result.Reset();
    end;

    [TryFunction]
    local procedure TryRead(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    /// <summary>Checks the full input tree and record state before the first business write.</summary>
    procedure Validate(var Argument: Record "Message Argument ori"; Request: JsonObject; Operation: Integer): Boolean
    var
        Header: Record "Proj. Follow-up Request ori";
        Project: Record Job;
        Task: Record "Job Task";
        Resource: Record Resource;
        Contract: Codeunit "Proj. Follow-up Contract ori";
        Staging: Codeunit "Blob Staging ori";
        Schema: JsonArray;
        Token: JsonToken;
        ItemsToken: JsonToken;
        StagingId: Guid;
        ResourceNo: Code[20];
        ProjectNo: Code[20];
        TaskNo: Code[20];
        Seen: List of [Guid];
    begin
        if not CanRun(Operation) then
            exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionLbl));
        Contract.AddParameters(Schema, Operation);
        if not ValidateObject(Argument, Request, Schema, '') then
            exit(false);
        if Operation = 1 then
            if Replay(Argument, Request) then
                exit(true);
        case Operation of
            1:
                begin
                    if not OwnResource(Argument, ResourceNo) then
                        exit(false);
                    ProjectNo := CopyStr(TextValue(Request, 'projectNo'), 1, 20);
                    TaskNo := CopyStr(TextValue(Request, 'taskNo'), 1, 20);
                    if not OpenProject(Argument, ProjectNo) then
                        exit(false);
                    if not Task.Get(ProjectNo, TaskNo) then
                        exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', NextLbl));
                    if Task."Job Task Type" <> Task."Job Task Type"::Posting then
                        exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', NextLbl));
                    if Request.Contains('estimatedHours') then
                        if Request.GetDecimal('estimatedHours') <= 0 then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'estimatedHours', NextLbl));
                    if Request.Contains('urgency') then
                        if not (TextValue(Request, 'urgency') in ['low', 'normal', 'high']) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'urgency', NextLbl));
                    if Request.Contains('items') then begin
                        if Request.GetArray('items').Count() > 100 then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'items', NextLbl));
                        Request.Get('items', ItemsToken);
                        foreach Token in ItemsToken.AsArray() do
                            if not ValidateItem(Argument, Token.AsObject()) then
                                exit(false);
                    end;
                    if Request.Contains('stagingIds') then begin
                        if Request.GetArray('stagingIds').Count() > 10 then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'stagingIds', NextLbl));
                        foreach Token in Request.GetArray('stagingIds') do begin
                            if not ValidStagingId(Token, StagingId) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'stagingIds', NextLbl));
                            if Seen.Contains(StagingId) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'stagingIds', NextLbl));
                            Seen.Add(StagingId);
                            if not Staging.Exists(StagingId) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'stagingIds', NextLbl));
                        end;
                    end;
                end;
            2:
                begin
                    if Request.Contains('status') then
                        if not (TextValue(Request, 'status') in ['Open', 'Converted', 'Rejected']) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'status', NextLbl));
                    if Request.Contains('take') then
                        if (IntegerValue(Request, 'take') < 1) or (IntegerValue(Request, 'take') > 100) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'take', NextLbl));
                    if not IsManager() then begin
                        if not OwnResource(Argument, ResourceNo) then
                            exit(false);
                        if Request.Contains('resourceNo') then
                            if TextValue(Request, 'resourceNo') <> ResourceNo then
                                exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'resourceNo', PermissionLbl));
                    end;
                    if Request.Contains('projectNo') then begin
                        if not Project.Get(TextValue(Request, 'projectNo')) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', NextLbl));
                        if IsManager() and not Manages(Project) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'projectNo', PermissionLbl));
                    end;
                end;
            3, 4:
                begin
                    if not Header.Get(IntegerValue(Request, 'requestId')) then
                        exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'requestId', NextLbl));
                    if not Project.Get(Header."Project No.") then
                        exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', NextLbl));
                    if not Manages(Project) then
                        exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'requestId', PermissionLbl));
                    if Header.Status <> Header.Status::Open then
                        exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'requestId', OpenLbl));
                    if not OpenProject(Argument, Header."Project No.") then
                        exit(false);
                    if Operation = 3 then begin
                        if not (TextValue(Request, 'target') in ['newTask', 'existingTask']) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'target', NextLbl));
                        TaskNo := CopyStr(TextValue(Request, 'taskNo'), 1, 20);
                        if TextValue(Request, 'target') = 'existingTask' then begin
                            if TaskNo = '' then
                                TaskNo := Header."Task No.";
                            if not Task.Get(Header."Project No.", TaskNo) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', NextLbl));
                            if Task."Job Task Type" <> Task."Job Task Type"::Posting then
                                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', NextLbl));
                        end else
                            if TaskNo <> '' then
                                if Task.Get(Header."Project No.", TaskNo) then
                                    exit(Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'taskNo', NextLbl));
                        ResourceNo := Header."Resource No.";
                        if Request.Contains('resourceNo') then
                            ResourceNo := CopyStr(TextValue(Request, 'resourceNo'), 1, 20);
                        if not Resource.Get(ResourceNo) then
                            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'resourceNo', NextLbl));
                    end;
                end;
        end;
        exit(true);
    end;

    local procedure ValidateItem(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Item: Record Item;
    begin
        if DecimalValue(RequestJson, 'quantity') <= 0 then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'items.quantity', NextLbl));
        if (TextValue(RequestJson, 'itemNo') = '') and (TextValue(RequestJson, 'description').Trim() = '') then
            exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'items.itemNo', NextLbl));
        if TextValue(RequestJson, 'itemNo') <> '' then
            if not Item.Get(TextValue(RequestJson, 'itemNo')) then
                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'items.itemNo', NextLbl));
        exit(true);
    end;

    /// <summary>Returns a technician's retained request for an existing client request id.</summary>
    procedure Replay(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Header: Record "Proj. Follow-up Request ori";
        Runner: Codeunit "Proj. Follow-up Runner ori";
    begin
        if TextValue(Request, 'clientRequestId') = '' then
            exit(false);
        Header.SetRange("Requested By", UserSecurityId());
        Header.SetRange("Client Request Id", TextValue(Request, 'clientRequestId'));
        if not Header.FindFirst() then
            exit(false);
        Argument.SetResponseJson(Runner.ResponseFor(Header));
        exit(true);
    end;

    local procedure ValidateObject(var Argument: Record "Message Argument ori"; Request: JsonObject; Schema: JsonArray; Path: Text): Boolean
    var
        ParameterToken: JsonToken;
        Value: JsonToken;
        Child: JsonToken;
        Parameter: JsonObject;
        Name: Text;
        Kind: Text;
        Raw: Text;
        Number: Decimal;
        Day: Date;
        Names: List of [Text];
    begin
        foreach ParameterToken in Schema do begin
            Parameter := ParameterToken.AsObject();
            Name := Parameter.GetText('name');
            Names.Add(Name);
            if not Request.Get(Name, Value) then begin
                if Parameter.GetBoolean('required') then
                    exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, Path + Name, NextLbl));
            end else begin
                Kind := Parameter.GetText('type');
                if Kind = 'array' then begin
                    if not Value.IsArray() then
                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                    if Parameter.Contains('children') then
                        foreach Child in Value.AsArray() do begin
                            if not Child.IsObject() then
                                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                            if not ValidateObject(Argument, Child.AsObject(), Parameter.GetArray('children'), Path + Name + '.') then
                                exit(false);
                        end;
                end else begin
                    if not Value.IsValue() then
                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                    if Value.AsValue().IsNull() then
                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                    Value.WriteTo(Raw);
                    case Kind of
                        'string', 'date':
                            begin
                                if not Raw.StartsWith('"') then
                                    exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                                if Parameter.GetBoolean('required') and (Value.AsValue().AsText().Trim() = '') then
                                    exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, Path + Name, NextLbl));
                                if Parameter.Contains('maxLength') then
                                    if StrLen(Value.AsValue().AsText()) > Parameter.GetInteger('maxLength') then
                                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                                if Kind = 'date' then
                                    if (StrLen(Value.AsValue().AsText()) <> 10) or not Evaluate(Day, Value.AsValue().AsText(), 9) or (Day = 0D) then
                                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                            end;
                        'number', 'integer':
                            begin
                                if Raw.StartsWith('"') or not Evaluate(Number, Raw, 9) then
                                    exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                                if Kind = 'integer' then
                                    if (Number < 0) or (Number > 2147483647) or (Round(Number, 1) <> Number) then
                                        exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                            end;
                        'boolean':
                            if not (Raw in ['true', 'false']) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Path + Name, NextLbl));
                    end;
                end;
            end;
        end;
        foreach Name in Request.Keys() do
            if not Names.Contains(Name) then
                exit(Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, Path + Name, NextLbl));
        exit(true);
    end;

    local procedure ValidStagingId(Token: JsonToken; var Id: Guid): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then
            exit(false);
        exit(Evaluate(Id, Token.AsValue().AsText()));
    end;

    /// <summary>Maps the caller to exactly one technician resource.</summary>
    procedure OwnResource(var Argument: Record "Message Argument ori"; var ResourceNo: Code[20]): Boolean
    var
        Resource: Record Resource;
    begin
        Resource.SetRange("Time Sheet Owner User ID", CopyStr(UserId(), 1, 50));
        Resource.SetRange("Use Time Sheet", true);
        if not Resource.FindSet() then
            exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'resourceNo', PermissionLbl));
        ResourceNo := Resource."No.";
        if Resource.Next() <> 0 then
            exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'resourceNo', NextLbl));
        exit(true);
    end;

    local procedure OpenProject(var Argument: Record "Message Argument ori"; ProjectNo: Code[20]): Boolean
    var
        Project: Record Job;
    begin
        if not Project.Get(ProjectNo) then
            exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', NextLbl));
        if (Project.Blocked <> Project.Blocked::" ") or (Project.Status = Project.Status::Completed) then
            exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', OpenLbl));
        exit(true);
    end;

    /// <summary>Checks content-edit ownership without granting additional table rights.</summary>
    procedure CanEdit(Header: Record "Proj. Follow-up Request ori"): Boolean
    var
        Project: Record Job;
    begin
        if Header."Requested By" = UserSecurityId() then
            exit(true);
        if not IsManager() then
            exit(false);
        if Project.Get(Header."Project No.") then
            exit(Manages(Project));
        exit(false);
    end;

    local procedure Manages(Project: Record Job): Boolean
    var
        Resource: Record Resource;
    begin
        if Project."Project Manager" = CopyStr(UserId(), 1, 50) then
            exit(true);
        if Project."Person Responsible" = '' then
            exit(false);
        if Resource.Get(Project."Person Responsible") then
            exit(Resource."Time Sheet Owner User ID" = CopyStr(UserId(), 1, 50));
        exit(false);
    end;

    /// <summary>Applies visibility to the client page without exposing other technicians' rows.</summary>
    procedure FilterVisible(var Header: Record "Proj. Follow-up Request ori")
    var
        Project: Record Job;
    begin
        if not IsManager() then begin
            Header.FilterGroup(2);
            Header.SetRange("Requested By", UserSecurityId());
            Header.FilterGroup(0);
            exit;
        end;
        if Header.FindSet() then
            repeat
                if Project.Get(Header."Project No.") then
                    if Manages(Project) then
                        Header.Mark(true);
            until Header.Next() = 0;
        Header.MarkedOnly(true);
    end;

    local procedure ListRequests(RequestJson: JsonObject) Response: JsonObject
    var
        Header: Record "Proj. Follow-up Request ori";
        Requests: JsonArray;
        Skip: Integer;
        Take: Integer;
    begin
        FilterVisible(Header);
        if RequestJson.Contains('projectNo') then
            Header.SetRange("Project No.", TextValue(RequestJson, 'projectNo'));
        if RequestJson.Contains('resourceNo') then
            Header.SetRange("Resource No.", TextValue(RequestJson, 'resourceNo'));
        if RequestJson.Contains('status') then
            case TextValue(RequestJson, 'status') of
                'Open': Header.SetRange(Status, Header.Status::Open);
                'Converted': Header.SetRange(Status, Header.Status::Converted);
                'Rejected': Header.SetRange(Status, Header.Status::Rejected);
            end;
        Take := 50;
        if RequestJson.Contains('take') then
            Take := IntegerValue(RequestJson, 'take');
        if RequestJson.Contains('skip') then
            Skip := IntegerValue(RequestJson, 'skip');
        if Header.FindSet() then
            repeat
                if Skip > 0 then
                    Skip -= 1
                else
                    Requests.Add(ToJson(Header));
            until (Header.Next() = 0) or (Requests.Count() = Take);
        Response.Add('status', 'Success');
        Response.Add('requests', Requests);
        Response.Add('summary', StrSubstNo(ListLbl, Requests.Count()));
    end;

    /// <summary>Returns only the caller's follow-ups for a visit brief.</summary>
    procedure Brief(ProjectNo: Code[20]; TaskNo: Code[20]) Requests: JsonArray
    var
        Header: Record "Proj. Follow-up Request ori";
    begin
        Header.SetRange("Project No.", ProjectNo);
        Header.SetRange("Task No.", TaskNo);
        Header.SetRange("Requested By", UserSecurityId());
        if Header.FindSet() then
            repeat
                Requests.Add(ToJson(Header));
            until (Header.Next() = 0) or (Requests.Count() = 100);
    end;

    /// <summary>Serializes the request with immutable native result keys.</summary>
    procedure ToJson(Header: Record "Proj. Follow-up Request ori") Response: JsonObject
    var
        Line: Record "Proj. Follow-up Req. Line ori";
        Items: JsonArray;
        Photos: JsonArray;
        Node: JsonObject;
        StatusNames: List of [Text];
        StatusOrdinals: List of [Integer];
    begin
        Response.Add('requestId', Header."Entry No.");
        Response.Add('projectNo', Header."Project No.");
        Response.Add('taskNo', Header."Task No.");
        Response.Add('resourceNo', Header."Resource No.");
        Response.Add('description', Header.Description);
        Response.Add('estimatedHours', Header."Estimated Hours");
        if Header."Preferred Date" <> 0D then
            Response.Add('preferredDate', Format(Header."Preferred Date", 0, 9));
        Response.Add('urgency', Header.Urgency);
        StatusNames := Header.Status.Names();
        StatusOrdinals := Header.Status.Ordinals();
        Response.Add('status', StatusNames.Get(StatusOrdinals.IndexOf(Header.Status.AsInteger())));
        Response.Add('convertedTaskNo', Header."Converted Task No.");
        Response.Add('resourcePlanningLineNo', Header."Resource Planning Line No.");
        Response.Add('reason', Header."Rejection Reason");
        Line.SetRange("Request No.", Header."Entry No.");
        if Line.FindSet() then
            repeat
                Clear(Node);
                if Line."Is Photo" then begin
                    Node.Add('lineNo', Line."Line No.");
                    Node.Add('fileName', Line."File Name");
                    Node.Add('contentType', Line."Content Type");
                    Photos.Add(Node);
                end else begin
                    Node.Add('itemNo', Line."Item No.");
                    Node.Add('description', Line.Description);
                    Node.Add('quantity', Line.Quantity);
                    Node.Add('planningLineNo', Line."Planning Line No.");
                    Items.Add(Node);
                end;
            until Line.Next() = 0;
        Response.Add('items', Items);
        Response.Add('photos', Photos);
    end;

    /// <summary>Reads an optional, already validated text value.</summary>
    procedure TextValue(Request: JsonObject; Name: Text): Text
    begin
        if Request.Contains(Name) then
            exit(Request.GetText(Name));
    end;

    /// <summary>Reads an integer after schema validation.</summary>
    procedure IntegerValue(Data: JsonObject; Name: Text): Integer
    begin
        exit(Data.GetInteger(Name));
    end;

    /// <summary>Reads a decimal after schema validation.</summary>
    procedure DecimalValue(Data: JsonObject; Name: Text): Decimal
    begin
        exit(Data.GetDecimal(Name));
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(Code, RefusedLbl, Parameter, '', '', NextStep);
        exit(false);
    end;
}
