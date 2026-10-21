namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Validates additive Projects contracts and reports actionable single errors.</summary>
codeunit 70009230 "Projects Followup Input ori"
{
    Access = Internal;

    var
        Text1Lbl: Label 'Remove the unknown parameter.', Comment = 'is-IS=Fjarlægðu óþekkta viðfangið.';
        Text2Lbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        Text3Lbl: Label 'Use the parameter type and length listed in the help.', Comment = 'is-IS=Notaðu gagnategund og lengd viðfangs sem tilgreind eru í hjálpinni.';

    /// <summary>Checks declared keys and scalar types before native processing.</summary>
    procedure Validate(var Argument: Record "Message Argument ori"; Request: JsonObject; Schema: JsonArray): Boolean
    var
        SchemaEntry: JsonToken;
        Metadata: JsonObject;
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
        NumberValue: Decimal;
        DateValue: Date;
        GuidValue: Guid;
        Found: Boolean;
    begin
        foreach ParameterName in Request.Keys() do begin
            Found := false;
            foreach SchemaEntry in Schema do
                if SchemaEntry.AsObject().GetText('name') = ParameterName then
                    Found := true;
            if not Found then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName, Text1Lbl));
        end;
        foreach SchemaEntry in Schema do begin
            Metadata := SchemaEntry.AsObject();
            ParameterName := Metadata.GetText('name');
            if not Request.Get(ParameterName, Token) then begin
                if Metadata.GetBoolean('required') then
                    exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName, Text2Lbl));
            end else
                if Metadata.GetText('type') = 'array' then
                    if not Token.IsArray() then
                        exit(BadFormat(Argument, ParameterName))
                    else
                        Found := true
                else begin
                    if not Token.IsValue() then
                        exit(BadFormat(Argument, ParameterName));
                    if Token.AsValue().IsNull() then
                        exit(BadFormat(Argument, ParameterName));
                    Token.WriteTo(Raw);
                    case Metadata.GetText('type') of
                        'string', 'date', 'guid':
                            begin
                                if not Raw.StartsWith('"') then
                                    exit(BadFormat(Argument, ParameterName));
                                if Metadata.GetBoolean('required') and (Token.AsValue().AsText().Trim() = '') then
                                    exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName, Text2Lbl));
                                if Metadata.GetText('type') = 'date' then
                                    if (StrLen(Token.AsValue().AsText()) <> 10) or not Evaluate(DateValue, Token.AsValue().AsText(), 9) then
                                        exit(BadFormat(Argument, ParameterName));
                                if Metadata.GetText('type') = 'guid' then
                                    if not Evaluate(GuidValue, Token.AsValue().AsText()) then
                                        exit(BadFormat(Argument, ParameterName));
                                if Metadata.Contains('maxLength') then
                                    if StrLen(Token.AsValue().AsText()) > Metadata.GetInteger('maxLength') then
                                        exit(BadFormat(Argument, ParameterName));
                            end;
                        'integer', 'number':
                            begin
                                if Raw.StartsWith('"') or not Evaluate(NumberValue, Raw, 9) then
                                    exit(BadFormat(Argument, ParameterName));
                                if Metadata.GetText('type') = 'integer' then
                                    if (NumberValue <> Round(NumberValue, 1)) or (NumberValue < 0) or (NumberValue > 2147483647) then
                                        exit(BadFormat(Argument, ParameterName));
                            end;
                    end;
                end;
        end;
        exit(true);
    end;

    /// <summary>Builds a documented parameter with an optional length bound.</summary>
    procedure Parameter(ParameterName: Text; ParameterType: Text; Required: Boolean; Description: Text; MaxLength: Integer) Result: JsonObject
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Result := Contract.Parameter(ParameterName, ParameterType, Required, Description);
        if MaxLength > 0 then
            Result.Add('maxLength', MaxLength);
        exit(Result);
    end;

    /// <summary>Returns optional text without silently truncating identifiers.</summary>
    procedure TextValue(Request: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        if Request.Get(ParameterName, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    /// <summary>Sets the stable error code, parameter and corrective next step.</summary>
    procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; NextStep: Text): Boolean
    var
        InvalidLbl: Label 'The Projects request cannot be processed. Check the named parameter.', Comment = 'is-IS=Ekki er hægt að vinna verkefnabeiðnina. Athugaðu tilgreint viðfang.';
    begin
        Argument.RespondWithError(ErrorCode, InvalidLbl, ParameterName, '', '', NextStep);
        exit(false);
    end;

    local procedure BadFormat(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    begin
        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, Text3Lbl));
    end;
}
