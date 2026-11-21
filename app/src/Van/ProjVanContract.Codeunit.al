namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Contract text for Projects.VisitItem.Register and Projects.VanStock.Get (projects#84).</summary>
codeunit 70013476 "Proj. Van Contract ori"
{
    Access = Internal;

    var
        ProjectNoLbl: Label 'Project number, maximum 20 characters.', Comment = 'is-IS=Númer verkefnis, mest 20 stafir.';
        TaskNoLbl: Label 'Task number, maximum 20 characters.', Comment = 'is-IS=Númer verkþáttar, mest 20 stafir.';
        ItemsLbl: Label 'One to 50 parts. Each has itemNo, reference or description, and quantity. Optional unitOfMeasure, binCode, lotNo, serialNo.', Comment = 'is-IS=Ein til 50 vörur. Hver hefur itemNo, reference eða description og quantity. Valfrjálst unitOfMeasure, binCode, lotNo, serialNo.';
        DateLbl: Label 'Usage date as yyyy-mm-dd. Omitted means today. It must be inside the week of your time sheet.', Comment = 'is-IS=Dagsetning notkunar á sniðinu áááá-mm-dd. Ef sleppt er í dag. Hún verður að vera innan viku tímaskýrslunnar.';
        ClientRequestLbl: Label 'Repeat key, maximum 100 characters. The same key returns the first result and writes nothing new.', Comment = 'is-IS=Endurtekningarlykill, mest 100 stafir. Sami lykill skilar fyrstu niðurstöðu og skrifar ekkert nýtt.';
        ItemFilterLbl: Label 'Optional text. Keeps items whose number or description contains it.', Comment = 'is-IS=Valfrjáls texti. Heldur vörum sem númer eða lýsing inniheldur hann.';
        BelowMinimumLbl: Label 'When true, list only items below their reorder point.', Comment = 'is-IS=Þegar satt, aðeins vörur undir endurpöntunarmörkum.';
        RefusedLbl: Label 'The van parts request cannot be processed.', Comment = 'is-IS=Ekki er hægt að vinna úr beiðni um vörur úr bíl.';
        PermissionNextLbl: Label 'Assign BIFROST Read ori together with PROJ FIELD TECH.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori ásamt PROJ FIELD TECH.';
        MissingNextLbl: Label 'Send the missing key.', Comment = 'is-IS=Sendu lykilinn sem vantar.';
        FormatNextLbl: Label 'Send the key with the documented type and range.', Comment = 'is-IS=Sendu lykilinn með skráðri tegund og bili.';
        UnknownNextLbl: Label 'Remove the unknown key.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn.';
        NotFoundNextLbl: Label 'Use an item, project, task or bin that exists.', Comment = 'is-IS=Notaðu vöru, verkefni, verkþátt eða hólf sem er til.';
        ConflictNextLbl: Label 'Send itemNo or reference, or make both name the same item.', Comment = 'is-IS=Sendu itemNo eða reference, eða láttu bæði nefna sömu vöru.';
        PreconditionNextLbl: Label 'Check the item, the lot or serial number, the time sheet line and that your van location is set up.', Comment = 'is-IS=Athugaðu vöruna, lotu- eða raðnúmerið, tímaskýrslulínuna og að bílstaðsetning þín sé skráð.';
        IsolatedNextLbl: Label 'Run this action outside an uncommitted batch.', Comment = 'is-IS=Keyrðu þessa aðgerð utan óstaðfestrar lotu.';
        RetryNextLbl: Label 'Correct the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu Business Central villuna og reyndu aftur. Engu var breytt.';
        UnmappedNextLbl: Label 'Ask an administrator to set you as the time sheet owner of your resource.', Comment = 'is-IS=Biddu stjórnanda að skrá þig sem eiganda tímaskýrslu á forðanum þínum.';
        NoVanNextLbl: Label 'Ask an administrator to set your van location on the Technician Setup page.', Comment = 'is-IS=Biddu stjórnanda að skrá bílstaðsetningu þína á síðunni Uppsetning tæknimanna.';
        NoSheetNextLbl: Label 'Create the week with Projects.MyTimeSheet.Create.', Comment = 'is-IS=Stofnaðu vikuna með Projects.MyTimeSheet.Create.';
        LockedLineNextLbl: Label 'Use a task whose time sheet line is open or rejected.', Comment = 'is-IS=Notaðu verkþátt þar sem tímaskýrslulínan er opin eða hafnað.';
        ChooseNextLbl: Label 'Send the itemNo of one candidate for each ambiguous input. Nothing was written.', Comment = 'is-IS=Sendu itemNo eins valkosts fyrir hverja óljósa færslu. Engu var skrifað.';
        SerialNextLbl: Label 'Send one line per serial number with quantity 1.', Comment = 'is-IS=Sendu eina línu fyrir hvert raðnúmer með magn 1.';
        TrackedNextLbl: Label 'Send lotNo or serialNo, as the item tracking code requires.', Comment = 'is-IS=Sendu lotNo eða serialNo, eins og rekjanleikakóði vörunnar krefst.';
        BlockedNextLbl: Label 'Use an item that is not blocked.', Comment = 'is-IS=Notaðu vöru sem er ekki lokuð.';
        StatusLbl: Label 'Success, Ambiguous or Error.', Comment = 'is-IS=Success, Ambiguous eða Error.';
        LinesRespLbl: Label 'The open usage lines written, with the van location, bin, lot and serial number.', Comment = 'is-IS=Opnu notkunarlínurnar sem voru skrifaðar, með bílstaðsetningu, hólfi, lotu og raðnúmeri.';
        AmbiguousRespLbl: Label 'Inputs with more than one match and their candidates. When present nothing was written.', Comment = 'is-IS=Færslur með fleiri en eina samsvörun og valkostir þeirra. Þegar til staðar var engu skrifað.';
        ShortagesRespLbl: Label 'Items where the request is more than the van holds after pending usage. The lines are still written.', Comment = 'is-IS=Vörur þar sem beiðnin er meiri en bíllinn á eftir biðnotkun. Línurnar eru samt skrifaðar.';
        SummaryRespLbl: Label 'A short sentence about what was written.', Comment = 'is-IS=Stutt setning um það sem var skrifað.';
        NextRespLbl: Label 'What the caller can do next.', Comment = 'is-IS=Það sem kallandi getur gert næst.';
        LocationRespLbl: Label 'The van location.', Comment = 'is-IS=Bílstaðsetningin.';
        StockRespLbl: Label 'Items at the van with inventory, pending usage, available quantity, bin and below-minimum flag.', Comment = 'is-IS=Vörur í bílnum með birgðir, biðnotkun, tiltækt magn, hólf og merki um undir lágmarki.';

    /// <summary>Declares the VisitItem.Register request keys.</summary>
    procedure AddRegisterParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('projectNo', 'string', true, ProjectNoLbl));
        Parameters.Add(Contract.Parameter('taskNo', 'string', true, TaskNoLbl));
        Parameters.Add(Contract.Parameter('items', 'array', true, ItemsLbl));
        Parameters.Add(Contract.Parameter('date', 'string', false, DateLbl));
        Parameters.Add(Contract.Parameter('clientRequestId', 'string', false, ClientRequestLbl));
    end;

    /// <summary>Declares the VanStock.Get request keys.</summary>
    procedure AddStockParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('itemFilter', 'string', false, ItemFilterLbl));
        Parameters.Add(Contract.Parameter('belowMinimumOnly', 'boolean', false, BelowMinimumLbl));
    end;

    /// <summary>Declares the VisitItem.Register response.</summary>
    procedure AddRegisterResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('lines', 'array', LinesRespLbl));
        Fields.Add(Contract.ResponseField('ambiguous', 'array', AmbiguousRespLbl));
        Fields.Add(Contract.ResponseField('shortages', 'array', ShortagesRespLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryRespLbl));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', NextRespLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares the VanStock.Get response.</summary>
    procedure AddStockResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('location', 'string', LocationRespLbl));
        Fields.Add(Contract.ResponseField('items', 'array', StockRespLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryRespLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents the refusals of both types.</summary>
    procedure AddErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, PermissionNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, MissingNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, FormatNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, UnknownNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, NotFoundNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, ConflictNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, PreconditionNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, RetryNextLbl));
    end;

    procedure RefusedText(): Text
    begin
        exit(RefusedLbl);
    end;

    procedure PermissionNext(): Text
    begin
        exit(PermissionNextLbl);
    end;

    procedure MissingNext(): Text
    begin
        exit(MissingNextLbl);
    end;

    procedure FormatNext(): Text
    begin
        exit(FormatNextLbl);
    end;

    procedure UnknownNext(): Text
    begin
        exit(UnknownNextLbl);
    end;

    procedure NotFoundNext(): Text
    begin
        exit(NotFoundNextLbl);
    end;

    procedure ConflictNext(): Text
    begin
        exit(ConflictNextLbl);
    end;

    procedure PreconditionNext(): Text
    begin
        exit(PreconditionNextLbl);
    end;

    procedure IsolatedNext(): Text
    begin
        exit(IsolatedNextLbl);
    end;

    procedure RetryNext(): Text
    begin
        exit(RetryNextLbl);
    end;

    procedure UnmappedNext(): Text
    begin
        exit(UnmappedNextLbl);
    end;

    procedure NoVanNext(): Text
    begin
        exit(NoVanNextLbl);
    end;

    procedure NoSheetNext(): Text
    begin
        exit(NoSheetNextLbl);
    end;

    procedure LockedLineNext(): Text
    begin
        exit(LockedLineNextLbl);
    end;

    procedure ChooseNext(): Text
    begin
        exit(ChooseNextLbl);
    end;

    procedure SerialNext(): Text
    begin
        exit(SerialNextLbl);
    end;

    procedure TrackedNext(): Text
    begin
        exit(TrackedNextLbl);
    end;

    procedure BlockedNext(): Text
    begin
        exit(BlockedNextLbl);
    end;
}
