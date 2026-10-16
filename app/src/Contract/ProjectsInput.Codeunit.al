namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Validates the entire request tree before any native project write.</summary>
codeunit 10078497 "Projects Input ori"
{
    Access = Internal;
    /// <summary>Collects malformed and missing parameters, including every nested line.</summary>
    procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; Schema: JsonArray; Path: Text): Boolean
    var
        SchemaToken: JsonToken;
        Parameter: JsonObject;
        Value: JsonToken;
        Metadata: JsonToken;
        Children: JsonArray;
        Child: JsonToken;
        Name: Text;
        TypeName: Text;
        ParameterPath: Text;
        Required: Boolean;
        Index: Integer;
    begin
        foreach SchemaToken in Schema do begin
            Parameter := SchemaToken.AsObject();
            Parameter.Get('name', Metadata);
            Name := Metadata.AsValue().AsText();
            ParameterPath := Path + Name;
            Parameter.Get('type', Metadata);
            TypeName := Metadata.AsValue().AsText();
            Parameter.Get('required', Metadata);
            Required := Metadata.AsValue().AsBoolean();
            if not Request.Get(Name, Value) then begin
                if Required then
                    AddMissing(Argument, ParameterPath);
            end else
                if TypeName = 'array' then begin
                    if not Value.IsArray() then
                        AddBad(Argument, ParameterPath)
                    else begin
                        Parameter.Get('children', Metadata);
                        Children := Metadata.AsArray();
                        Index := 0;
                        foreach Child in Value.AsArray() do begin
                            if not Child.IsObject() then
                                AddBad(Argument, ParameterPath + '[' + Format(Index, 0, 9) + ']')
                            else
                                ValidateRequest(Argument, Child.AsObject(), Children, ParameterPath + '[' + Format(Index, 0, 9) + '].');
                            Index += 1;
                        end;
                    end;
                end else
                    ValidateScalar(Argument, Value, Parameter, ParameterPath, TypeName, Required);
        end;
        exit(not Argument.HasCollectedErrors());
    end;

    local procedure ValidateScalar(var Argument: Record "Message Argument ori"; Token: JsonToken; Parameter: JsonObject; Path: Text; TypeName: Text; Required: Boolean)
    var
        Metadata: JsonToken;
        Allowed: JsonToken;
        Raw: Text;
        TextValue: Text;
        DateValue: Date;
        NumberValue: Decimal;
        MatchFound: Boolean;
    begin
        if not Token.IsValue() then begin
            AddBad(Argument, Path);
            exit;
        end;
        if Token.AsValue().IsNull() then begin
            AddBad(Argument, Path);
            exit;
        end;
        Token.WriteTo(Raw);
        case TypeName of
            'string', 'date':
                begin
                    if not Raw.StartsWith('"') then begin
                        AddBad(Argument, Path);
                        exit;
                    end;
                    TextValue := Token.AsValue().AsText();
                    if Required and (TextValue.Trim() = '') then begin
                        AddMissing(Argument, Path);
                        exit;
                    end;
                    if Parameter.Get('maxLength', Metadata) then
                        if StrLen(TextValue) > Metadata.AsValue().AsInteger() then
                            AddBad(Argument, Path);
                    if TypeName = 'date' then
                        if (StrLen(TextValue) <> 10) or not Evaluate(DateValue, TextValue, 9) then
                            AddBad(Argument, Path);
                    if Parameter.Get('allowed', Metadata) then begin
                        foreach Allowed in Metadata.AsArray() do
                            if Allowed.AsValue().AsText() = TextValue then
                                MatchFound := true;
                        if not MatchFound then
                            AddBad(Argument, Path);
                    end;
                end;
            'boolean':
                if not (Raw in ['true', 'false']) then
                    AddBad(Argument, Path);
            'integer', 'number':
                begin
                    if Raw.StartsWith('"') or not Evaluate(NumberValue, Raw, 9) then begin
                        AddBad(Argument, Path);
                        exit;
                    end;
                    if TypeName = 'integer' then
                        if (NumberValue <> Round(NumberValue, 1)) or (NumberValue < 0) or (NumberValue > 2147483647) then
                            AddBad(Argument, Path);
                    if Path.EndsWith('lineNo') then
                        if NumberValue <= 0 then
                            AddBad(Argument, Path);
                end;
        end;
    end;

    local procedure AddMissing(var Argument: Record "Message Argument ori"; Path: Text)
    var
        MissingErr: Label 'A required Projects parameter is missing or empty.', Comment = 'is-IS=Nauðsynlegt viðfang verkefnis vantar eða er tómt.';
    begin
        Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingErr, Path, '', '', '');
    end;

    local procedure AddBad(var Argument: Record "Message Argument ori"; Path: Text)
    var
        BadErr: Label 'A Projects parameter does not match its declared type, length or allowed values.', Comment = 'is-IS=Viðfang verkefnis passar ekki við skilgreinda gerð, lengd eða leyfileg gildi.';
    begin
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, BadErr, Path, '', '', '');
    end;
}
