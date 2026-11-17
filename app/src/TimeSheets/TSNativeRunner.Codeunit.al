namespace Origo.Bifrost.Projects;

using Microsoft.Foundation.NoSeries;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.Resources.Setup;
using Microsoft.Projects.TimeSheet;

/// <summary>
/// Write isolation for the native time-sheet message types. OnRun is started with
/// Codeunit.Run. A platform error rolls the write back and the caller maps it to a
/// clean refusal. This codeunit does not re-check the request; the manager did that.
/// </summary>
codeunit 70013567 "TS Native Runner ori"
{
    Access = Internal;

    trigger OnRun()
    var
        Context: Codeunit "TS Native Context ori";
    begin
        case Context.GetOperation() of
            1:
                Submit(Context);
            2:
                Approve(Context);
            3:
                Reject(Context);
            8, 9, 10:
                RunBulkTimeSheetOperation(Context);
        end;
    end;

    local procedure Approve(Context: Codeunit "TS Native Context ori")
    var
        TimeSheetLine: Record "Time Sheet Line";
        ApprovalMgt: Codeunit "Time Sheet Approval Management";
        Lines: JsonArray;
    begin
        SelectLines(Context, TimeSheetLine);
        if TimeSheetLine.FindSet(true) then
            repeat
                if TimeSheetLine.Status = TimeSheetLine.Status::Submitted then begin
                    ApprovalMgt.Approve(TimeSheetLine);
                    TimeSheetLine.Get(TimeSheetLine."Time Sheet No.", TimeSheetLine."Line No.");
                    Lines.Add(LineNode(TimeSheetLine, true));
                end else begin
                    TimeSheetLine.TestField(Status, TimeSheetLine.Status::Approved);
                    Lines.Add(LineNode(TimeSheetLine, false));
                end;
            until TimeSheetLine.Next() = 0;
        StoreLines(Context, Lines);
    end;

    local procedure Reject(Context: Codeunit "TS Native Context ori")
    var
        TimeSheetLine: Record "Time Sheet Line";
        ApprovalMgt: Codeunit "Time Sheet Approval Management";
        Lines: JsonArray;
    begin
        SelectLines(Context, TimeSheetLine);
        if TimeSheetLine.FindSet(true) then
            repeat
                TimeSheetLine.TestField(Status, TimeSheetLine.Status::Submitted);
                ApprovalMgt.Reject(TimeSheetLine);
                TimeSheetLine.Get(TimeSheetLine."Time Sheet No.", TimeSheetLine."Line No.");
                if Context.GetComment() <> '' then
                        WriteComment(TimeSheetLine, Context.GetComment());
                Lines.Add(LineNode(TimeSheetLine, true));
            until TimeSheetLine.Next() = 0;
        StoreLines(Context, Lines);
    end;

    local procedure SelectLines(Context: Codeunit "TS Native Context ori"; var TimeSheetLine: Record "Time Sheet Line")
    begin
        if Context.GetOperation() <> 1 then
            CheckApprover(Context.GetSheetNo());
        TimeSheetLine.SetRange("Time Sheet No.", Context.GetSheetNo());
        if Context.GetLineFilter() <> '*' then
            TimeSheetLine.SetFilter("Line No.", Context.GetLineFilter());
    end;

    local procedure CheckApprover(SheetNo: Code[20])
    var
        Header: Record "Time Sheet Header";
        ApproverErr: Label 'Only the approver named on the time sheet can approve.', Comment = 'is-IS=Aðeins samþykktaraðilinn sem er nefndur á tímaskýrslunni getur samþykkt.';
    begin
        Header.ReadIsolation := IsolationLevel::UpdLock;
        Header.Get(SheetNo);
        if (Header."Approver User ID" = '') or (Header."Approver User ID" <> UpperCase(UserId())) then
            Error(ErrorInfo.Create(ApproverErr));
    end;

    local procedure WriteComment(TimeSheetLine: Record "Time Sheet Line"; Comment: Text)
    var
        CommentLine: Record "Time Sheet Comment Line";
        LineNo: Integer;
    begin
        CommentLine.ReadIsolation := IsolationLevel::UpdLock;
        CommentLine.SetRange("No.", TimeSheetLine."Time Sheet No.");
        CommentLine.SetRange("Time Sheet Line No.", TimeSheetLine."Line No.");
        if CommentLine.FindLast() then
            LineNo := CommentLine."Line No." + 10000
        else
            LineNo := 10000;
        CommentLine.Init();
        CommentLine."No." := TimeSheetLine."Time Sheet No.";
        CommentLine."Time Sheet Line No." := TimeSheetLine."Line No.";
        CommentLine."Line No." := LineNo;
        CommentLine.Validate(Date, WorkDate());
        CommentLine.Validate(Comment, CopyStr(Comment, 1, MaxStrLen(CommentLine.Comment)));
        CommentLine.Insert(true);
    end;

    local procedure LineNode(TimeSheetLine: Record "Time Sheet Line"; Changed: Boolean) Node: JsonObject
    var
        Context: Codeunit "TS Native Context ori";
    begin
        Node.Add('timeSheetNo', TimeSheetLine."Time Sheet No.");
        Node.Add('lineNo', TimeSheetLine."Line No.");
        Node.Add('status', TimeSheetLine.Status.Names().Get(TimeSheetLine.Status.Ordinals().IndexOf(TimeSheetLine.Status.AsInteger())));
        Node.Add('changed', Changed);
        if Context.GetOperation() = 1 then
            Node.Add('lineType', TimeSheetLine.Type.Names().Get(TimeSheetLine.Type.Ordinals().IndexOf(TimeSheetLine.Type.AsInteger())));
    end;

    local procedure StoreLines(Context: Codeunit "TS Native Context ori"; Lines: JsonArray)
    var
        Response: JsonObject;
    begin
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Context.SetResult(JsonText(Response));
    end;

    local procedure JsonText(Response: JsonObject): Text
    var
        Result: Text;
    begin
        Response.WriteTo(Result);
        exit(Result);
    end;

    local procedure RunBulkTimeSheetOperation(Context: Codeunit "TS Native Context ori")
    var
        TimeSheetMgt: Codeunit "TS Bulk Mgt ori";
        Response: JsonObject;
        ResponseText: Text;
    begin
        Response.Add('status', 'Success');
        case Context.GetOperation() of
            8:
                Response.Add('reopenedLines', TimeSheetMgt.ReopenTimeSheets(Context.GetStartDate()));
            9:
                Response.Add('postedLines', TimeSheetMgt.PostApprovedTimeSheets(Context.GetJournalTemplate(), Context.GetJournalBatch()));
            10:
                Response.Add('archived', TimeSheetMgt.ArchivePostedTimeSheets());
        end;
        Response.WriteTo(ResponseText);
        Context.SetResult(ResponseText);
    end;

    local procedure Submit(Context: Codeunit "TS Native Context ori")
    var
        TimeSheetLine: Record "Time Sheet Line";
        ApprovalMgt: Codeunit "Time Sheet Approval Management";
        Lines: JsonArray;
    begin
        SelectLines(Context, TimeSheetLine);
        if TimeSheetLine.FindSet(true) then
            repeat
                if TimeSheetLine.Status = TimeSheetLine.Status::Open then begin
                    ApprovalMgt.Submit(TimeSheetLine);
                    TimeSheetLine.Get(TimeSheetLine."Time Sheet No.", TimeSheetLine."Line No.");
                    Lines.Add(LineNode(TimeSheetLine, TimeSheetLine.Status = TimeSheetLine.Status::Submitted));
                end else
                    Lines.Add(LineNode(TimeSheetLine, false));
            until TimeSheetLine.Next() = 0;
        StoreLines(Context, Lines);
    end;
}
