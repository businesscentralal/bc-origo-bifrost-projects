namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.WIP;

/// <summary>Executes native WIP operations and returns the actual calculated and posted entry state.</summary>
codeunit 70013520 "Projects WIP ori"
{
    Access = Internal;
    /// <summary>Runs inside the existing Projects process transaction, preserving native WIP and posting validation.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        WIP: Codeunit "Job Calculate WIP";
        PostingGate: Codeunit "Proj. Posting Gate ori";
        Request: JsonObject;
        Response: JsonObject;
        ProjectNo: Code[20];
        PostingDate: Date;
        DocumentNo: Code[20];
    begin
        if Argument.Type = "Message Type ori"::"Projects.WIP.Reverse" then begin
            Reverse(Argument);
            exit;
        end;
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        Project.Get(ProjectNo);
        if Argument.Type <> "Message Type ori"::"Projects.WIP.Get" then begin
            Evaluate(PostingDate, Request.GetText('postingDate'), 9);
            DocumentNo := CopyStr(Request.GetText('documentNo'), 1, MaxStrLen(DocumentNo));
            case Argument.Type of
                "Message Type ori"::"Projects.WIP.Calculate":
                    WIP.JobCalcWIP(Project, PostingDate, DocumentNo);
                "Message Type ori"::"Projects.WIP.Post":
                    begin
                        if not PostingGate.AssertCanPost(Argument) then
                            exit;
                        WIP.CalcGLWIP(ProjectNo, false, DocumentNo, PostingDate, true);
                    end;
            end;
        end;
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        Response.Add('entries', ReadWIPEntries(ProjectNo));
        Response.Add('glEntries', ReadGLEntries(ProjectNo));
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Declares reversal keys without changing the existing posting contract.</summary>
    procedure ReverseParameters() Result: JsonArray
    var
        Contract: Codeunit "Projects Contract ori";
        Input: Codeunit "Projects Followup Input ori";
    begin
        Result := Contract.Parameters('WIP', 'Reverse', false);
        Result.Add(Input.Parameter('expectedCount', 'integer', false, 'Number of posted WIP entries marked for reversal and not yet reversed. Omit to preview when confirmation is required.', 0));
    end;

    /// <summary>Validates reversal input and locks the native candidate set before counting it.</summary>
    procedure ValidateReverse(var Argument: Record "Message Argument ori"; var Count: Integer): Boolean
    var
        Project: Record Job;
        Entry: Record "Job WIP G/L Entry";
        Input: Codeunit "Projects Followup Input ori";
        Request: JsonObject;
        ProjectNo: Code[20];
        InvalidDataLbl: Label 'Send data as a JSON object.', Comment = 'is-IS=Sendu data sem JSON-hlut.';
        MissingLbl: Label 'The project does not exist.', Comment = 'is-IS=Verkefnið er ekki til.';
        NoEntriesLbl: Label 'There are no posted WIP entries eligible for reversal.', Comment = 'is-IS=Engar bókaðar færslur verka í vinnslu eru tiltækar til bakfærslu.';
        CompleteLbl: Label 'Completed project WIP cannot be reversed.', Comment = 'is-IS=Ekki er hægt að bakfæra lokin verk í vinnslu.';
        FindLbl: Label 'Check projectNo with Data.Records.Get.', Comment = 'is-IS=Athugaðu projectNo með Data.Records.Get.';
    begin
        Count := 0;
        if not TryReadRequest(Argument, Request) then begin
            ClearLastError();
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'data', InvalidDataLbl));
        end;
        if not Input.Validate(Argument, Request, ReverseParameters()) then
            exit(false);
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        if not Project.Get(ProjectNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingLbl, 'projectNo', ProjectNo, '', FindLbl);
            exit(false);
        end;
        Entry.SetRange("Job No.", ProjectNo);
        Entry.SetRange("Job Complete", true);
        if not Entry.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, CompleteLbl, 'projectNo', ProjectNo, '', 'Projects.WIP.Get');
            exit(false);
        end;
        Entry.SetRange("Job Complete");
        Entry.SetRange(Reverse, true);
        Entry.SetRange(Reversed, false);
        Count := Entry.Count();
        if Count = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoEntriesLbl, 'projectNo', ProjectNo, '', 'Projects.WIP.Get');
            exit(false);
        end;
        exit(true);
    end;

    [TryFunction]
    local procedure TryReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject)
    begin
        Request := Argument.GetRequestJson();
    end;

    local procedure Reverse(var Argument: Record "Message Argument ori")
    var
        Entry: Record "Job WIP G/L Entry";
        WIP: Codeunit "Job Calculate WIP";
        PostingGate: Codeunit "Proj. Posting Gate ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Request: JsonObject;
        Response: JsonObject;
        CurrentWIP: JsonObject;
        ReversedEntries: JsonArray;
        ProjectNo: Code[20];
        DocumentNo: Code[20];
        PostingDate: Date;
        Count: Integer;
        CountLbl: Label 'posted project WIP entries to reverse', Comment = 'is-IS=bókaðar færslur verka í vinnslu sem á að bakfæra';
        SummaryLbl: Label 'Reversed %1 posted WIP entries. Recalculate with Projects.WIP.Calculate before posting again.', Comment = '%1 = reversed entry count, is-IS=Bakfærði %1 bókaðar færslur verka í vinnslu. Endurreiknaðu með Projects.WIP.Calculate áður en þú bókar aftur.';
    begin
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        // Count and confirm under the same lock as the native write, inside its rollback boundary.
        Entry.LockTable();
        if not ValidateReverse(Argument, Count) then
            exit;
        if not ConfirmGate.Confirm(Argument, Count, CountLbl) then
            exit;
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        DocumentNo := CopyStr(Request.GetText('documentNo'), 1, MaxStrLen(DocumentNo));
        Evaluate(PostingDate, Request.GetText('postingDate'), 9);
        ReversedEntries := ReadGLEntries(ProjectNo, true);
        WIP.CalcGLWIP(ProjectNo, true, DocumentNo, PostingDate, false);
        CurrentWIP.Add('status', 'Success');
        CurrentWIP.Add('projectNo', ProjectNo);
        CurrentWIP.Add('entries', ReadWIPEntries(ProjectNo));
        CurrentWIP.Add('glEntries', ReadGLEntries(ProjectNo));
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        Response.Add('reversedEntries', ReversedEntries);
        Response.Add('wip', CurrentWIP);
        Response.Add('nextStep', 'Projects.WIP.Calculate');
        Response.Add('summary', StrSubstNo(SummaryLbl, Count));
        Argument.SetResponseJson(Response);
    end;

    local procedure ReadWIPEntries(ProjectNo: Code[20]) Result: JsonArray
    var
        Entry: Record "Job WIP Entry";
        Item: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Entry.SetRange("Job No.", ProjectNo);
        Names := Entry.Type.Names();
        Ordinals := Entry.Type.Ordinals();
        if Entry.FindSet() then
            repeat
                Clear(Item);
                Item.Add('entryNo', Entry."Entry No.");
                Item.Add('documentNo', Entry."Document No.");
                Item.Add('postingDate', Entry."WIP Posting Date");
                Item.Add('accountNo', Entry."G/L Account No.");
                Item.Add('balanceAccountNo', Entry."G/L Bal. Account No.");
                Item.Add('amount', Entry."WIP Entry Amount");
                Item.Add('type', Names.Get(Ordinals.IndexOf(Entry.Type.AsInteger())));
                Item.Add('complete', Entry."Job Complete");
                Result.Add(Item);
            until Entry.Next() = 0;
    end;

    local procedure ReadGLEntries(ProjectNo: Code[20]): JsonArray
    begin
        exit(ReadGLEntries(ProjectNo, false));
    end;

    local procedure ReadGLEntries(ProjectNo: Code[20]; ReversalCandidatesOnly: Boolean) Result: JsonArray
    var
        Entry: Record "Job WIP G/L Entry";
        Item: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Entry.SetRange("Job No.", ProjectNo);
        if ReversalCandidatesOnly then begin
            Entry.SetRange(Reverse, true);
            Entry.SetRange(Reversed, false);
        end;
        Names := Entry.Type.Names();
        Ordinals := Entry.Type.Ordinals();
        if Entry.FindSet() then
            repeat
                Clear(Item);
                Item.Add('entryNo', Entry."Entry No.");
                Item.Add('documentNo', Entry."Document No.");
                Item.Add('postingDate', Entry."Posting Date");
                Item.Add('accountNo', Entry."G/L Account No.");
                Item.Add('balanceAccountNo', Entry."G/L Bal. Account No.");
                Item.Add('amount', Entry."WIP Entry Amount");
                Item.Add('type', Names.Get(Ordinals.IndexOf(Entry.Type.AsInteger())));
                Item.Add('complete', Entry."Job Complete");
                Item.Add('reversed', Entry.Reversed or ReversalCandidatesOnly);
                Item.Add('glEntryNo', Entry."G/L Entry No.");
                Result.Add(Item);
            until Entry.Next() = 0;
    end;
}
