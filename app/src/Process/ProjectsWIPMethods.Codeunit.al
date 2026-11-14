namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.WIP;
using Origo.Bifrost;

/// <summary>Validates WIP method contracts and applies native changes inside a rollback boundary.</summary>
codeunit 70009242 "Projects WIP Methods ori"
{
    Access = Internal;

    /// <summary>Checks every native table permission and adds localized recovery guidance to gate refusals.</summary>
    procedure AssertEnabled(var Argument: Record "Message Argument ori"; Writing: Boolean): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
        Response: JsonObject;
        Allowed: Boolean;
        NextLbl: Label 'Enable Projects in Projects Setup and ask an administrator for the native WIP method and WIP entry table permissions.', Comment = 'is-IS=Virkjaðu verkefni í uppsetningu verkefna og biddu kerfisstjóra um heimildir á innbyggðum töflum VÍV-aðferða og VÍV-færslna.';
    begin
        Allowed := Gate.AssertEnabled(Argument, Database::"Job WIP Method", Writing);
        if Allowed and Writing then
            Allowed := Gate.AssertEnabled(Argument, Database::"Job WIP Entry", false);
        if Allowed and Writing then
            Allowed := Gate.AssertEnabled(Argument, Database::"Job WIP G/L Entry", false);
        if Allowed then
            exit(true);
        Response := Argument.GetResponseJson();
        if not Response.Contains('nextStep') then begin
            Response.Add('nextStep', NextLbl);
            Argument.SetResponseJson(Response);
        end;
        exit(false);
    end;

    /// <summary>Declares the English request schema, using stable native enum names at every locale.</summary>
    procedure Parameters(Writing: Boolean) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Costs: Enum "Job WIP Recognized Costs Type";
        Sales: Enum "Job WIP Recognized Sales Type";
        Entry: JsonObject;
    begin
        Entry := Contract.Parameter('code', 'string', Writing, 'Exact method code. Omit on Get to list all methods. Required on Set.');
        Entry.Add('maxLength', 20);
        Result.Add(Entry);
        if not Writing then
            exit;
        Entry := Contract.Parameter('description', 'string', false, 'Description; omitted on update preserves the existing value.');
        Entry.Add('maxLength', 100);
        Result.Add(Entry);
        AddEnumParameter(Result, 'recognizedCosts', Costs.Names());
        AddEnumParameter(Result, 'recognizedSales', Sales.Names());
        Result.Add(Contract.Parameter('wipCost', 'boolean', false, 'Native WIP cost flag; false requires Usage (Total Cost).'));
        Result.Add(Contract.Parameter('wipSales', 'boolean', false, 'Native WIP sales flag; false requires Contract (Invoiced Price).'));
        Result.Add(Contract.Parameter('valid', 'boolean', false, 'Whether the custom method is available for assignment to projects.'));
    end;

    local procedure AddEnumParameter(var Schema: JsonArray; Name: Text; Names: List of [Text])
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Entry: JsonObject;
        Allowed: JsonArray;
        Value: Text;
    begin
        foreach Value in Names do
            Allowed.Add(Value);
        Entry := Contract.Parameter(Name, 'string', false, 'Exact native English enum name, independent of session language.');
        Entry.Add('allowed', Allowed);
        Schema.Add(Entry);
    end;

    /// <summary>Lists stable refusal codes and their recovery instructions in English contract chapters.</summary>
    procedure Errors() Result: JsonArray
    var
        Entry: JsonObject;
        CodeName: Text;
        CodeNames: Text;
    begin
        CodeNames := 'MissingParameter,InvalidParameterFormat,RecordNotFound,PreconditionFailed,BusinessCentralError,PermissionDenied,InvalidParameter';
        foreach CodeName in CodeNames.Split(',') do begin
            Clear(Entry);
            Entry.Add('code', CodeName);
            Entry.Add('description', 'Invalid input, missing method, protected method, native validation, permission or company setup refusal.');
            Entry.Add('nextStep', 'Correct the request, enable Projects or request native table permissions. For protected methods, create a new custom method code.');
            Result.Add(Entry);
        end;
    end;

    /// <summary>Rejects malformed input before opening the isolated native transaction.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        Writing: Boolean;
        NativeErr: Text;
        Response: JsonObject;
        NativeSummaryLbl: Label 'Native validation rejected the WIP method settings.', Comment = 'is-IS=Innbyggð sannprófun hafnaði stillingum VÍV-aðferðarinnar.';
        NativeNextLbl: Label 'Review the method settings and nativeError details, then retry with valid values.', Comment = 'is-IS=Farðu yfir stillingar aðferðarinnar og nánari upplýsingar í nativeError og reyndu aftur með gildum gildum.';
    begin
        Writing := Argument.Type = "Message Type ori"::"Projects.WIPMethod.Set";
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            RefuseInput(Argument, 'data', false);
            exit;
        end;
        if not ValidateRequest(Argument, Request, Writing) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. WIP Method Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. WIP Method Process ori", Argument) then begin
            NativeErr := GetLastErrorText();
            ClearLastError();
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, NativeSummaryLbl, '', '', '', NativeNextLbl);
            Response := Argument.GetResponseJson();
            Response.Add('nativeError', NativeErr);
            Argument.SetResponseJson(Response);
        end;
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; Writing: Boolean): Boolean
    var
        Schema: JsonArray;
        ParameterToken: JsonToken;
        Parameter: JsonObject;
        Value: JsonToken;
        Allowed: JsonToken;
        Name: Text;
        Raw: Text;
        RequestKey: Text;
        Known: Boolean;
        Matches: Boolean;
    begin
        Schema := Parameters(Writing);
        foreach RequestKey in Request.Keys() do begin
            Known := false;
            foreach ParameterToken in Schema do
                if ParameterToken.AsObject().GetText('name') = RequestKey then
                    Known := true;
            if not Known then begin
                RefuseInput(Argument, RequestKey, false);
                exit(false);
            end;
        end;
        foreach ParameterToken in Schema do begin
            Parameter := ParameterToken.AsObject();
            Name := Parameter.GetText('name');
            if not Request.Get(Name, Value) then begin
                if Parameter.GetBoolean('required') then begin
                    RefuseInput(Argument, Name, true);
                    exit(false);
                end;
            end else begin
                if not Value.IsValue() then begin
                    RefuseInput(Argument, Name, false);
                    exit(false);
                end;
                if Value.AsValue().IsNull() then begin
                    RefuseInput(Argument, Name, false);
                    exit(false);
                end;
                Value.WriteTo(Raw);
                if Parameter.GetText('type') = 'boolean' then begin
                    if not (Raw in ['true', 'false']) then begin
                        RefuseInput(Argument, Name, false);
                        exit(false);
                    end;
                end else begin
                    if not Raw.StartsWith('"') then begin
                        RefuseInput(Argument, Name, false);
                        exit(false);
                    end;
                    if (Name = 'code') and (Value.AsValue().AsText().Trim() = '') then begin
                        RefuseInput(Argument, Name, true);
                        exit(false);
                    end;
                    if Parameter.Contains('maxLength') then
                        if StrLen(Value.AsValue().AsText()) > Parameter.GetInteger('maxLength') then begin
                            RefuseInput(Argument, Name, false);
                            exit(false);
                        end;
                    if Parameter.Contains('allowed') then begin
                        Matches := false;
                        foreach Allowed in Parameter.GetArray('allowed') do
                            if Allowed.AsValue().AsText() = Value.AsValue().AsText() then
                                Matches := true;
                        if not Matches then begin
                            RefuseInput(Argument, Name, false);
                            exit(false);
                        end;
                    end;
                end;
            end;
        end;
        exit(true);
    end;

    local procedure RefuseInput(var Argument: Record "Message Argument ori"; Parameter: Text; Missing: Boolean)
    var
        InvalidLbl: Label 'A WIP method parameter has an invalid type, length or value, or is not supported.', Comment = 'is-IS=Viðfang VÍV-aðferðar er af ógildri gerð eða lengd, hefur ógilt gildi eða er ekki stutt.';
        MissingLbl: Label 'The WIP method code is required and must not be empty.', Comment = 'is-IS=Kóði VÍV-aðferðar er nauðsynlegur og má ekki vera tómur.';
        NextLbl: Label 'Send a JSON object with a nonempty code of at most 20 characters for Set. Use the documented fields, boolean flags and exact English enum names.', Comment = 'is-IS=Sendu JSON-hlut með kóða sem er ekki tómur og er að hámarki 20 stafir fyrir Set. Notaðu skjalfesta reiti, rökgildisflögg og nákvæm ensk heiti upptalningargilda.';
    begin
        if Missing then
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLbl, Parameter, '', '', NextLbl)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, Parameter, '', '', NextLbl);
    end;

    /// <summary>Reads methods or writes one custom method, retaining all native validation and triggers.</summary>
    procedure RunNative(var Argument: Record "Message Argument ori")
    var
        Method: Record "Job WIP Method";
        Calculated: Record "Job WIP Entry";
        Posted: Record "Job WIP G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        Methods: JsonArray;
        CodeValue: Code[20];
        Writing: Boolean;
        Exists: Boolean;
        MissingLbl: Label 'The requested WIP method does not exist.', Comment = 'is-IS=Umbeðin VÍV-aðferð er ekki til.';
        MissingNextLbl: Label 'List WIP methods without a code, or create a custom method with Set.', Comment = 'is-IS=Sýndu VÍV-aðferðir án kóða eða stofnaðu sérsniðna aðferð með Set.';
        ProtectedLbl: Label 'System-defined WIP methods cannot be changed.', Comment = 'is-IS=Ekki er hægt að breyta kerfisskilgreindum VÍV-aðferðum.';
        UsedLbl: Label 'WIP methods referenced by calculated or posted WIP cannot be changed.', Comment = 'is-IS=Ekki er hægt að breyta VÍV-aðferðum sem reiknaðar eða bókaðar VÍV-færslur vísa í.';
        NewNextLbl: Label 'Create a new custom WIP method with a different code; leave the protected method unchanged.', Comment = 'is-IS=Stofnaðu nýja sérsniðna VÍV-aðferð með öðrum kóða; láttu vernduðu aðferðina vera óbreytta.';
    begin
        Request := Argument.GetRequestJson();
        Writing := Argument.Type = "Message Type ori"::"Projects.WIPMethod.Set";
        if Request.Contains('code') then
            CodeValue := CopyStr(Request.GetText('code'), 1, MaxStrLen(CodeValue));
        if Writing then begin
            Method.LockTable();
            Exists := Method.Get(CodeValue);
            if Exists and Method."System Defined" then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ProtectedLbl, 'code', '', '', NewNextLbl);
                exit;
            end;
            Calculated.ReadIsolation := IsolationLevel::ReadCommitted;
            Posted.ReadIsolation := IsolationLevel::ReadCommitted;
            Calculated.SetRange("WIP Method Used", CodeValue);
            Posted.SetRange("WIP Method Used", CodeValue);
            if not Calculated.IsEmpty() or not Posted.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, UsedLbl, 'code', '', '', NewNextLbl);
                exit;
            end;
            if not Exists then begin
                Method.Init();
                Method.Validate(Code, CodeValue);
            end;
            ApplyFields(Method, Request);
            if Exists then
                Method.Modify(true)
            else
                Method.Insert(true);
            Methods.Add(MethodJson(Method));
        end else begin
            Method.ReadIsolation := IsolationLevel::ReadCommitted;
            if CodeValue <> '' then begin
                Method.SetRange(Code, CodeValue);
                if Method.IsEmpty() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingLbl, 'code', '', '', MissingNextLbl);
                    exit;
                end;
            end;
            Method.SetLoadFields(Code, Description, "Recognized Costs", "Recognized Sales", "WIP Cost", "WIP Sales", Valid, "System Defined");
            if Method.FindSet() then
                repeat
                    Methods.Add(MethodJson(Method));
                until Method.Next() = 0;
        end;
        Response.Add('status', 'Success');
        Response.Add('methods', Methods);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ApplyFields(var Method: Record "Job WIP Method"; Request: JsonObject)
    var
        Costs: Enum "Job WIP Recognized Costs Type";
        Sales: Enum "Job WIP Recognized Sales Type";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        if Request.Contains('description') then
            Method.Validate(Description, CopyStr(Request.GetText('description'), 1, MaxStrLen(Method.Description)));
        if Request.Contains('recognizedCosts') then begin
            Names := Costs.Names();
            Ordinals := Costs.Ordinals();
            Method.Validate("Recognized Costs", "Job WIP Recognized Costs Type".FromInteger(Ordinals.Get(Names.IndexOf(Request.GetText('recognizedCosts')))));
        end;
        if Request.Contains('recognizedSales') then begin
            Names := Sales.Names();
            Ordinals := Sales.Ordinals();
            Method.Validate("Recognized Sales", "Job WIP Recognized Sales Type".FromInteger(Ordinals.Get(Names.IndexOf(Request.GetText('recognizedSales')))));
        end;
        if Request.Contains('wipCost') then
            Method.Validate("WIP Cost", Request.GetBoolean('wipCost'));
        if Request.Contains('wipSales') then
            Method.Validate("WIP Sales", Request.GetBoolean('wipSales'));
        if Request.Contains('valid') then
            Method.Validate(Valid, Request.GetBoolean('valid'));
    end;

    local procedure MethodJson(Method: Record "Job WIP Method") Result: JsonObject
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Result.Add('code', Method.Code);
        Result.Add('description', Method.Description);
        Names := Method."Recognized Costs".Names();
        Ordinals := Method."Recognized Costs".Ordinals();
        Result.Add('recognizedCosts', Names.Get(Ordinals.IndexOf(Method."Recognized Costs".AsInteger())));
        Names := Method."Recognized Sales".Names();
        Ordinals := Method."Recognized Sales".Ordinals();
        Result.Add('recognizedSales', Names.Get(Ordinals.IndexOf(Method."Recognized Sales".AsInteger())));
        Result.Add('wipCost', Method."WIP Cost");
        Result.Add('wipSales', Method."WIP Sales");
        Result.Add('valid', Method.Valid);
        Result.Add('systemDefined', Method."System Defined");
    end;
}
