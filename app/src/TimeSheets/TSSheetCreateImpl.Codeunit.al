namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.Period;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;
using System.Security.User;

/// <summary>
/// Creates weekly time sheets for chosen resources.
/// </summary>
codeunit 70013571 "TS Sheet Create Impl ori" implements "Msg Interface ori", "Msg Contract ori", "Msg Discovery ori"
{
    Access = Internal;

    /// <summary>Provides IsEnabled for time sheet creation.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(CanCreate());
    end;

    /// <summary>Provides GetFilterTableNo for time sheet creation.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Provides GetDescription for time sheet creation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides GetKeywords for time sheet creation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'time sheet, create, timesheets', Comment = 'is-IS=tímaskýrsla, búa til, tímaskýrslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides GetSelectionDescription for time sheet creation.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Projects.TimeSheet.Create: Creates time sheets for chosen resources and weeks.', Comment = 'is-IS=Projects.TimeSheet.Create: Býr til tímaskýrslur fyrir valdar auðlindir og vikur.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides GetEnvelope for time sheet creation.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetEnvelope(Envelope));
    end;

    /// <summary>Provides GetTarget for time sheet creation.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetParameters for time sheet creation.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetParameters(Parameters));
    end;

    /// <summary>Provides GetResponse for time sheet creation.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetResponse(Response));
    end;

    /// <summary>Provides GetErrors for time sheet creation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetErrors(Errors));
    end;

    /// <summary>Provides GetEffect for time sheet creation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetEffect(Effect));
    end;

    /// <summary>Provides GetMetering for time sheet creation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for time sheet creation.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetRelated(Related));
    end;

    /// <summary>Provides GetWorkflow for time sheet creation.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetWorkflow(Workflow));
    end;

    /// <summary>Provides GetExamples for time sheet creation.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetExamples(Examples));
    end;

    /// <summary>Provides GetOverview for time sheet creation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetOverview(Overview));
    end;

    /// <summary>Provides GetNotes for time sheet creation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "TS Create Contract ori";
    begin
        exit(Parts.GetNotes(Notes));
    end;

    /// <summary>Provides GetMessageDirection for time sheet creation.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for time sheet creation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        ExecuteCreate(Argument);
    end;

    var
        DescriptionLbl: Label 'Creates time sheets for chosen resources and weeks.', Comment = 'is-IS=Býr til tímaskýrslur fyrir valdar auðlindir og vikur.';
        MissingLbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        TypeLbl: Label 'A key has the wrong JSON type or value.', Comment = 'is-IS=Lykill er af röngu JSON-tagi eða hefur rangt gildi.';
        TypeNextLbl: Label 'Send the key with the documented type.', Comment = 'is-IS=Sendu lykilinn með skráðu tagi.';
        UnknownLbl: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        ResourceLbl: Label 'The resource was not found, is blocked or does not use time sheets.', Comment = 'is-IS=Auðlindin fannst ekki, er læst eða notar ekki tímaskýrslur.';
        ResourceNextLbl: Label 'Turn on Use Time Sheet on the resource.', Comment = 'is-IS=Kveiktu á Notaðu tímaskýrslu á auðlindinni.';
        ConflictLbl: Label 'Choose resources in only one way.', Comment = 'is-IS=Veldu auðlindir á aðeins einn hátt.';
        ConflictNextLbl: Label 'Send only one of resourceNo, resourceNos or resourceGroup.', Comment = 'is-IS=Sendu aðeins eitt af resourceNo, resourceNos eða resourceGroup.';
        PermissionLbl: Label 'The caller lacks permission to create time sheets.', Comment = 'is-IS=Kallandinn hefur ekki heimild til að búa til tímaskýrslur.';
        PermissionNextLbl: Label 'Assign the BIFROST Full ori and PROJ TS ADMIN permission sets.', Comment = 'is-IS=Úthlutaðu heimildasamstæðunum BIFROST Full ori og PROJ TS ADMIN.';
        WeekdayLbl: Label 'startingDate must be %1.', Comment = '%1 = first weekday|is-IS=startingDate verður að vera %1.';
        WeekdayNextLbl: Label 'Use the first weekday named in the refusal.', Comment = 'is-IS=Notaðu fyrsta vikudaginn sem höfnunin nefnir.';
        LimitLbl: Label 'numberOfPeriods is above 52.', Comment = 'is-IS=numberOfPeriods er yfir 52.';
        LimitNextLbl: Label 'Split the call.', Comment = 'is-IS=Skiptu kallinu.';
        PeriodLbl: Label 'numberOfPeriods must be from 1 to 52.', Comment = 'is-IS=numberOfPeriods verður að vera frá 1 til 52.';
        PeriodNextLbl: Label 'Send a number from 1 to 52.', Comment = 'is-IS=Sendu tölu frá 1 til 52.';
        SetupLbl: Label 'Time sheet setup is incomplete or the caller is not a time sheet administrator.', Comment = 'is-IS=Uppsetning tímaskýrslna er ófullgerð eða kallandinn er ekki stjórnandi tímaskýrslna.';
        SetupNextLbl: Label 'Configure time sheet numbering and Time Sheet Admin. in User Setup.', Comment = 'is-IS=Stilltu númeraröð tímaskýrslna og Stjórnandi tímaskýrslna í notandauppsetningu.';
        WriteLbl: Label 'Business Central could not create the requested time sheets. Nothing was written.', Comment = 'is-IS=Business Central gat ekki búið til umbeðnar tímaskýrslur. Ekkert var skrifað.';
        WriteNextLbl: Label 'Check the resource owners, approvers, numbering and open accounting periods, then retry.', Comment = 'is-IS=Athugaðu eigendur auðlinda, samþykktaraðila, númeraröð og opin reikningstímabil og reyndu aftur.';

    /// <summary>Checks all reads and writes used by the native report and optional planning lines.</summary>
    procedure CanCreate(): Boolean
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Detail: Record "Time Sheet Detail";
        Resource: Record Resource;
        ResourceGroup: Record "Resource Group";
        ResourcesSetup: Record "Resources Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        UserSetup: Record "User Setup";
        AccountingPeriod: Record "Accounting Period";
        Job: Record Job;
        JobTask: Record "Job Task";
        JobPlanningLine: Record "Job Planning Line";
    begin
        exit(Header.ReadPermission() and Header.WritePermission() and
            Line.ReadPermission() and Line.WritePermission() and Detail.ReadPermission() and Detail.WritePermission() and
            Resource.ReadPermission() and ResourceGroup.ReadPermission() and ResourcesSetup.ReadPermission() and
            NoSeries.ReadPermission() and NoSeriesLine.ReadPermission() and NoSeriesLine.WritePermission() and
            UserSetup.ReadPermission() and AccountingPeriod.ReadPermission() and Job.ReadPermission() and
            JobTask.ReadPermission() and JobPlanningLine.ReadPermission());
    end;

    local procedure ExecuteCreate(var Argument: Record "Message Argument ori")
    var
        TempWriteArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Normalized: JsonObject;
    begin
        if not CanCreate() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request, Normalized) then
            exit;
        TempWriteArgument := Argument;
        TempWriteArgument.Insert();
        TempWriteArgument.SetRequestJson(Normalized);
        // Omit Commit participates in the enclosing caller transaction. Normal queue
        // dispatch captures Run's result and rolls the entire report batch back on failure.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"TS Create Writer ori", TempWriteArgument)
        else begin
            if Database.IsInWriteTransaction() then
                Commit();
            ClearLastError();
            if not Codeunit.Run(Codeunit::"TS Create Writer ori", TempWriteArgument) then begin
                Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, WriteLbl, '', WriteNextLbl);
                exit;
            end;
        end;
        Argument.SetResponseJson(TempWriteArgument.GetResponseJson());
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; var Normalized: JsonObject): Boolean
    var
        ResourcesSetup: Record "Resources Setup";
        UserSetup: Record "User Setup";
        Allowed: List of [Text];
        ParameterName: Text;
        Token: JsonToken;
        StartingDate: Date;
        Periods: Integer;
        Number: Decimal;
        FromPlanning: Boolean;
        Resources: JsonArray;
    begin
        Allowed.Add('startingDate');
        Allowed.Add('numberOfPeriods');
        Allowed.Add('resourceNo');
        Allowed.Add('resourceNos');
        Allowed.Add('resourceGroup');
        Allowed.Add('createLinesFromPlanning');
        foreach ParameterName in Request.Keys() do
            if not Allowed.Contains(ParameterName) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownLbl, ParameterName, UnknownNextLbl));
        if not Request.Get('startingDate', Token) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'startingDate', MissingNextLbl));
        if not IsString(Token) then
            exit(WrongType(Argument, 'startingDate'));
        if not Evaluate(StartingDate, Token.AsValue().AsText(), 9) then
            exit(WrongType(Argument, 'startingDate'));
        if StartingDate = 0D then
            exit(WrongType(Argument, 'startingDate'));
        Periods := 1;
        if Request.Get('numberOfPeriods', Token) then begin
            if not IsNumber(Token) then
                exit(WrongType(Argument, 'numberOfPeriods'));
            if not Evaluate(Number, Token.AsValue().AsText(), 9) then
                exit(WrongType(Argument, 'numberOfPeriods'));
            if Number <> Round(Number, 1) then
                exit(WrongType(Argument, 'numberOfPeriods'));
            if Number > 52 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::LimitExceeded, LimitLbl, 'numberOfPeriods', LimitNextLbl));
            if Number < 1 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, PeriodLbl, 'numberOfPeriods', PeriodNextLbl));
            Periods := Number;
        end;
        if StartingDate > (99991231D - Periods * 7) then
            exit(WrongType(Argument, 'startingDate'));
        if Request.Get('createLinesFromPlanning', Token) then begin
            if not IsBoolean(Token) then
                exit(WrongType(Argument, 'createLinesFromPlanning'));
            FromPlanning := Token.AsValue().AsBoolean();
        end;
        ResourcesSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        UserSetup.ReadIsolation := IsolationLevel::ReadCommitted;
        if not ResourcesSetup.Get() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SetupLbl, '', SetupNextLbl));
        if Date2DWY(StartingDate, 1) <> ResourcesSetup."Time Sheet First Weekday" + 1 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed,
                StrSubstNo(WeekdayLbl, SelectStr(ResourcesSetup."Time Sheet First Weekday" + 1, WeekdaysLbl)), 'startingDate', WeekdayNextLbl));
        if not ResolveResources(Argument, Request, Resources) then
            exit(false);
        if not UserSetup.Get(UserId()) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SetupLbl, '', SetupNextLbl));
        if (not UserSetup."Time Sheet Admin.") or (ResourcesSetup."Time Sheet Nos." = '') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SetupLbl, '', SetupNextLbl));
        Normalized.Add('startingDate', Format(StartingDate, 0, 9));
        Normalized.Add('numberOfPeriods', Periods);
        Normalized.Add('resourceNos', Resources);
        Normalized.Add('createLinesFromPlanning', FromPlanning);
        exit(true);
    end;

    local procedure ResolveResources(var Argument: Record "Message Argument ori"; Request: JsonObject; var Resources: JsonArray): Boolean
    var
        Resource: Record Resource;
        ResourceGroup: Record "Resource Group";
        Seen: List of [Code[20]];
        Token: JsonToken;
        Entry: JsonToken;
        Selections: Integer;
    begin
        if Request.Contains('resourceNo') then
            Selections += 1;
        if Request.Contains('resourceNos') then
            Selections += 1;
        if Request.Contains('resourceGroup') then
            Selections += 1;
        if Selections = 0 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'resourceNos', MissingNextLbl));
        if Selections > 1 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'resourceNos', ConflictNextLbl));
        if Request.Get('resourceNo', Token) then
            exit(AddResource(Argument, Token, 'resourceNo', Seen, Resources));
        if Request.Get('resourceNos', Token) then begin
            if not Token.IsArray() then
                exit(WrongType(Argument, 'resourceNos'));
            foreach Entry in Token.AsArray() do
                if not AddResource(Argument, Entry, 'resourceNos', Seen, Resources) then
                    exit(false);
            if Resources.Count() = 0 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'resourceNos', MissingNextLbl));
            exit(true);
        end;
        Request.Get('resourceGroup', Token);
        if not IsString(Token) then
            exit(WrongType(Argument, 'resourceGroup'));
        if (Token.AsValue().AsText() = '') or (StrLen(Token.AsValue().AsText()) > MaxStrLen(ResourceGroup."No.")) then
            exit(WrongType(Argument, 'resourceGroup'));
        ResourceGroup.ReadIsolation := IsolationLevel::ReadCommitted;
        if not ResourceGroup.Get(Token.AsValue().AsText()) then
            exit(MissingResource(Argument, 'resourceGroup'));
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        Resource.SetLoadFields("No.", "Resource Group No.", "Use Time Sheet", Blocked);
        Resource.SetRange("Resource Group No.", ResourceGroup."No.");
        if Resource.FindSet() then
            repeat
                if (not Resource."Use Time Sheet") or Resource.Blocked then
                    exit(MissingResource(Argument, 'resourceGroup'));
                Resources.Add(Resource."No.");
            until Resource.Next() = 0;
        if Resources.Count() = 0 then
            exit(MissingResource(Argument, 'resourceGroup'));
        exit(true);
    end;

    local procedure AddResource(var Argument: Record "Message Argument ori"; Token: JsonToken; ParameterName: Text; var Seen: List of [Code[20]]; var Resources: JsonArray): Boolean
    var
        Resource: Record Resource;
    begin
        if not IsString(Token) then
            exit(WrongType(Argument, ParameterName));
        if (Token.AsValue().AsText() = '') or (StrLen(Token.AsValue().AsText()) > MaxStrLen(Resource."No.")) then
            exit(WrongType(Argument, ParameterName));
        Resource.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Resource.Get(Token.AsValue().AsText()) then
            exit(MissingResource(Argument, ParameterName));
        if (not Resource."Use Time Sheet") or Resource.Blocked then
            exit(MissingResource(Argument, ParameterName));
        if not Seen.Contains(Resource."No.") then begin
            Seen.Add(Resource."No.");
            Resources.Add(Resource."No.");
        end;
        exit(true);
    end;

    local procedure MissingResource(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    begin
        exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, ResourceLbl, ParameterName, ResourceNextLbl));
    end;

    local procedure WrongType(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    begin
        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, TypeLbl, ParameterName, TypeNextLbl));
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; ParameterName: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, MessageText, ParameterName, '', '', NextStep);
        exit(false);
    end;

    local procedure IsString(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        exit(CopyStr(Raw, 1, 1) = '"');
    end;

    local procedure IsNumber(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Raw);
        exit(CopyStr(Raw, 1, 1) in ['-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    end;

    local procedure IsBoolean(Token: JsonToken): Boolean
    var
        Raw: Text;
    begin
        Token.WriteTo(Raw);
        exit(Raw in ['true', 'false']);
    end;

    var
        WeekdaysLbl: Label 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday', Comment = 'is-IS=mánudagur,þriðjudagur,miðvikudagur,fimmtudagur,föstudagur,laugardagur,sunnudagur';
}
