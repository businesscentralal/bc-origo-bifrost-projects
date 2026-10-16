namespace Origo.Bifrost.Projects;

using Origo.Bifrost;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.WIP;

/// <summary>Executes native WIP operations and returns the actual calculated and posted entry state.</summary>
codeunit 10078505 "Projects WIP ori"
{
    Access = Internal;
    /// <summary>Runs inside the existing Projects process transaction, preserving native WIP and posting validation.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        WIP: Codeunit "Job Calculate WIP";
        Request: JsonObject;
        Response: JsonObject;
        ProjectNo: Code[20];
        PostingDate: Date;
        DocumentNo: Code[20];
    begin
        Request := Argument.GetRequestJson();
        ProjectNo := CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(ProjectNo));
        Project.Get(ProjectNo);
        if Argument.Type <> "Message Type ori"::"Projects.WIP.Get" then begin
            Evaluate(PostingDate, Request.GetText('postingDate'), 9);
            DocumentNo := CopyStr(Request.GetText('documentNo'), 1, MaxStrLen(DocumentNo));
            case Argument.Type of
                "Message Type ori"::"Projects.WIP.Calculate":
                    WIP.JobCalcWIP(Project, PostingDate, DocumentNo);
            end;
        end;
        Response.Add('status', 'Success');
        Response.Add('projectNo', ProjectNo);
        Response.Add('entries', ReadWIPEntries(ProjectNo));
        Response.Add('glEntries', ReadGLEntries(ProjectNo));
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

    local procedure ReadGLEntries(ProjectNo: Code[20]) Result: JsonArray
    var
        Entry: Record "Job WIP G/L Entry";
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
                Item.Add('postingDate', Entry."Posting Date");
                Item.Add('accountNo', Entry."G/L Account No.");
                Item.Add('balanceAccountNo', Entry."G/L Bal. Account No.");
                Item.Add('amount', Entry."WIP Entry Amount");
                Item.Add('type', Names.Get(Ordinals.IndexOf(Entry.Type.AsInteger())));
                Item.Add('complete', Entry."Job Complete");
                Item.Add('reversed', Entry.Reversed);
                Item.Add('glEntryNo', Entry."G/L Entry No.");
                Result.Add(Item);
            until Entry.Next() = 0;
    end;
}
