namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Discovery schema for the approved visit report and signature operations.</summary>
codeunit 70013465 "Proj. Visit Sign Contract ori"
{
    Access = Internal;
    var
        VisitLbl: Label 'Visit number, or send projectNo, taskNo and date.', Comment = 'is-IS=Númer heimsóknar, eða sendu projectNo, taskNo og date.';
        ProjectLbl: Label 'Project number. Must match visitId when both are sent.', Comment = 'is-IS=Verkefnisnúmer. Verður að samsvara visitId þegar hvort tveggja er sent.';
        TaskLbl: Label 'Task number.', Comment = 'is-IS=Númer verkþáttar.';
        DateLbl: Label 'Visit date in YYYY-MM-DD format.', Comment = 'is-IS=Dagsetning heimsóknar á sniðinu YYYY-MM-DD.';
        SignerLbl: Label 'Name of the customer who signed, up to 100 characters.', Comment = 'is-IS=Nafn viðskiptavinar sem undirritaði, allt að 100 stafir.';
        StagingLbl: Label 'Your staged PNG or JPEG customer signature, at most 5 MiB.', Comment = 'is-IS=PNG- eða JPEG-undirskrift viðskiptavinar í bráðabirgðageymslu þinni, mest 5 MiB.';
        PhotosLbl: Label 'Up to ten staged PNG or JPEG photos. All files are consumed atomically.', Comment = 'is-IS=Allt að tíu PNG- eða JPEG-ljósmyndir í bráðabirgðageymslu. Allar skrár eru teknar í einni færslu.';
        RequestLbl: Label 'Unique request id. Retry the same signature with this id.', Comment = 'is-IS=Einkvæmt auðkenni beiðni. Endurtaktu sömu undirskrift með þessu auðkenni.';
        ResponseLbl: Label 'Visit, usage quantities, recipient, report, summary and next steps.', Comment = 'is-IS=Heimsókn, notkunarmagn, viðtakandi, skýrsla, samantekt og næstu skref.';
        RefusalLbl: Label 'Use your completed visit and a valid staged customer signature.', Comment = 'is-IS=Notaðu lokna heimsókn þína og gilda undirskrift viðskiptavinar í bráðabirgðageymslu.';

    /// <summary>Describes every accepted request key.</summary>
    procedure AddParameters(var Parameters: JsonArray; Sign: Boolean)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('visitId', 'integer', false, VisitLbl));
        Parameters.Add(Contract.Parameter('projectNo', 'string', false, ProjectLbl));
        Parameters.Add(Contract.Parameter('taskNo', 'string', false, TaskLbl));
        Parameters.Add(Contract.Parameter('date', 'string', false, DateLbl));
        if not Sign then
            exit;
        Parameters.Add(Contract.Parameter('signerName', 'string', true, SignerLbl));
        Parameters.Add(Contract.Parameter('signatureStagingId', 'string', true, StagingLbl));
        Parameters.Add(Contract.Parameter('photoStagingIds', 'array', false, PhotosLbl));
        Parameters.Add(Contract.Parameter('clientRequestId', 'string', true, RequestLbl));
    end;

    /// <summary>Describes the compact response.</summary>
    procedure AddResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('visit', 'object', ResponseLbl));
        Fields.Add(Contract.ResponseField('usageLines', 'array', ResponseLbl));
        Fields.Add(Contract.ResponseField('recipient', 'string', ResponseLbl));
        Fields.Add(Contract.ResponseField('report', 'object', ResponseLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', ResponseLbl));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', ResponseLbl));
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents typed refusals.</summary>
    procedure AddErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusalLbl, RefusalLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusalLbl, RefusalLbl));
    end;
}
