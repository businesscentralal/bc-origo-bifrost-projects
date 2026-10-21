namespace Origo.Bifrost.Projects;
using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Posting;
/// <summary>Reads usage links and applies owned project usage through native BC link/transfer codeunits.</summary>
codeunit 70009229 "Projects Usage ori"
{
    Access = Internal;
    /// <summary>Processes one exact project/task ledger usage link or reads its native state.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Task: Record "Job Task";
        Ledger: Record "Job Ledger Entry";
        Planning: Record "Job Planning Line";
        Link: Record "Job Usage Link";
        Journal: Record "Job Journal Line";
        Apply: Codeunit "Job Link Usage";
        Transfer: Codeunit "Job Post-Line";
        Request: JsonObject;
        Response: JsonObject;
        Links: JsonArray;
        Lines: JsonArray;
        Item: JsonObject;
        Token: JsonToken;
        ProjectNo: Code[20];
        TaskNo: Code[20];
        CreatePlanning: Boolean;
        InvalidErr: Label 'The usage entry and planning line must belong to the requested project/task and match type, number, unit, location, variant and work type.', Comment = 'is-IS=Notkunarfærsla og áætlunarlína verða að tilheyra umbeðnu verkefni og verkhluta og passa í gerð, númeri, einingu, staðsetningu, afbrigði og verkgerð.';
        AlreadyLinkedErr: Label 'This usage entry is already linked. Read its existing links instead of applying it again.', Comment = 'is-IS=Þessi notkunarfærsla er þegar tengd. Lestu tengingarnar í stað þess að tengja hana aftur.';
        MissingLineErr: Label 'Send a positive lineNo or set createPlanningLine to true.', Comment = 'is-IS=Sendu jákvætt lineNo eða stilltu createPlanningLine á true.';
    begin
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        TaskNo := CopyStr(Request.GetText('taskNo'), 1, MaxStrLen(TaskNo));
        Project.Get(ProjectNo);
        Task.Get(ProjectNo, TaskNo);
        if Argument.Type = "Message Type ori"::"Projects.Usage.Link" then begin
            Ledger.LockTable();
            Link.LockTable();
            Planning.LockTable();
            Ledger.Get(Request.GetInteger('entryNo'));
            if (Ledger."Job No." <> ProjectNo) or (Ledger."Job Task No." <> TaskNo) then
                Error(ErrorInfo.Create(InvalidErr));
            Ledger.TestField("Entry Type", Ledger."Entry Type"::Usage);
            Ledger.TestField("Quantity (Base)");
            Project.TestField("Apply Usage Link", true);
            Project.TestBlocked();
            Link.SetRange("Entry No.", Ledger."Entry No.");
            if not Link.IsEmpty() then
                Error(ErrorInfo.Create(AlreadyLinkedErr));
            if Request.Get('createPlanningLine', Token) then
                CreatePlanning := Token.AsValue().AsBoolean();
            if CreatePlanning then begin
                Ledger."Line Type" := Ledger."Line Type"::Budget;
                if Request.Get('lineType', Token) then
                    case Token.AsValue().AsText() of
                        'Billable':
                            Ledger."Line Type" := Ledger."Line Type"::Billable;
                        'Both Budget and Billable':
                            Ledger."Line Type" := Ledger."Line Type"::"Both Budget and Billable";
                    end;
                Transfer.InsertPlLineFromLedgEntry(Ledger);
            end else begin
                if not Request.Get('lineNo', Token) then
                    Error(ErrorInfo.Create(MissingLineErr));
                Planning.Get(ProjectNo, TaskNo, Token.AsValue().AsInteger());
                if (Planning.Type <> Ledger.Type) or (Planning."No." <> Ledger."No.") or
                   (Planning."Unit of Measure Code" <> Ledger."Unit of Measure Code") or
                   (Planning."Location Code" <> Ledger."Location Code") or
                   (Planning."Variant Code" <> Ledger."Variant Code") or
                   (Planning."Work Type Code" <> Ledger."Work Type Code")
                then
                    Error(ErrorInfo.Create(InvalidErr));
                Journal."Job No." := Ledger."Job No.";
                Journal."Job Task No." := Ledger."Job Task No.";
                Journal.Type := Ledger.Type;
                Journal."No." := Ledger."No.";
                Journal.Quantity := Ledger.Quantity;
                Journal."Unit of Measure Code" := Ledger."Unit of Measure Code";
                Journal."Qty. per Unit of Measure" := Ledger."Qty. per Unit of Measure";
                Journal."Posting Date" := Ledger."Posting Date";
                Journal."Job Planning Line No." := Planning."Line No.";
                Journal."Quantity (Base)" := Ledger."Quantity (Base)";
                Journal."Remaining Qty. (Base)" := Planning."Remaining Qty. (Base)" - Ledger."Quantity (Base)";
                Apply.ApplyUsage(Ledger, Journal);
            end;
        end;
        Link.Reset();
        Link.SetRange("Job No.", ProjectNo);
        Link.SetRange("Job Task No.", TaskNo);
        if Link.FindSet() then
            repeat
                Clear(Item);
                Item.Add('entryNo', Link."Entry No.");
                Item.Add('lineNo', Link."Line No.");
                Links.Add(Item);
            until Link.Next() = 0;
        Planning.Reset();
        Planning.SetRange("Job No.", ProjectNo);
        Planning.SetRange("Job Task No.", TaskNo);
        if Planning.FindSet() then
            repeat
                Clear(Item);
                Item.Add('lineNo', Planning."Line No.");
                Item.Add('quantity', Planning.Quantity);
                Item.Add('remainingQuantity', Planning."Remaining Qty.");
                Item.Add('usageLink', Planning."Usage Link");
                Lines.Add(Item);
            until Planning.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        Response.Add('taskNo', TaskNo);
        Response.Add('links', Links);
        Response.Add('planningLines', Lines);
        Argument.SetResponseJson(Response);
    end;
}
