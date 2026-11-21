namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Contract parts shared by the Projects.Usage.* message types.</summary>
codeunit 70013404 "TS Usage Contract ori"
{
    Access = Internal;

    var
        SheetTxt: Label 'The time sheet number.', Comment = 'is-IS=Númer tímaskýrslunnar.';
        LineTxt: Label 'The line number on the time sheet the usage is linked to.', Comment = 'is-IS=Línunúmer á tímaskýrslunni sem notkunin er tengd við.';
        TypeTxt: Label 'Item or Resource.', Comment = 'is-IS=Item eða Resource.';
        NoTxt: Label 'The item or resource number.', Comment = 'is-IS=Vöru- eða aðfangsnúmerið.';
        DateTxt: Label 'The usage date (YYYY-MM-DD), inside the week of the time sheet.', Comment = 'is-IS=Dagsetning notkunar (ÁÁÁÁ-MM-DD), innan viku tímaskýrslunnar.';
        QuantityTxt: Label 'The quantity used, greater than zero.', Comment = 'is-IS=Magnið sem var notað, stærra en núll.';
        UnitTxt: Label 'Optional unit of measure code.', Comment = 'is-IS=Valfrjáls einingarkóði.';
        LocationTxt: Label 'Optional location code the item is taken from (Item usage only).', Comment = 'is-IS=Valfrjáls staðsetningarkóði sem varan er tekin úr (aðeins vörunotkun).';
        BinTxt: Label 'Optional bin code at that location. Needs locationCode.', Comment = 'is-IS=Valfrjáls hólfkóði á þeirri staðsetningu. Krefst locationCode.';
        LotTxt: Label 'Lot number, required when the item tracking code uses lot numbers.', Comment = 'is-IS=Lotunúmer, krafist þegar rekjanleikakóði vörunnar notar lotunúmer.';
        SerialTxt: Label 'Serial number, required when the item tracking code uses serial numbers. Quantity must be 1.', Comment = 'is-IS=Raðnúmer, krafist þegar rekjanleikakóði vörunnar notar raðnúmer. Magn verður að vera 1.';
        DescriptionTxt: Label 'Optional description, at most 100 characters.', Comment = 'is-IS=Valfrjáls lýsing, mest 100 stafir.';
        EntryNosTxt: Label 'Optional array of usage entry numbers. Without it every eligible line of the time sheet is used.', Comment = 'is-IS=Valfrjáls listi af færslunúmerum notkunar. Án hans eru allar gjaldgengar línur tímaskýrslunnar notaðar.';
        CommentTxt: Label 'Optional comment, at most 250 characters.', Comment = 'is-IS=Valfrjáls athugasemd, mest 250 stafir.';
        EntryNoTxt: Label 'The usage entry number.', Comment = 'is-IS=Færslunúmer notkunar.';
        JournalTxt: Label 'Journal template or batch for this kind of usage (item, resource, or job when the sheet line has a project).', Comment = 'is-IS=Færslubókarsniðmát eða keyrsla fyrir þessa tegund notkunar (vara, aðfang eða verk þegar tímaskýrslulínan hefur verkefni).';
        ReverseTxt: Label 'true to also create the reversing journal line.', Comment = 'is-IS=true til að búa einnig til bakfærslulínu í færslubók.';
        StatusTxt: Label 'Optional status filter: Open, Submitted, Approved, Rejected, Transferred or Posted.', Comment = 'is-IS=Valfrjáls stöðusía: Open, Submitted, Approved, Rejected, Transferred eða Posted.';
        PendingTxt: Label 'true for the Submitted lines addressed to the caller as approver.', Comment = 'is-IS=true fyrir innsendar línur sem beinast að kallanda sem samþykktaraðila.';
        PageTxt: Label 'Paging: skip (default 0) and take (default 50, at most 200).', Comment = 'is-IS=Blaðsíðuskipting: skip (sjálfgefið 0) og take (sjálfgefið 50, mest 200).';
        SuccessTxt: Label 'Success after the entire operation succeeds. lines holds the usage lines.', Comment = 'is-IS=Success eftir að öll aðgerðin tekst. lines geymir notkunarlínurnar.';

    /// <summary>Declares the request keys of one operation (1 register, 2 submit, 3 approve, 4 reject, 5 transfer, 6 reverse, 7 list).</summary>
    procedure GetParameters(Operation: Integer; var Parameters: JsonArray): Boolean
    var
        C: Codeunit "Msg Contract Mgt ori";
    begin
        case Operation of
            1:
                begin
                    Parameters.Add(C.Parameter('timeSheetNo', 'string', true, SheetTxt));
                    Parameters.Add(C.Parameter('lineNo', 'integer', true, LineTxt));
                    Parameters.Add(C.Parameter('type', 'string', true, TypeTxt));
                    Parameters.Add(C.Parameter('no', 'string', true, NoTxt));
                    Parameters.Add(C.Parameter('date', 'string', true, DateTxt));
                    Parameters.Add(C.Parameter('quantity', 'number', true, QuantityTxt));
                    Parameters.Add(C.Parameter('unitOfMeasure', 'string', false, UnitTxt));
                    Parameters.Add(C.Parameter('description', 'string', false, DescriptionTxt));
                    Parameters.Add(C.Parameter('locationCode', 'string', false, LocationTxt));
                    Parameters.Add(C.Parameter('binCode', 'string', false, BinTxt));
                    Parameters.Add(C.Parameter('lotNo', 'string', false, LotTxt));
                    Parameters.Add(C.Parameter('serialNo', 'string', false, SerialTxt));
                end;
            2, 3, 4:
                begin
                    Parameters.Add(C.Parameter('timeSheetNo', 'string', true, SheetTxt));
                    Parameters.Add(C.Parameter('entryNos', 'array', false, EntryNosTxt));
                    if Operation = 4 then
                        Parameters.Add(C.Parameter('comment', 'string', false, CommentTxt));
                end;
            5:
                begin
                    Parameters.Add(C.Parameter('timeSheetNo', 'string', false, SheetTxt));
                    Parameters.Add(C.Parameter('entryNos', 'array', false, EntryNosTxt));
                    AddJournalKeys(Parameters);
                end;
            6:
                begin
                    Parameters.Add(C.Parameter('entryNo', 'integer', true, EntryNoTxt));
                    Parameters.Add(C.Parameter('createJournalLine', 'boolean', false, ReverseTxt));
                    AddJournalKeys(Parameters);
                end;
            7:
                begin
                    Parameters.Add(C.Parameter('timeSheetNo', 'string', false, SheetTxt));
                    Parameters.Add(C.Parameter('status', 'string', false, StatusTxt));
                    Parameters.Add(C.Parameter('pending', 'boolean', false, PendingTxt));
                    Parameters.Add(C.Parameter('skip', 'integer', false, PageTxt));
                    Parameters.Add(C.Parameter('take', 'integer', false, PageTxt));
                end;
        end;
        exit(true);
    end;

    local procedure AddJournalKeys(var Parameters: JsonArray)
    var
        C: Codeunit "Msg Contract Mgt ori";
        KeyName: Text;
    begin
        foreach KeyName in 'itemTemplate,itemBatch,resourceTemplate,resourceBatch,jobTemplate,jobBatch'.Split(',') do
            Parameters.Add(C.Parameter(KeyName, 'string', false, JournalTxt));
    end;

    /// <summary>Declares the data-only version 1 envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Declares the stable success response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        Field: JsonObject;
    begin
        Field.Add('name', 'status');
        Field.Add('type', 'string');
        Field.Add('description', SuccessTxt);
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'lines');
        Field.Add('type', 'array');
        Fields.Add(Field);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares the effect: a read for List, a rolled-back write for the others.</summary>
    procedure GetEffect(Operation: Integer; var Effect: JsonObject): Boolean
    begin
        if Operation = 7 then begin
            Effect.Add('effect', 'read');
            Effect.Add('changes', 'Nothing is changed.');
            Effect.Add('idempotent', true);
        end else begin
            Effect.Add('effect', 'write');
            Effect.Add('changes', 'Time sheet usage lines; Transfer and Reverse also create journal lines. Nothing is posted. A failure rolls back the whole request.');
            Effect.Add('idempotent', false);
        end;
        exit(true);
    end;
}
