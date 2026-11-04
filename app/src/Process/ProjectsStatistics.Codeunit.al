namespace Origo.Bifrost.Projects;
using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
/// <summary>Reads native project statistics using the same calculation engine as the BC statistics pages.</summary>
codeunit 70009226 "Projects Statistics ori"
{
    Access = Internal;
    /// <summary>Returns totals and, for budget versus actual, individual posting task results in LCY.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Task: Record "Job Task";
        Calculate: Codeunit "Job Calculate Statistics";
        Request: JsonObject;
        Response: JsonObject;
        Tasks: JsonArray;
        TaskResult: JsonObject;
        TaskToken: JsonToken;
        MissingTaskErr: Label 'The requested posting task does not exist in this project.', Comment = 'is-IS=Umbeðinn bókunarverkhluti er ekki til í þessu verkefni.';
    begin
        Request := Argument.GetRequestJson();
        Project.Get(CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(Project."No.")));
        Calculate.JobCalculateCommonFilters(Project);
        Calculate.CalculateAmounts();
        Response.Add('status', 'Success');
        Response.Add('projectNo', Project."No.");
        Response.Add('currency', 'LCY');
        Response.Add('statistics', ReadAmounts(Calculate));
        if Argument.Type = "Message Type ori"::"Projects.BudgetVsActual.Get" then begin
            Task.SetRange("Job No.", Project."No.");
            Task.SetRange("Job Task Type", Task."Job Task Type"::Posting);
            if Request.Get('taskNo', TaskToken) then begin
                Task.SetRange("Job Task No.", CopyStr(TaskToken.AsValue().AsText(), 1, MaxStrLen(Task."Job Task No.")));
                if Task.IsEmpty() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingTaskErr, 'taskNo', TaskToken.AsValue().AsText(), '', '');
                    exit;
                end;
            end;
            if Task.FindSet() then
                repeat
                    Clear(Calculate);
                    Calculate.JTCalculateCommonFilters(Task, Project, true);
                    Calculate.CalculateAmounts();
                    Clear(TaskResult);
                    TaskResult.Add('taskNo', Task."Job Task No.");
                    TaskResult.Add('statistics', ReadAmounts(Calculate));
                    Tasks.Add(TaskResult);
                until Task.Next() = 0;
            Response.Add('tasks', Tasks);
        end;
        Argument.SetResponseJson(Response);
    end;

    local procedure ReadAmounts(var Calculate: Codeunit "Job Calculate Statistics") Result: JsonObject
    var
        Costs: array[16] of Decimal;
        Prices: array[16] of Decimal;
        Groups: List of [Text];
        Types: List of [Text];
        Amounts: JsonObject;
        Row: JsonObject;
        GroupIndex: Integer;
        TypeIndex: Integer;
        Index: Integer;
    begin
        Calculate.GetLCYCostAmounts(Costs);
        Calculate.GetLCYPriceAmounts(Prices);
        Groups.Add('budget');
        Groups.Add('actual');
        Groups.Add('billable');
        Groups.Add('invoiced');
        Types.Add('resource');
        Types.Add('item');
        Types.Add('glAccount');
        Types.Add('total');
        for GroupIndex := 1 to 4 do begin
            Clear(Row);
            for TypeIndex := 1 to 4 do begin
                Index := (GroupIndex - 1) * 4 + TypeIndex;
                Clear(Amounts);
                Amounts.Add('cost', Costs[Index]);
                Amounts.Add('price', Prices[Index]);
                Row.Add(Types.Get(TypeIndex), Amounts);
            end;
            Result.Add(Groups.Get(GroupIndex), Row);
        end;
    end;
}
