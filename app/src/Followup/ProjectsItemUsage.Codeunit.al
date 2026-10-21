namespace Origo.Bifrost.Projects;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Posting;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Validates an atomic native project item-usage request before dispatching posting.</summary>
codeunit 70009233 "Projects Item Usage ori"
{
    Access = Internal;

    var
        MissingLbl: Label 'Check the project and task nos.', Comment = 'is-IS=Athugaðu verkefnis- og verkhlutanúmerin.';
        StatusLbl: Label 'Change the status with Projects.Project.SetStatus.', Comment = 'is-IS=Breyttu stöðunni með Projects.Project.SetStatus.';
        LinesLbl: Label 'Pass at least one item usage line with a positive quantity.', Comment = 'is-IS=Sendu að minnsta kosti eina vörunotkunarlínu með jákvæðu magni.';
        TypeLbl: Label 'Pass an array of item usage objects using the types listed in the help.', Comment = 'is-IS=Sendu fylki vörunotkunarhluta með gagnategundum sem taldar eru upp í hjálpinni.';
        IdentifierLbl: Label 'Pass existing item, variant, location, bin and unit of measure identifiers belonging together.', Comment = 'is-IS=Sendu auðkenni vöru, afbrigðis, birgðageymslu, hólfs og mælieiningar sem eru til og eiga saman.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Full ori and native project and inventory posting permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og innbyggðar heimildir til verkefna- og birgðabókunar.';

    /// <summary>Declares the task-level project selector and item lines.</summary>
    procedure Parameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
        ProjectLbl: Label 'Exact open unblocked project number.', Comment = 'is-IS=Nákvæmt númer opins ólokaðs verkefnis.';
        TaskLbl: Label 'Exact posting task number in projectNo.', Comment = 'is-IS=Nákvæmt bókunarverkhlutanúmer í projectNo.';
        ItemLinesLbl: Label 'Nonempty array: itemNo, quantity, optional variantCode, locationCode, binCode, unitOfMeasureCode, lotNo and serialNo. Quantity must be positive; one serial number represents one base unit.', Comment = 'is-IS=Fylki sem er ekki tómt: itemNo, quantity, valfrjálst variantCode, locationCode, binCode, unitOfMeasureCode, lotNo og serialNo. Magn verður að vera jákvætt; eitt raðnúmer táknar eina grunneiningu.';
        PostingLbl: Label 'Optional ISO posting date; defaults to the current work date.', Comment = 'is-IS=Valfrjáls ISO-bókunardagsetning; sjálfgefið er núverandi vinnudagsetning.';
        DocumentLbl: Label 'Optional document number; defaults to a unique value for this task. Posting is not idempotent.', Comment = 'is-IS=Valfrjálst skjalnúmer; sjálfgefið er einkvæmt gildi fyrir þetta verk. Endurtekning bókar aftur.';
    begin
        Result.Add(Input.Parameter('projectNo', 'string', true, ProjectLbl, 20));
        Result.Add(Input.Parameter('taskNo', 'string', true, TaskLbl, 20));
        Result.Add(Input.Parameter('lines', 'array', true, ItemLinesLbl, 0));
        Result.Add(Input.Parameter('postingDate', 'date', false, PostingLbl, 0));
        Result.Add(Input.Parameter('documentNo', 'string', false, DocumentLbl, 20));
    end;

    /// <summary>Declares every accepted nested item-line key for strict validation.</summary>
    procedure LineParameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
    begin
        Result.Add(Input.Parameter('itemNo', 'string', true, IdentifierLbl, 20));
        Result.Add(Input.Parameter('quantity', 'number', true, LinesLbl, 0));
        Result.Add(Input.Parameter('variantCode', 'string', false, IdentifierLbl, 10));
        Result.Add(Input.Parameter('locationCode', 'string', false, IdentifierLbl, 10));
        Result.Add(Input.Parameter('binCode', 'string', false, IdentifierLbl, 20));
        Result.Add(Input.Parameter('unitOfMeasureCode', 'string', false, IdentifierLbl, 10));
        Result.Add(Input.Parameter('lotNo', 'string', false, IdentifierLbl, 50));
        Result.Add(Input.Parameter('serialNo', 'string', false, IdentifierLbl, 50));
    end;

    /// <summary>Checks the explicit posting token and directly read/write native project data.</summary>
    procedure IsEnabled(): Boolean
    var
        Posting: Codeunit "Proj. Posting Gate ori";
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Posting.HasPostingPermission() and Gate.IsEnabled(Database::Job, true) and Gate.IsEnabled(Database::Job, false) and
             Gate.IsEnabled(Database::"Job Task", false) and Gate.IsEnabled(Database::Customer, false) and Gate.IsEnabled(Database::"Job Journal Line", true) and
             Gate.IsEnabled(Database::"Job Ledger Entry", true) and Gate.IsEnabled(Database::"Job Register", true) and
             Gate.IsEnabled(Database::"Job Planning Line", true) and Gate.IsEnabled(Database::Item, false) and
             Gate.IsEnabled(Database::"Item Variant", false) and Gate.IsEnabled(Database::Location, false) and
             Gate.IsEnabled(Database::Bin, false) and Gate.IsEnabled(Database::"Item Unit of Measure", false) and
             Gate.IsEnabled(Database::Item, true) and Gate.IsEnabled(Database::"Item Ledger Entry", true) and
             Gate.IsEnabled(Database::"Item Register", true) and Gate.IsEnabled(Database::"Value Entry", true) and
             Gate.IsEnabled(Database::"Item Application Entry", true) and Gate.IsEnabled(Database::"Reservation Entry", true) and
             Gate.IsEnabled(Database::"G/L Entry", true) and Gate.IsEnabled(Database::"G/L Register", true) and
             Gate.IsEnabled(Database::"Warehouse Entry", true) and Gate.IsEnabled(Database::"Warehouse Register", true) and
             Gate.IsEnabled(Database::"Bin Content", true));
    end;

    /// <summary>Uses the isolated write runner; successful production posting commits as one task.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    begin
        if not Validate(Argument, Argument.GetRequestJson()) then
            exit;
        if Argument."Omit Commit" then begin
            Codeunit.Run(Codeunit::"Proj. Item Usage Process ori", Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Proj. Item Usage Process ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>Validates every line and exact native selector before any posting or tracking creation.</summary>
    procedure Validate(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Project: Record Job;
        Task: Record "Job Task";
        Input: Codeunit "Projects Followup Input ori";
        Token: JsonToken;
        Line: JsonObject;
        PostingDate: Date;
    begin
        if not Input.Validate(Argument, Request, Parameters()) then
            exit(false);
        if not IsEnabled() then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl));
        Project.ReadIsolation := IsolationLevel::ReadCommitted;
        Task.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Project.Get(Request.GetText('projectNo')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl));
        if not Task.Get(Project."No.", Request.GetText('taskNo')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', MissingLbl));
        if (Project.Status <> Project.Status::Open) or (Project.Blocked <> Project.Blocked::" ") then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', StatusLbl));
        if Task."Job Task Type" <> Task."Job Task Type"::Posting then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'taskNo', MissingLbl));
        if Request.Contains('postingDate') then begin
            Evaluate(PostingDate, Request.GetText('postingDate'), 9);
            if PostingDate = 0D then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'postingDate', TypeLbl));
        end;
        if Request.GetArray('lines').Count() = 0 then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'lines', LinesLbl));
        foreach Token in Request.GetArray('lines') do begin
            if not Token.IsObject() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'lines', TypeLbl));
            Line := Token.AsObject();
            if not Input.Validate(Argument, Line, LineParameters()) then
                exit(false);
            if Line.GetDecimal('quantity') <= 0 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'quantity', LinesLbl));
            if not ValidateItem(Argument, Line) then
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>Posts only through the native project journal, with no explicit commits inside the task transaction.</summary>
    [CommitBehavior(CommitBehavior::Error)]
    procedure PostNative(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        TempJournal: Record "Job Journal Line" temporary;
        Posting: Codeunit "Job Jnl.-Post Line";
        Capture: Codeunit "Proj. Usage Entry Capture ori";
        Request: JsonObject;
        Line: JsonToken;
        Response: JsonObject;
        Entries: JsonArray;
        Entry: JsonToken;
        EntryNo: Integer;
        FirstEntryNo: Integer;
        LastEntryNo: Integer;
        LineNo: Integer;
        NoEntriesLbl: Label 'Native posting produced no project ledger entries. The task was rolled back.', Comment = 'is-IS=Innbyggð bókun bjó ekki til verkefnisfærslur. Verkið var afturkallað.';
    begin
        Request := Argument.GetRequestJson();
        FirstEntryNo := 0;
        LastEntryNo := 0;
        LineNo := SourceLineNo(Argument.ID);
        Project.LockTable();
        if not Validate(Argument, Request) then
            exit;
        BindSubscription(Capture);
        foreach Line in Request.GetArray('lines') do begin
            LineNo += 1;
            PrepareJournal(Argument.ID, Request, Line.AsObject(), LineNo, TempJournal);
            AssertTrackingKeyAvailable(TempJournal);
            CreateTracking(TempJournal, Line.AsObject());
            Capture.ExpectSource(TempJournal);
            Posting.RunWithCheck(TempJournal);
            AssertTrackingKeyAvailable(TempJournal);
        end;
        UnbindSubscription(Capture);
        Entries := Capture.EntryNos();
        if Entries.Count() = 0 then
            Error(NoEntriesLbl);
        foreach Entry in Entries do begin
            EntryNo := Entry.AsValue().AsInteger();
            if (FirstEntryNo = 0) or (EntryNo < FirstEntryNo) then
                FirstEntryNo := EntryNo;
            if EntryNo > LastEntryNo then
                LastEntryNo := EntryNo;
        end;
        Response.Add('status', 'Success');
        Response.Add('firstEntryNo', FirstEntryNo);
        Response.Add('lastEntryNo', LastEntryNo);
        Response.Add('entryNos', Entries);
        Argument.SetResponseJson(Response);
    end;

    local procedure PrepareJournal(TaskId: Guid; Request: JsonObject; Line: JsonObject; LineNo: Integer; var Journal: Record "Job Journal Line" temporary)
    var
        Project: Record Job;
        Customer: Record Customer;
        Input: Codeunit "Projects Followup Input ori";
        PostingDate: Date;
        DocumentNo: Code[20];
    begin
        Clear(Journal);
        Journal.Init();
        Journal."Journal Batch Name" := CopyStr(DelChr(Format(TaskId, 0, 4), '=', '{}-'), 1, MaxStrLen(Journal."Journal Batch Name"));
        Journal."Line No." := LineNo;
        Journal."Entry Type" := Journal."Entry Type"::Usage;
        Journal.Validate(Type, Journal.Type::Item);
        PostingDate := WorkDate();
        if Request.Contains('postingDate') then
            Evaluate(PostingDate, Request.GetText('postingDate'), 9);
        Journal.Validate("Posting Date", PostingDate);
        DocumentNo := CopyStr(Input.TextValue(Request, 'documentNo'), 1, MaxStrLen(DocumentNo));
        if DocumentNo = '' then
            DocumentNo := CopyStr(DelChr(Format(TaskId, 0, 4), '=', '{}-'), 1, MaxStrLen(DocumentNo));
        Journal.Validate("Document No.", DocumentNo);
        Journal.Validate("Job No.", CopyStr(Request.GetText('projectNo'), 1, MaxStrLen(Journal."Job No.")));
        Journal.Validate("Job Task No.", CopyStr(Request.GetText('taskNo'), 1, MaxStrLen(Journal."Job Task No.")));
        Project.Get(Request.GetText('projectNo'));
        Customer.Get(Project."Bill-to Customer No.");
        Journal.Validate("Gen. Bus. Posting Group", Customer."Gen. Bus. Posting Group");
        Journal.Validate("No.", CopyStr(Line.GetText('itemNo'), 1, MaxStrLen(Journal."No.")));
        if Input.TextValue(Line, 'variantCode') <> '' then
            Journal.Validate("Variant Code", CopyStr(Line.GetText('variantCode'), 1, MaxStrLen(Journal."Variant Code")));
        if Input.TextValue(Line, 'locationCode') <> '' then
            Journal.Validate("Location Code", CopyStr(Line.GetText('locationCode'), 1, MaxStrLen(Journal."Location Code")));
        if Input.TextValue(Line, 'binCode') <> '' then
            Journal.Validate("Bin Code", CopyStr(Line.GetText('binCode'), 1, MaxStrLen(Journal."Bin Code")));
        if Input.TextValue(Line, 'unitOfMeasureCode') <> '' then
            Journal.Validate("Unit of Measure Code", CopyStr(Line.GetText('unitOfMeasureCode'), 1, MaxStrLen(Journal."Unit of Measure Code")));
        Journal.Validate(Quantity, Line.GetDecimal('quantity'));
    end;

    local procedure SourceLineNo(TaskId: Guid) Result: Integer
    var
        TaskText: Text;
        Index: Integer;
        Digit: Integer;
    begin
        TaskText := DelChr(Format(TaskId, 0, 4), '=', '{}-').ToLower();
        Result := 0;
        for Index := 1 to 7 do begin
            Digit := StrPos('0123456789abcdef', CopyStr(TaskText, Index, 1)) - 1;
            Result := (Result * 16) + Digit;
        end;
    end;

    local procedure AssertTrackingKeyAvailable(Journal: Record "Job Journal Line" temporary)
    var
        Existing: Record "Reservation Entry";
        ItemJournal: Record "Item Journal Line";
        TrackingKeyLbl: Label 'The isolated native posting tracking key is in use or was not consumed. Nothing was posted.', Comment = 'is-IS=Einangraði innbyggði bókunarrakningarlykillinn er í notkun eða var ekki notaður að fullu. Ekkert var bókað.';
    begin
        Existing.LockTable();
        Existing.SetSourceFilter(Database::"Job Journal Line", Journal."Entry Type".AsInteger(), Journal."Journal Template Name", Journal."Line No.", false);
        Existing.SetRange("Source Batch Name", Journal."Journal Batch Name");
        if not Existing.IsEmpty() then
            Error(TrackingKeyLbl);
        Existing.Reset();
        Existing.SetSourceFilter(Database::"Item Journal Line", ItemJournal."Entry Type"::"Negative Adjmt.".AsInteger(), '', Journal."Line No.", false);
        Existing.SetRange("Source Batch Name", '');
        if not Existing.IsEmpty() then
            Error(TrackingKeyLbl);
    end;

    local procedure CreateTracking(Journal: Record "Job Journal Line" temporary; Line: JsonObject)
    var
        Existing: Record "Reservation Entry";
        Tracking: Record "Reservation Entry";
        CreateEntry: Codeunit "Create Reserv. Entry";
        Input: Codeunit "Projects Followup Input ori";
        CollisionLbl: Label 'The temporary posting tracking key is already in use. Retry with a new task.', Comment = 'is-IS=Tímabundni bókunarrakningarlykillinn er í notkun. Reyndu aftur með nýju verki.';
    begin
        if (Input.TextValue(Line, 'lotNo') = '') and (Input.TextValue(Line, 'serialNo') = '') then
            exit;
        Existing.LockTable();
        Existing.SetSourceFilter(Database::"Job Journal Line", Journal."Entry Type".AsInteger(), Journal."Journal Template Name", Journal."Line No.", false);
        Existing.SetRange("Source Batch Name", Journal."Journal Batch Name");
        if not Existing.IsEmpty() then
            Error(CollisionLbl);
        Tracking."Lot No." := CopyStr(Input.TextValue(Line, 'lotNo'), 1, MaxStrLen(Tracking."Lot No."));
        Tracking."Serial No." := CopyStr(Input.TextValue(Line, 'serialNo'), 1, MaxStrLen(Tracking."Serial No."));
        CreateEntry.CreateReservEntryFor(Database::"Job Journal Line", Journal."Entry Type".AsInteger(), Journal."Journal Template Name", Journal."Journal Batch Name", 0, Journal."Line No.", Journal."Qty. per Unit of Measure", Journal.Quantity, Journal."Quantity (Base)", Tracking);
        CreateEntry.CreateEntry(Journal."No.", Journal."Variant Code", Journal."Location Code", Journal.Description, 0D, Journal."Posting Date", 0, "Reservation Status"::Surplus);
    end;

    local procedure ValidateItem(var Argument: Record "Message Argument ori"; Line: JsonObject): Boolean
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Bin: Record Bin;
        ItemUOM: Record "Item Unit of Measure";
        Input: Codeunit "Projects Followup Input ori";
        UOMCode: Code[10];
        QuantityPerUOM: Decimal;
    begin
        Item.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Item.Get(Line.GetText('itemNo')) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'itemNo', IdentifierLbl));
        if Input.TextValue(Line, 'variantCode') <> '' then
            if not Variant.Get(Item."No.", Line.GetText('variantCode')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'variantCode', IdentifierLbl));
        if Input.TextValue(Line, 'locationCode') <> '' then
            if not Location.Get(Line.GetText('locationCode')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'locationCode', IdentifierLbl));
        if Input.TextValue(Line, 'binCode') <> '' then
            if not Bin.Get(Input.TextValue(Line, 'locationCode'), Line.GetText('binCode')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'binCode', IdentifierLbl));
        UOMCode := CopyStr(Input.TextValue(Line, 'unitOfMeasureCode'), 1, MaxStrLen(UOMCode));
        if UOMCode = '' then
            UOMCode := Item."Base Unit of Measure";
        QuantityPerUOM := 1;
        if UOMCode <> '' then begin
            if not ItemUOM.Get(Item."No.", UOMCode) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'unitOfMeasureCode', IdentifierLbl));
            QuantityPerUOM := ItemUOM."Qty. per Unit of Measure";
        end;
        if Input.TextValue(Line, 'serialNo') <> '' then
            if Line.GetDecimal('quantity') * QuantityPerUOM <> 1 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'serialNo', LinesLbl));
        exit(true);
    end;
}
