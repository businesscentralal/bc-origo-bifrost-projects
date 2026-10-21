namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

/// <summary>Declares the native Projects write contract and its nested parameter schemas.</summary>
codeunit 70009204 "Projects Contract ori"
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
            Result.Add(DecorateParameter(ContractMgt.Parameter('projectNo', 'string', true, 'Exact native project number.'), 'string', 20, ''));
        if Kind = 'Usage' then begin
            Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', true, 'Exact posting task number.'), 'string', 20, ''));
            if Operation = 'Link' then begin
                Result.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'Exact posted usage entry; already linked entries are rejected.'));
                Result.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Existing positive planning line number unless creating from usage.'));
                Result.Add(ContractMgt.Parameter('createPlanningLine', 'boolean', false, 'Create through native transfer instead of linking an existing line. Default false.'));
                Result.Add(DecorateParameter(ContractMgt.Parameter('lineType', 'string', false, 'Used only when creating from usage; Budget by default.'), 'string', 0, 'Budget,Billable,Both Budget and Billable'));
            end;
            exit;
        end;
        if Kind in ['Statistics', 'BudgetVsActual'] then begin
            if Kind = 'BudgetVsActual' then
                Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', false, 'Optional exact posting task number for the task breakdown.'), 'string', 20, ''));
            exit;
        end;
        if Kind = 'WIP' then begin
            if Operation <> 'Get' then begin
                Result.Add(ContractMgt.Parameter('postingDate', 'date', true, 'Explicit ISO posting date YYYY-MM-DD.'));
                Result.Add(DecorateParameter(ContractMgt.Parameter('documentNo', 'string', true, 'Document number passed to the native WIP engine. New WIP G/L entries retain the calculated WIP document number.'), 'string', 20, ''));
            end;
            exit;
        end;
        if Operation = 'Copy' then begin
            Result.Add(DecorateParameter(ContractMgt.Parameter('targetProjectNo', 'string', true, 'New project number; must not exist.'), 'string', 20, ''));
            Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, 'New description; omitted keeps the source description.'), 'string', 100, ''));
            Result.Add(DecorateParameter(ContractMgt.Parameter('billToCustomerNo', 'string', false, 'Optional replacement bill-to customer.'), 'string', 20, ''));
            Result.Add(DecorateParameter(ContractMgt.Parameter('sellToCustomerNo', 'string', false, 'Optional replacement sell-to customer.'), 'string', 20, ''));
            Result.Add(DecorateParameter(ContractMgt.Parameter('fromTaskNo', 'string', false, 'First included task number.'), 'string', 20, ''));
            Result.Add(DecorateParameter(ContractMgt.Parameter('toTaskNo', 'string', false, 'Last included task number.'), 'string', 20, ''));
            Result.Add(ContractMgt.Parameter('copyQuantity', 'boolean', false, 'Copy quantities; default true.'));
            Result.Add(ContractMgt.Parameter('copyPrices', 'boolean', false, 'Copy prices; default true.'));
            Result.Add(ContractMgt.Parameter('copyDimensions', 'boolean', false, 'Copy dimensions; default true.'));
            Result.Add(DecorateParameter(ContractMgt.Parameter('planningLineType', 'string', false, 'Both by default, or only Budget or Billable planning lines.'), 'string', 0, 'Both,Budget,Billable'));
            exit;
        end;
        if Operation = 'SetStatus' then begin
            Result.Add(DecorateParameter(ContractMgt.Parameter('status', 'string', false, 'Native project status; send status or blocked.'), 'string', 0, 'Planning,Quote,Open,Completed'));
            Result.Add(DecorateParameter(ContractMgt.Parameter('blocked', 'string', false, 'None unblocks; Posting or All applies the native block.'), 'string', 0, 'None,Posting,All'));
            exit;
        end;
        case Kind of
            'Project':
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, 'Native description; omitted on update preserves the current value.'), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('billToCustomerNo', 'string', false, 'Native bill-to customer number.'), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('personResponsible', 'string', false, 'Native person responsible code.'), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('startingDate', 'date', false, 'Native starting date in ISO format YYYY-MM-DD.'), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('endingDate', 'date', false, 'Native ending date in ISO format YYYY-MM-DD.'), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('currencyCode', 'string', false, 'Native currency code; empty uses local currency.'), 'string', 10, ''));
                        Entry := ContractMgt.Parameter('tasks', 'array', false, 'New nested records inheriting the parent keys.');
                        Entry.Add('children', Parameters('Task', 'Create', true));
                        Result.Add(Entry);
                    end;
            'Task':
                begin
                    Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', true, 'Exact native task number within the project.'), 'string', 20, ''));
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('taskType', 'string', false, 'Native task type; Posting by default when creating a task.'), 'string', 0, 'Posting,Heading,Total,Begin-Total,End-Total'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, 'Native description; omitted on update preserves the current value.'), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('totaling', 'string', false, 'Native task-number totaling filter for a total task.'), 'string', 250, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('indentation', 'integer', false, 'Native task indentation level as a nonnegative integer.'), 'integer', 0, ''));
                        Entry := ContractMgt.Parameter('planningLines', 'array', false, 'New nested records inheriting the parent keys.');
                        Entry.Add('children', Parameters('PlanningLine', 'Create', true));
                        Result.Add(Entry);
                    end;
                end;
            'PlanningLine':
                begin
                    if not Nested then
                        Result.Add(DecorateParameter(ContractMgt.Parameter('taskNo', 'string', true, 'Exact native task number within the project.'), 'string', 20, ''));
                    Result.Add(DecorateParameter(ContractMgt.Parameter('lineNo', 'integer', true, 'Positive planning line number within the project and task.'), 'integer', 0, ''));
                    if Operation <> 'Delete' then begin
                        Result.Add(DecorateParameter(ContractMgt.Parameter('lineType', 'string', false, 'Budget, Billable or Both Budget and Billable; native default on create.'), 'string', 0, 'Budget,Billable,Both Budget and Billable'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('type', 'string', false, 'Native planning line type: Resource, Item, G/L Account or Text.'), 'string', 0, 'Resource,Item,G/L Account,Text'));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('no', 'string', false, 'Native resource, item or G/L account number for the selected type.'), 'string', 20, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('description', 'string', false, 'Native description; omitted on update preserves the current value.'), 'string', 100, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('planningDate', 'date', false, 'Native planning date in ISO format YYYY-MM-DD.'), 'date', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitOfMeasureCode', 'string', false, 'Native unit of measure code for the selected resource or item.'), 'string', 10, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('quantity', 'number', false, 'Native planning quantity; field validation recalculates dependent amounts.'), 'number', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitCost', 'number', false, 'Native unit cost; field validation recalculates dependent amounts.'), 'number', 0, ''));
                        Result.Add(DecorateParameter(ContractMgt.Parameter('unitPrice', 'number', false, 'Native unit price; field validation recalculates dependent amounts.'), 'number', 0, ''));
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
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The requested posting task does not exist in this project.', 'Supply an existing posting task number in taskNo.'));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refuses validation or the record operation.', 'Correct the reported native validation error; the operation is rolled back.'));
    end;
}
