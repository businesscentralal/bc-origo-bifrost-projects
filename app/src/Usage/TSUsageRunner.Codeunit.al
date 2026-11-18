namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>
/// Write isolation for the usage message types. OnRun is started with Codeunit.Run, so a
/// failure rolls back every change of the request. The runner revalidates decision eligibility under update locks before writing.
/// </summary>
codeunit 70013403 "TS Usage Runner ori"
{
    Access = Internal;
    Permissions = tabledata "TS Usage Line ori" = RIM;

    trigger OnRun()
    var
        Context: Codeunit "TS Usage Context ori";
    begin
        case Context.GetOperation() of
            1:
                Register(Context);
            2, 3, 4:
                Decide(Context);
            5:
                Transfer(Context);
            6:
                Reverse(Context);
        end;
    end;

    local procedure Register(Context: Codeunit "TS Usage Context ori")
    var
        Usage: Record "TS Usage Line ori";
        Mgt: Codeunit "TS Usage Mgt ori";
        Params: JsonObject;
        Lines: JsonArray;
        Response: JsonObject;
    begin
        Params := Context.GetParams();
        Usage.Init();
        Usage."Time Sheet No." := CopyStr(Mgt.GetText(Params, 'timeSheetNo'), 1, MaxStrLen(Usage."Time Sheet No."));
        Usage."Time Sheet Line No." := Mgt.GetInt(Params, 'lineNo');
        Usage."Resource No." := CopyStr(Mgt.GetText(Params, 'resourceNo'), 1, MaxStrLen(Usage."Resource No."));
        if Mgt.GetText(Params, 'type') = 'Item' then
            Usage.Type := Usage.Type::Item
        else
            Usage.Type := Usage.Type::Resource;
        Usage."No." := CopyStr(Mgt.GetText(Params, 'no'), 1, MaxStrLen(Usage."No."));
        Evaluate(Usage.Date, Mgt.GetText(Params, 'date'), 9);
        Evaluate(Usage.Quantity, Mgt.GetText(Params, 'quantity'), 9);
        Usage."Unit of Measure Code" := CopyStr(Mgt.GetText(Params, 'unitOfMeasure'), 1, MaxStrLen(Usage."Unit of Measure Code"));
        Usage.Description := CopyStr(Mgt.GetText(Params, 'description'), 1, MaxStrLen(Usage.Description));
        Usage.Status := Usage.Status::Open;
        Usage.Insert();
        Lines.Add(Mgt.LineNode(Usage, true));
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Context.SetResult(Mgt.JsonText(Response));
    end;

    local procedure Decide(Context: Codeunit "TS Usage Context ori")
    var
        Usage: Record "TS Usage Line ori";
        Mgt: Codeunit "TS Usage Mgt ori";
        Params: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        Lines: JsonArray;
        Response: JsonObject;
        Operation: Integer;
        Index: Integer;
    begin
        Operation := Context.GetOperation();
        Params := Context.GetParams();
        Params.Get('entryNos', Token);
        Usage.ReadIsolation := IsolationLevel::UpdLock;
        for Index := 0 to Token.AsArray().Count() - 1 do begin
            Token.AsArray().Get(Index, Entry);
            Usage.Get(Entry.AsValue().AsInteger());
            Mgt.ValidateDecision(Usage, Operation, CopyStr(Mgt.GetText(Params, 'timeSheetNo'), 1, MaxStrLen(Usage."Time Sheet No.")));
            case Operation of
                2:
                    Usage.Status := Usage.Status::Submitted;
                3:
                    begin
                        Usage.Status := Usage.Status::Approved;
                        Usage."Approved By" := CopyStr(UserId(), 1, MaxStrLen(Usage."Approved By"));
                        Usage."Approved At" := CurrentDateTime();
                    end;
                4:
                    begin
                        Usage.Status := Usage.Status::Rejected;
                        Usage."Reject Comment" := CopyStr(Mgt.GetText(Params, 'comment'), 1, MaxStrLen(Usage."Reject Comment"));
                    end;
            end;
            Usage.Modify();
            Lines.Add(Mgt.LineNode(Usage, true));
        end;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Context.SetResult(Mgt.JsonText(Response));
    end;

    local procedure Transfer(Context: Codeunit "TS Usage Context ori")
    var
        Usage: Record "TS Usage Line ori";
        Journal: Codeunit "TS Usage Journal ori";
        Mgt: Codeunit "TS Usage Mgt ori";
        Params: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        Lines: JsonArray;
        Response: JsonObject;
        Template: Code[10];
        Batch: Code[10];
        Index: Integer;
    begin
        Params := Context.GetParams();
        Params.Get('entryNos', Token);
        for Index := 0 to Token.AsArray().Count() - 1 do begin
            Token.AsArray().Get(Index, Entry);
            Usage.Get(Entry.AsValue().AsInteger());
            Usage.TestField(Status, Usage.Status::Approved);
            Mgt.JournalTarget(Params, Usage, Template, Batch);
            Usage."Document No." := Mgt.DocumentNo('TSU', Usage."Entry No.");
            Usage."Journal Line No." := Journal.CreateJournalLine(Usage, Template, Batch, false, Usage."Document No.");
            Usage."Journal Template Name" := Template;
            Usage."Journal Batch Name" := Batch;
            Usage.Status := Usage.Status::Transferred;
            Usage.Modify();
            Lines.Add(Mgt.LineNode(Usage, true));
        end;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Context.SetResult(Mgt.JsonText(Response));
    end;

    local procedure Reverse(Context: Codeunit "TS Usage Context ori")
    var
        Usage: Record "TS Usage Line ori";
        Journal: Codeunit "TS Usage Journal ori";
        Mgt: Codeunit "TS Usage Mgt ori";
        Params: JsonObject;
        Token: JsonToken;
        Lines: JsonArray;
        Response: JsonObject;
        Template: Code[10];
        Batch: Code[10];
        ReversingLineNo: Integer;
    begin
        Params := Context.GetParams();
        Usage.Get(Mgt.GetInt(Params, 'entryNo'));
        Usage.TestField(Status, Usage.Status::Posted);
        Usage.TestField(Reversed, false);
        if Params.Get('createJournalLine', Token) then
            if Token.AsValue().AsBoolean() then begin
                Mgt.JournalTarget(Params, Usage, Template, Batch);
                ReversingLineNo := Journal.CreateJournalLine(Usage, Template, Batch, true, Mgt.DocumentNo('TSR', Usage."Entry No."));
            end;
        Usage.Reversed := true;
        Usage.Modify();
        Lines.Add(Mgt.LineNode(Usage, true));
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        if ReversingLineNo <> 0 then
            Response.Add('reversingJournalLineNo', ReversingLineNo);
        Context.SetResult(Mgt.JsonText(Response));
    end;
}
