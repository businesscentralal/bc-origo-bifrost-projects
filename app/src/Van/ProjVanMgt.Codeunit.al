namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Microsoft.Warehouse.Structure;
using Origo.Bifrost;

/// <summary>Validates Projects.VisitItem.Register and Projects.VanStock.Get. A refusal writes nothing.</summary>
codeunit 70013474 "Proj. Van Mgt ori"
{
    Access = Internal;

    /// <summary>True when the caller can read the stock context and register usage on a time sheet.</summary>
    procedure CanRun(): Boolean
    var
        Item: Record Item;
        Location: Record Location;
        Setup: Record "Proj. Technician Setup ori";
        Ledger: Record "Item Ledger Entry";
        Visit: Codeunit "Proj. Visit Mgt ori";
    begin
        exit(Visit.CanRun() and Item.ReadPermission() and Location.ReadPermission() and Setup.ReadPermission() and Ledger.ReadPermission());
    end;

    /// <summary>Registers van parts as Open usage lines.</summary>
    procedure ExecuteRegister(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        ResourceNo: Code[20];
        RequestId: Text;
        Allowed: List of [Text];
    begin
        if not Open(Argument, ResourceNo) then
            exit;
        Request := Argument.GetRequestJson();
        Allowed.AddRange('projectNo', 'taskNo', 'items', 'date', 'clientRequestId');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        if not ReadOptional(Argument, Request, 'clientRequestId', 100, RequestId) then
            exit;
        if Replay(Argument, ResourceNo, RequestId) then
            exit;
        Register(Argument, Request, ResourceNo, RequestId);
    end;

    /// <summary>Returns the van stock after pending usage.</summary>
    procedure ExecuteStock(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        ResourceNo: Code[20];
        Allowed: List of [Text];
        FilterText: Text;
        BelowOnly: Boolean;
        Location: Code[10];
        DefaultBin: Code[20];
    begin
        if not Open(Argument, ResourceNo) then
            exit;
        Request := Argument.GetRequestJson();
        Allowed.AddRange('itemFilter', 'belowMinimumOnly');
        if not AllowOnly(Argument, Request, Allowed) then
            exit;
        if not ReadOptional(Argument, Request, 'itemFilter', 100, FilterText) then
            exit;
        if not ReadBoolean(Argument, Request, 'belowMinimumOnly', BelowOnly) then
            exit;
        if not VanOf(Argument, ResourceNo, Location, DefaultBin) then
            exit;
        Stock(Argument, Location, DefaultBin, FilterText, BelowOnly);
    end;

    local procedure Open(var Argument: Record "Message Argument ori"; var ResourceNo: Code[20]): Boolean
    var
        Resource: Record Resource;
    begin
        Argument.AssertVersion1();
        if not CanRun() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', VanContract.PermissionNext());
            exit(false);
        end;
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', VanContract.IsolatedNext());
            exit(false);
        end;
        Resource.SetRange("Time Sheet Owner User ID", CallerId());
        Resource.SetRange("Use Time Sheet", true);
        if not Resource.FindFirst() then begin
            Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, '', VanContract.UnmappedNext());
            exit(false);
        end;
        ResourceNo := Resource."No.";
        exit(true);
    end;

    local procedure VanOf(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; var Location: Code[10]; var DefaultBin: Code[20]): Boolean
    var
        Setup: Record "Proj. Technician Setup ori";
    begin
        if Setup.Get(ResourceNo) then begin
            Location := Setup."Van Location Code";
            DefaultBin := Setup."Default Bin Code";
        end;
        if Location = '' then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', VanContract.NoVanNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure Register(var Argument: Record "Message Argument ori"; Request: JsonObject; ResourceNo: Code[20]; RequestId: Text)
    var
        Header: Record "Time Sheet Header";
        JobTask: Record "Job Task";
        Job: Record Job;
        Item: Record Item;
        Token: JsonToken;
        Entry: JsonToken;
        Payload: JsonObject;
        Node: JsonObject;
        Resolved: JsonArray;
        Ambiguous: JsonArray;
        Shortages: JsonArray;
        Requested: Dictionary of [Code[20], Decimal];
        ProjectNo: Text;
        TaskNo: Text;
        DateText: Text;
        UsageDate: Date;
        Location: Code[10];
        DefaultBin: Code[20];
        Index: Integer;
        ItemNo: Code[20];
        BaseQty: Decimal;
        Available: Decimal;
    begin
        if not ReadRequired(Argument, Request, 'projectNo', 20, ProjectNo) then
            exit;
        if not ReadRequired(Argument, Request, 'taskNo', 20, TaskNo) then
            exit;
        if not ReadOptional(Argument, Request, 'date', 10, DateText) then
            exit;
        UsageDate := Today();
        if DateText <> '' then
            if not Evaluate(UsageDate, DateText, 9) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'date', VanContract.FormatNext());
                exit;
            end;
        if not Request.Get('items', Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'items', VanContract.MissingNext());
            exit;
        end;
        if not Token.IsArray() then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'items', VanContract.FormatNext());
            exit;
        end;
        if Token.AsArray().Count() = 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'items', VanContract.MissingNext());
            exit;
        end;
        if Token.AsArray().Count() > 50 then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'items', VanContract.FormatNext());
            exit;
        end;
        if not Job.Get(CopyStr(ProjectNo, 1, MaxStrLen(Job."No."))) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', VanContract.NotFoundNext());
            exit;
        end;
        if not JobTask.Get(Job."No.", CopyStr(TaskNo, 1, MaxStrLen(JobTask."Job Task No."))) or (JobTask."Job Task Type" <> JobTask."Job Task Type"::Posting) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', VanContract.NotFoundNext());
            exit;
        end;
        if not VanOf(Argument, ResourceNo, Location, DefaultBin) then
            exit;
        if not FindSheet(Argument, ResourceNo, UsageDate, Header) then
            exit;
        if not LineUsable(Argument, Header."No.", Job."No.", JobTask."Job Task No.") then
            exit;
        for Index := 0 to Token.AsArray().Count() - 1 do begin
            Token.AsArray().Get(Index, Entry);
            if not Entry.IsObject() then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'items', VanContract.FormatNext());
                exit;
            end;
            if not ResolveEntry(Argument, Entry.AsObject(), Location, DefaultBin, Item, Node, Ambiguous) then
                exit;
            if Node.Contains('itemNo') then begin
                Resolved.Add(Node);
                ItemNo := CopyStr(Node.GetText('itemNo'), 1, MaxStrLen(ItemNo));
                Evaluate(BaseQty, Node.GetText('baseQuantity'), 9);
                if Requested.ContainsKey(ItemNo) then
                    Requested.Set(ItemNo, Requested.Get(ItemNo) + BaseQty)
                else
                    Requested.Add(ItemNo, BaseQty);
            end;
            Clear(Node);
        end;
        if Ambiguous.Count() > 0 then begin
            AmbiguousResponse(Argument, Ambiguous);
            exit;
        end;
        foreach ItemNo in Requested.Keys() do begin
            Available := AvailableBase(ItemNo, Location);
            if Requested.Get(ItemNo) > Available then begin
                Clear(Node);
                Node.Add('itemNo', ItemNo);
                Node.Add('requested', Requested.Get(ItemNo));
                Node.Add('available', Available);
                Shortages.Add(Node);
            end;
        end;
        Payload.Add('sheetNo', Header."No.");
        Payload.Add('resourceNo', ResourceNo);
        Payload.Add('projectNo', Job."No.");
        Payload.Add('taskNo', JobTask."Job Task No.");
        Payload.Add('date', Format(UsageDate, 0, 9));
        Payload.Add('location', Location);
        Payload.Add('clientRequestId', RequestId);
        Payload.Add('items', Resolved);
        Payload.Add('shortages', Shortages);
        RunWriter(Argument, Payload);
    end;

    local procedure ResolveEntry(var Argument: Record "Message Argument ori"; Entry: JsonObject; Location: Code[10]; DefaultBin: Code[20]; var Item: Record Item; var Node: JsonObject; var Ambiguous: JsonArray): Boolean
    var
        ItemUoM: Record "Item Unit of Measure";
        Bin: Record Bin;
        TrackingCode: Record "Item Tracking Code";
        Allowed: List of [Text];
        ItemNoText: Text;
        ReferenceText: Text;
        DescriptionText: Text;
        UnitText: Text;
        BinText: Text;
        LotText: Text;
        SerialText: Text;
        Quantity: Decimal;
        IsAmbiguous: Boolean;
    begin
        Allowed.AddRange('itemNo', 'reference', 'description', 'quantity', 'unitOfMeasure', 'binCode', 'lotNo', 'serialNo');
        if not AllowOnly(Argument, Entry, Allowed) then
            exit(false);
        if not (ReadOptional(Argument, Entry, 'itemNo', 20, ItemNoText) and ReadOptional(Argument, Entry, 'reference', 50, ReferenceText) and
                ReadOptional(Argument, Entry, 'description', 100, DescriptionText) and ReadOptional(Argument, Entry, 'unitOfMeasure', 10, UnitText) and
                ReadOptional(Argument, Entry, 'binCode', 20, BinText) and ReadOptional(Argument, Entry, 'lotNo', 50, LotText) and
                ReadOptional(Argument, Entry, 'serialNo', 50, SerialText))
        then
            exit(false);
        if not ReadQuantity(Argument, Entry, Quantity) then
            exit(false);
        if (ItemNoText = '') and (ReferenceText = '') and (DescriptionText = '') then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'itemNo', VanContract.MissingNext());
            exit(false);
        end;
        if not FindItem(Argument, ItemNoText, ReferenceText, DescriptionText, Item, Ambiguous, IsAmbiguous) then
            exit(false);
        if IsAmbiguous then
            exit(true);
        if Item.Blocked then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'itemNo', VanContract.BlockedNext());
            exit(false);
        end;
        if UnitText = '' then
            UnitText := Item."Base Unit of Measure";
        if not ItemUoM.Get(Item."No.", CopyStr(UnitText, 1, MaxStrLen(ItemUoM.Code))) then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'unitOfMeasure', VanContract.NotFoundNext());
            exit(false);
        end;
        if BinText = '' then
            BinText := DefaultBin;
        if BinText <> '' then
            if not Bin.Get(Location, CopyStr(BinText, 1, MaxStrLen(Bin.Code))) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'binCode', VanContract.NotFoundNext());
                exit(false);
            end;
        if (SerialText <> '') and (Quantity <> 1) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'quantity', VanContract.SerialNext());
            exit(false);
        end;
        if Item."Item Tracking Code" <> '' then begin
            TrackingCode.Get(Item."Item Tracking Code");
            if (TrackingCode."Lot Specific Tracking" and (LotText = '')) or (TrackingCode."SN Specific Tracking" and (SerialText = '')) then begin
                Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'lotNo', VanContract.TrackedNext());
                exit(false);
            end;
        end;
        Node.Add('itemNo', Item."No.");
        Node.Add('description', Item.Description);
        Node.Add('quantity', Format(Quantity, 0, 9));
        Node.Add('baseQuantity', Format(Quantity * ItemUoM."Qty. per Unit of Measure", 0, 9));
        Node.Add('unitOfMeasure', ItemUoM.Code);
        Node.Add('binCode', BinText);
        Node.Add('lotNo', LotText);
        Node.Add('serialNo', SerialText);
        exit(true);
    end;

    local procedure FindItem(var Argument: Record "Message Argument ori"; ItemNoText: Text; ReferenceText: Text; DescriptionText: Text; var Item: Record Item; var Ambiguous: JsonArray; var IsAmbiguous: Boolean): Boolean
    var
        Reference: Record "Item Reference";
        Candidates: JsonArray;
        Candidate: JsonObject;
        Input: JsonObject;
        Seen: List of [Code[20]];
        FilterText: Text;
        Count: Integer;
    begin
        IsAmbiguous := false;
        if ItemNoText <> '' then begin
            if not Item.Get(CopyStr(ItemNoText, 1, MaxStrLen(Item."No."))) then begin
                Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'itemNo', VanContract.NotFoundNext());
                exit(false);
            end;
            if ReferenceText <> '' then begin
                Reference.SetRange("Reference No.", CopyStr(ReferenceText, 1, MaxStrLen(Reference."Reference No.")));
                Reference.SetRange("Item No.", Item."No.");
                if Reference.IsEmpty() then begin
                    Reference.SetRange("Item No.");
                    if Reference.IsEmpty() then
                        Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'reference', VanContract.NotFoundNext())
                    else
                        Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'reference', VanContract.ConflictNext());
                    exit(false);
                end;
            end;
            exit(true);
        end;
        if ReferenceText <> '' then begin
            Reference.SetRange("Reference No.", CopyStr(ReferenceText, 1, MaxStrLen(Reference."Reference No.")));
            if Reference.FindSet() then
                repeat
                    if not Seen.Contains(Reference."Item No.") then begin
                        Seen.Add(Reference."Item No.");
                        Item.Get(Reference."Item No.");
                        Clear(Candidate);
                        Candidate.Add('itemNo', Item."No.");
                        Candidate.Add('description', Item.Description);
                        Candidates.Add(Candidate);
                    end;
                until Reference.Next() = 0;
            Count := Seen.Count();
            FilterText := ReferenceText;
        end else begin
            FilterText := DelChr(DescriptionText, '=', '*|&()<>=@''"?');
            if FilterText = '' then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'description', VanContract.FormatNext());
                exit(false);
            end;
            Item.Reset();
            Item.SetFilter(Description, '@' + FilterText);
            Count := Item.Count();
            if Count = 0 then begin
                Item.SetFilter(Description, '@*' + FilterText + '*');
                Count := Item.Count();
            end;
            if Item.FindSet() then
                repeat
                    Clear(Candidate);
                    Candidate.Add('itemNo', Item."No.");
                    Candidate.Add('description', Item.Description);
                    if Candidates.Count() < 5 then
                        Candidates.Add(Candidate);
                until (Item.Next() = 0) or (Candidates.Count() >= 5);
        end;
        if Count = 0 then begin
            Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'itemNo', VanContract.NotFoundNext());
            exit(false);
        end;
        if Count = 1 then begin
            Item.Get(Candidates.GetObject(0).GetText('itemNo'));
            exit(true);
        end;
        IsAmbiguous := true;
        Input.Add('input', FilterText);
        Input.Add('candidates', Candidates);
        Ambiguous.Add(Input);
        exit(true);
    end;

    local procedure AmbiguousResponse(var Argument: Record "Message Argument ori"; Ambiguous: JsonArray)
    var
        Response: JsonObject;
        Lines: JsonArray;
        Next: JsonArray;
    begin
        Response.Add('status', 'Ambiguous');
        Response.Add('lines', Lines);
        Response.Add('ambiguous', Ambiguous);
        Response.Add('summary', VanContract.ChooseNext());
        Next.Add('Projects.VisitItem.Register');
        Response.Add('nextSteps', Next);
        Argument.SetResponseJson(Response);
    end;

    local procedure FindSheet(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; Day: Date; var Header: Record "Time Sheet Header"): Boolean
    begin
        Header.SetRange("Resource No.", ResourceNo);
        Header.SetRange("Owner User ID", CallerId());
        Header.SetFilter("Starting Date", '..%1', Day);
        Header.SetFilter("Ending Date", '%1..', Day);
        if not Header.FindFirst() then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'date', VanContract.NoSheetNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure LineUsable(var Argument: Record "Message Argument ori"; SheetNo: Code[20]; ProjectNo: Code[20]; TaskNo: Code[20]): Boolean
    var
        Line: Record "Time Sheet Line";
    begin
        Line.SetRange("Time Sheet No.", SheetNo);
        Line.SetRange(Type, Line.Type::Job);
        Line.SetRange("Job No.", ProjectNo);
        Line.SetRange("Job Task No.", TaskNo);
        Line.SetRange("Work Type Code", '');
        Line.SetFilter(Status, '%1|%2', Line.Status::Open, Line.Status::Rejected);
        if not Line.IsEmpty() then
            exit(true);
        Line.SetRange(Status);
        if not Line.IsEmpty() then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', VanContract.LockedLineNext());
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Inventory at the location minus usage lines that are not posted yet, in base units.</summary>
    procedure AvailableBase(ItemNo: Code[20]; Location: Code[10]): Decimal
    var
        Item: Record Item;
    begin
        Item.SetLoadFields("No.");
        Item.Get(ItemNo);
        Item.SetRange("Location Filter", Location);
        Item.CalcFields(Inventory);
        exit(Item.Inventory - PendingBase(ItemNo, Location));
    end;

    local procedure PendingBase(ItemNo: Code[20]; Location: Code[10]): Decimal
    var
        Usage: Record "TS Usage Line ori";
        ItemUoM: Record "Item Unit of Measure";
        Total: Decimal;
        PerUnit: Decimal;
    begin
        Usage.SetRange(Type, Usage.Type::Item);
        Usage.SetRange("No.", ItemNo);
        Usage.SetRange("Location Code", Location);
        Usage.SetRange(Reversed, false);
        Usage.SetFilter(Status, '%1|%2|%3|%4', Usage.Status::Open, Usage.Status::Submitted, Usage.Status::Approved, Usage.Status::Transferred);
        if Usage.FindSet() then
            repeat
                PerUnit := 1;
                if Usage."Unit of Measure Code" <> '' then
                    if ItemUoM.Get(ItemNo, Usage."Unit of Measure Code") then
                        PerUnit := ItemUoM."Qty. per Unit of Measure";
                Total += Usage.Quantity * PerUnit;
            until Usage.Next() = 0;
        exit(Total);
    end;

    local procedure Stock(var Argument: Record "Message Argument ori"; Location: Code[10]; DefaultBin: Code[20]; FilterText: Text; BelowOnly: Boolean)
    var
        Item: Record Item;
        Sku: Record "Stockkeeping Unit";
        Numbers: List of [Code[20]];
        ItemNo: Code[20];
        Response: JsonObject;
        Items: JsonArray;
        Node: JsonObject;
        Inventory: Decimal;
        Pending: Decimal;
        Available: Decimal;
        Reorder: Decimal;
        Below: Boolean;
        Truncated: Boolean;
    begin
        Item.SetLoadFields("No.", Description, "Reorder Point");
        Item.SetRange("Location Filter", Location);
        Item.SetFilter(Inventory, '<>0');
        if Item.FindSet() then
            repeat
                Numbers.Add(Item."No.");
            until Item.Next() = 0;
        Sku.SetRange("Location Code", Location);
        Sku.SetRange("Variant Code", '');
        if Sku.FindSet() then
            repeat
                if not Numbers.Contains(Sku."Item No.") then
                    Numbers.Add(Sku."Item No.");
            until Sku.Next() = 0;
        foreach ItemNo in Numbers do begin
            Item.Reset();
            Item.SetRange("Location Filter", Location);
            Item.Get(ItemNo);
            if (FilterText = '') or (StrPos(UpperCase(Item."No." + ' ' + Item.Description), UpperCase(FilterText)) > 0) then begin
                Item.CalcFields(Inventory);
                Inventory := Item.Inventory;
                Pending := PendingBase(ItemNo, Location);
                Available := Inventory - Pending;
                Reorder := Item."Reorder Point";
                if Sku.Get(Location, ItemNo, '') then
                    Reorder := Sku."Reorder Point";
                Below := (Reorder > 0) and (Available < Reorder);
                if Below or not BelowOnly then
                    if Items.Count() >= 200 then
                        Truncated := true
                    else begin
                        Clear(Node);
                        Node.Add('itemNo', ItemNo);
                        Node.Add('description', Item.Description);
                        Node.Add('inventory', Inventory);
                        Node.Add('pendingUsage', Pending);
                        Node.Add('available', Available);
                        Node.Add('binCode', DefaultBin);
                        Node.Add('belowMinimum', Below);
                        Items.Add(Node);
                    end;
            end;
        end;
        Response.Add('status', 'Success');
        Response.Add('location', Location);
        Response.Add('items', Items);
        Response.Add('summary', StrSubstNo(StockSummaryLbl, Items.Count(), Location) + TruncatedText(Truncated));
        Argument.SetResponseJson(Response);
    end;

    local procedure TruncatedText(Truncated: Boolean): Text
    begin
        if Truncated then
            exit(TruncatedLbl);
    end;

    local procedure Replay(var Argument: Record "Message Argument ori"; ResourceNo: Code[20]; RequestId: Text): Boolean
    var
        Usage: Record "TS Usage Line ori";
        Runner: Codeunit "Proj. Van Runner ori";
        Lines: JsonArray;
        Response: JsonObject;
    begin
        if RequestId = '' then
            exit(false);
        Usage.SetRange("Resource No.", ResourceNo);
        Usage.SetRange("Client Request Id", CopyStr(RequestId, 1, MaxStrLen(Usage."Client Request Id")));
        if not Usage.FindSet() then
            exit(false);
        repeat
            Lines.Add(Runner.LineNode(Usage));
        until Usage.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('lines', Lines);
        Response.Add('replayed', true);
        Response.Add('summary', StrSubstNo(WrittenLbl, Lines.Count()));
        Argument.SetResponseJson(Response);
        exit(true);
    end;

    local procedure RunWriter(var Argument: Record "Message Argument ori"; Payload: JsonObject)
    var
        Runner: Codeunit "Proj. Van Runner ori";
        Response: JsonObject;
        Err: Text;
    begin
        if Database.IsInWriteTransaction() then
            Commit();
        Runner.SetCall(Payload);
        if not Runner.Run() then begin
            Err := CopyStr(GetLastErrorText(), 1, 250);
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, VanContract.RefusedText(), '', Err, '', VanContract.RetryNext());
            exit;
        end;
        Response.ReadFrom(Runner.GetResult());
        Argument.SetResponseJson(Response);
    end;

    local procedure ReadQuantity(var Argument: Record "Message Argument ori"; Entry: JsonObject; var Quantity: Decimal): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        First: Text[1];
    begin
        if not Entry.Get('quantity', Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, 'quantity', VanContract.MissingNext());
            exit(false);
        end;
        if Token.IsValue() then begin
            Token.WriteTo(Raw);
            Raw := DelChr(Raw, '<>', ' ');
            First := CopyStr(Raw, 1, 1);
            if First in ['-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] then
                if Evaluate(Quantity, Raw, 9) and (Quantity > 0) then
                    exit(true);
        end;
        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'quantity', VanContract.FormatNext());
        exit(false);
    end;

    local procedure ReadBoolean(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := false;
        if not Request.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then begin
            Token.WriteTo(Raw);
            Raw := DelChr(Raw, '<>', ' ');
            if Raw in ['true', 'false'] then begin
                Value := Raw = 'true';
                exit(true);
            end;
        end;
        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, VanContract.FormatNext());
        exit(false);
    end;

    local procedure ReadRequired(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; MaxLength: Integer; var Value: Text): Boolean
    begin
        if not Request.Contains(KeyName) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName, VanContract.MissingNext());
            exit(false);
        end;
        if not ReadOptional(Argument, Request, KeyName, MaxLength, Value) then
            exit(false);
        if Value = '' then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName, VanContract.MissingNext());
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadOptional(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not Request.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then begin
            Token.WriteTo(Raw);
            if CopyStr(DelChr(Raw, '<>', ' '), 1, 1) = '"' then begin
                Value := Token.AsValue().AsText();
                if StrLen(Value) <= MaxLength then
                    exit(true);
            end;
        end;
        Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName, VanContract.FormatNext());
        exit(false);
    end;

    local procedure AllowOnly(var Argument: Record "Message Argument ori"; Request: JsonObject; Allowed: List of [Text]): Boolean
    var
        KeyName: Text;
    begin
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName, VanContract.UnknownNext());
                exit(false);
            end;
        exit(true);
    end;

    local procedure CallerId(): Code[50]
    begin
        exit(CopyStr(UpperCase(UserId()), 1, 50));
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Parameter: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, VanContract.RefusedText(), Parameter, '', '', NextStep);
    end;

    var
        VanContract: Codeunit "Proj. Van Contract ori";
        StockSummaryLbl: Label '%1 items at %2.', Comment = '%1 = count; %2 = location code; is-IS=%1 vörur á %2.';
        TruncatedLbl: Label ' The list is cut at 200 items; narrow it with itemFilter.', Comment = 'is-IS= Listinn er styttur við 200 vörur; þrengdu hann með itemFilter.';
        WrittenLbl: Label '%1 usage lines were written earlier with this clientRequestId.', Comment = '%1 = count; is-IS=%1 notkunarlínur voru skrifaðar áður með þessu clientRequestId.';
}
