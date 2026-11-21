namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>Writes the Open usage lines of one Projects.VisitItem.Register request in a single transaction.</summary>
codeunit 70013475 "Proj. Van Runner ori"
{
    Access = Internal;
    Permissions = tabledata "TS Usage Line ori" = RIM;

    var
        Payload: JsonObject;
        ResultText: Text;

    /// <summary>Stores the validated request for the next Run.</summary>
    procedure SetCall(NewPayload: JsonObject)
    begin
        Payload := NewPayload;
        ResultText := '';
    end;

    /// <summary>Returns the success JSON written by the last Run.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;

    /// <summary>Builds the response node of one usage line.</summary>
    procedure LineNode(Usage: Record "TS Usage Line ori") Node: JsonObject
    begin
        Node.Add('entryNo', Usage."Entry No.");
        Node.Add('itemNo', Usage."No.");
        Node.Add('description', Usage.Description);
        Node.Add('quantity', Usage.Quantity);
        Node.Add('unitOfMeasure', Usage."Unit of Measure Code");
        Node.Add('locationCode', Usage."Location Code");
        Node.Add('binCode', Usage."Bin Code");
        Node.Add('lotNo', Usage."Lot No.");
        Node.Add('serialNo', Usage."Serial No.");
        Node.Add('status', 'Open');
    end;

    trigger OnRun()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Usage: Record "TS Usage Line ori";
        VisitRunner: Codeunit "Proj. Visit Runner ori";
        Items: JsonArray;
        Entry: JsonToken;
        Lines: JsonArray;
        Response: JsonObject;
        Next: JsonArray;
        Day: Date;
        Index: Integer;
        Decimal: Decimal;
    begin
        Header.Get(Payload.GetText('sheetNo'));
        if not VisitRunner.FindOpenLine(Header."No.", CopyStr(Payload.GetText('projectNo'), 1, 20), CopyStr(Payload.GetText('taskNo'), 1, 20), '', Line) then
            VisitRunner.CreateJobLine(Header, CopyStr(Payload.GetText('projectNo'), 1, 20), CopyStr(Payload.GetText('taskNo'), 1, 20), '', Line);
        Evaluate(Day, Payload.GetText('date'), 9);
        Payload.Get('items', Entry);
        Items := Entry.AsArray();
        for Index := 0 to Items.Count() - 1 do begin
            Items.Get(Index, Entry);
            Usage.Init();
            Usage."Entry No." := 0;
            Usage."Time Sheet No." := Header."No.";
            Usage."Time Sheet Line No." := Line."Line No.";
            Usage."Resource No." := CopyStr(Payload.GetText('resourceNo'), 1, MaxStrLen(Usage."Resource No."));
            Usage.Type := Usage.Type::Item;
            Usage."No." := CopyStr(Entry.AsObject().GetText('itemNo'), 1, MaxStrLen(Usage."No."));
            Usage.Date := Day;
            Evaluate(Decimal, Entry.AsObject().GetText('quantity'), 9);
            Usage.Quantity := Decimal;
            Usage."Unit of Measure Code" := CopyStr(Entry.AsObject().GetText('unitOfMeasure'), 1, MaxStrLen(Usage."Unit of Measure Code"));
            Usage.Description := CopyStr(Entry.AsObject().GetText('description'), 1, MaxStrLen(Usage.Description));
            Usage."Location Code" := CopyStr(Payload.GetText('location'), 1, MaxStrLen(Usage."Location Code"));
            Usage."Bin Code" := CopyStr(Entry.AsObject().GetText('binCode'), 1, MaxStrLen(Usage."Bin Code"));
            Usage."Lot No." := CopyStr(Entry.AsObject().GetText('lotNo'), 1, MaxStrLen(Usage."Lot No."));
            Usage."Serial No." := CopyStr(Entry.AsObject().GetText('serialNo'), 1, MaxStrLen(Usage."Serial No."));
            Usage."Client Request Id" := CopyStr(Payload.GetText('clientRequestId'), 1, MaxStrLen(Usage."Client Request Id"));
            Usage.Status := Usage.Status::Open;
            Usage.Insert(true);
            Lines.Add(LineNode(Usage));
        end;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Response.Add('shortages', GetArray('shortages'));
        Response.Add('summary', StrSubstNo(SummaryLbl, Lines.Count(), Payload.GetText('location')));
        Next.Add('Projects.Usage.Submit');
        Next.Add('Projects.VanStock.Get');
        Response.Add('nextSteps', Next);
        Response.WriteTo(ResultText);
    end;

    local procedure GetArray(KeyName: Text) Result: JsonArray
    var
        Token: JsonToken;
    begin
        if Payload.Get(KeyName, Token) then
            Result := Token.AsArray();
    end;

    var
        SummaryLbl: Label '%1 usage lines written from van location %2. They stay Open until you submit them.', Comment = '%1 = count; %2 = location code; is-IS=%1 notkunarlínur skrifaðar frá bílstaðsetningu %2. Þær eru opnar þar til þú sendir þær inn.';
}
