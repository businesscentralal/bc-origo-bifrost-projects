namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Declares the native Projects write contract and its nested parameter schemas.</summary>
codeunit 10078489 "Projects Contract ori"
{
    Access = Internal;
    /// <summary>Declares the supported data keys for a Projects write operation.</summary>
    procedure Parameters(Kind: Text; Operation: Text; Nested: Boolean) Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Entry: JsonObject;
    begin
        if Nested then
            Result.Add(DecorateParameter(ContractMgt.Parameter('operation', 'string', false, 'Create by default; Update explicitly targets an existing nested record.'), 'string', 0, 'Create,Update'));
        if not Nested then
            Result.Add(DecorateParameter(ContractMgt.Parameter('projectNo', 'string', true, ''), 'string', 20, ''));
        case Kind of
            'Project':
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, ''), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('billToCustomerNo', 'string', false, ''), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('personResponsible', 'string', false, ''), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('startingDate', 'date', false, ''), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('endingDate', 'date', false, ''), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('currencyCode', 'string', false, ''), 'string', 10, ''));
                        Entry := ContractMgt.Parameter('tasks', 'array', false, 'New nested records inheriting the parent keys.');
                        Entry.Add('children', Parameters('Task', 'Create', true));
                        Result.Add(Entry);
                    end;
            'Task':
                begin
                    Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', true, ''), 'string', 20, ''));
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('taskType', 'string', false, ''), 'string', 0, 'Posting,Heading,Total,Begin-Total,End-Total'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, ''), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('totaling', 'string', false, ''), 'string', 250, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('indentation', 'integer', false, ''), 'integer', 0, ''));
                        Entry := ContractMgt.Parameter('planningLines', 'array', false, 'New nested records inheriting the parent keys.');
                        Entry.Add('children', Parameters('PlanningLine', 'Create', true));
                        Result.Add(Entry);
                    end;
                end;
            'PlanningLine':
                begin
                    Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', true, ''), 'string', 20, ''));
                    Result.Add(DecorateParameter(ContractMgt.Parameter('lineNo', 'integer', true, ''), 'integer', 0, ''));
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('lineType', 'string', false, ''), 'string', 0, 'Budget,Billable,Both Budget and Billable'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('type', 'string', false, ''), 'string', 0, 'Resource,Item,G/L Account,Text'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('no', 'string', false, ''), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, ''), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('planningDate', 'date', false, ''), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitOfMeasureCode', 'string', false, ''), 'string', 10, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('quantity', 'number', false, ''), 'number', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitCost', 'number', false, ''), 'number', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitPrice', 'number', false, ''), 'number', 0, ''));
                    end;
                end;
        end;
    end;

    local procedure DecorateParameter(Entry: JsonObject; TypeName: Text; MaxLength: Integer; AllowedText: Text): JsonObject
    var
        Allowed: JsonArray;
        AllowedValue: Text;
    begin
        if MaxLength > 0 then
            Entry.Add('maxLength', MaxLength);
        if TypeName = 'date' then
            Entry.Add('format', 'YYYY-MM-DD');
        if AllowedText <> '' then begin
            foreach AllowedValue in AllowedText.Split(',') do
                Allowed.Add(AllowedValue);
            Entry.Add('allowed', Allowed);
        end;
        exit(Entry);
    end;

    /// <summary>Documents stable contract and Business Central errors.</summary>
    procedure Errors() Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is missing or empty.', 'Supply the key named by parameter.'));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong JSON type, length, date or enum value.', 'Use the declared parameter schema.'));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several input values are invalid.', 'Correct every entry in errors and retry.'));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the native table permission.', 'Ask an administrator for the required Business Central role.'));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refuses validation or the record operation.', 'Correct the reported native validation error; the operation is rolled back.'));
    end;
}
