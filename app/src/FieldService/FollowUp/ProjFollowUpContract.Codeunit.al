namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Declares the follow-up input, output and refusal contracts.</summary>
codeunit 70013454 "Proj. Follow-up Contract ori"
{
    Access = Internal;
    var
        ProjectLbl: Label 'Project number.', Comment = 'is-IS=Verkefnisnúmer.';
        TaskLbl: Label 'Original or destination task number. A new task number defaults to the next unused number after the original task.', Comment = 'is-IS=Upprunalegur eða nýr verkþáttur. Nýr verkþáttur fær sjálfgefið næsta lausa númer á eftir upprunalegum verkþætti.';
        DescriptionLbl: Label 'Work or part description.', Comment = 'is-IS=Lýsing vinnu eða varahlutar.';
        HoursLbl: Label 'Estimated hours, greater than zero when supplied.', Comment = 'is-IS=Áætlaðar stundir, stærri en núll ef gefnar.';
        DateLbl: Label 'Preferred date as YYYY-MM-DD.', Comment = 'is-IS=Óskadagsetning sem YYYY-MM-DD.';
        UrgencyLbl: Label 'Urgency: low, normal or high. Default normal.', Comment = 'is-IS=Forgangur: low, normal eða high. Sjálfgefið normal.';
        ClientLbl: Label 'Optional idempotency key for this technician, up to 100 characters.', Comment = 'is-IS=Valfrjáls endurtekningarlykill þessa tæknimanns, allt að 100 stafir.';
        ItemsLbl: Label 'Parts requested, each with itemNo or description and positive quantity.', Comment = 'is-IS=Umbeðnir varahlutir, hver með itemNo eða description og jákvætt magn.';
        ItemLbl: Label 'Existing item number, or leave empty for a descriptive planning line.', Comment = 'is-IS=Fyrirliggjandi vörunúmer, eða tómt fyrir lýsandi áætlunarlínu.';
        QtyLbl: Label 'Requested quantity, greater than zero.', Comment = 'is-IS=Umbeðið magn, stærra en núll.';
        PhotosLbl: Label 'Up to 10 own Foundation upload ids. Bytes are retained with the request.', Comment = 'is-IS=Allt að 10 eigin innhleðsluauðkenni Foundation. Innihald er vistað með beiðninni.';
        StatusLbl: Label 'Open, Converted or Rejected.', Comment = 'is-IS=Open, Converted eða Rejected.';
        SkipLbl: Label 'Number to skip, default zero.', Comment = 'is-IS=Fjöldi sem á að sleppa, sjálfgefið núll.';
        TakeLbl: Label 'Number to return, from 1 to 100; default 50.', Comment = 'is-IS=Fjöldi til að skila, frá 1 til 100; sjálfgefið 50.';
        ResourceLbl: Label 'Technician resource. List defaults to your resource for technicians; Convert defaults to the request resource.', Comment = 'is-IS=Forði tæknimanns. List notar sjálfgefið eigin forða tæknimanns; Convert notar forða beiðninnar.';
        IdLbl: Label 'Follow-up request number.', Comment = 'is-IS=Númer eftirfylgnibeiðni.';
        TargetLbl: Label 'newTask or existingTask. The manager decides where work belongs.', Comment = 'is-IS=newTask eða existingTask. Stjórnandi ákveður hvar vinnan á heima.';
        PreviewLbl: Label 'True validates conversion and returns the proposed work without retaining any writes.', Comment = 'is-IS=True sannreynir umbreytingu og skilar fyrirhugaðri vinnu án þess að vista breytingar.';
        ReasonLbl: Label 'Reason for rejecting the open request.', Comment = 'is-IS=Ástæða höfnunar opinnar beiðni.';
        RefusedLbl: Label 'The follow-up request could not be processed.', Comment = 'is-IS=Ekki tókst að vinna úr eftirfylgnibeiðninni.';
        NextLbl: Label 'Check the request fields and your project permissions, then retry. Nothing was changed.', Comment = 'is-IS=Athugaðu reiti beiðninnar og verkefnaheimildir þínar og reyndu aftur. Engu var breytt.';
        SummaryLbl: Label 'A short description of the result.', Comment = 'is-IS=Stutt lýsing á niðurstöðu.';

    /// <summary>Builds the schema for one of the four operations.</summary>
    procedure AddParameters(var Parameters: JsonArray; Operation: Integer)
    var
        Children: JsonArray;
        Input: Codeunit "Projects Followup Input ori";
        Parameter: JsonObject;
    begin
        case Operation of
            1:
                begin
                    Parameters.Add(Input.Parameter('projectNo', 'string', true, ProjectLbl, 20));
                    Parameters.Add(Input.Parameter('taskNo', 'string', true, TaskLbl, 20));
                    Parameters.Add(Input.Parameter('description', 'string', true, DescriptionLbl, 100));
                    Parameters.Add(Input.Parameter('estimatedHours', 'number', false, HoursLbl, 0));
                    Parameters.Add(Input.Parameter('preferredDate', 'date', false, DateLbl, 0));
                    Parameters.Add(Input.Parameter('urgency', 'string', false, UrgencyLbl, 20));
                    Parameters.Add(Input.Parameter('clientRequestId', 'string', false, ClientLbl, 100));
                    Children.Add(Input.Parameter('itemNo', 'string', false, ItemLbl, 20));
                    Children.Add(Input.Parameter('description', 'string', false, DescriptionLbl, 100));
                    Children.Add(Input.Parameter('quantity', 'number', true, QtyLbl, 0));
                    Parameter := Input.Parameter('items', 'array', false, ItemsLbl, 0);
                    Parameter.Add('children', Children);
                    Parameters.Add(Parameter);
                    Parameters.Add(Input.Parameter('stagingIds', 'array', false, PhotosLbl, 0));
                end;
            2:
                begin
                    Parameters.Add(Input.Parameter('projectNo', 'string', false, ProjectLbl, 20));
                    Parameters.Add(Input.Parameter('status', 'string', false, StatusLbl, 20));
                    Parameters.Add(Input.Parameter('resourceNo', 'string', false, ResourceLbl, 20));
                    Parameters.Add(Input.Parameter('skip', 'integer', false, SkipLbl, 0));
                    Parameters.Add(Input.Parameter('take', 'integer', false, TakeLbl, 0));
                end;
            3:
                begin
                    Parameters.Add(Input.Parameter('requestId', 'integer', true, IdLbl, 0));
                    Parameters.Add(Input.Parameter('target', 'string', true, TargetLbl, 20));
                    Parameters.Add(Input.Parameter('taskNo', 'string', false, TaskLbl, 20));
                    Parameters.Add(Input.Parameter('resourceNo', 'string', false, ResourceLbl, 20));
                    Parameters.Add(Input.Parameter('preview', 'boolean', false, PreviewLbl, 0));
                end;
            4:
                begin
                    Parameters.Add(Input.Parameter('requestId', 'integer', true, IdLbl, 0));
                    Parameters.Add(Input.Parameter('reason', 'string', true, ReasonLbl, 250));
                end;
        end;
    end;

    /// <summary>Documents common response fields and retained request status.</summary>
    procedure AddResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success or Error.'));
        Fields.Add(Contract.ResponseField('requestId', 'integer', IdLbl));
        Fields.Add(Contract.ResponseField('requestStatus', 'string', StatusLbl));
        Fields.Add(Contract.ResponseField('requests', 'array', 'Visible requests with project, task, resource, items and decision keys.'));
        Fields.Add(Contract.ResponseField('created', 'object', 'Task and planningLines with their native keys; proposed only in preview.'));
        Fields.Add(Contract.ResponseField('preview', 'boolean', PreviewLbl));
        Fields.Add(Contract.ResponseField('summary', 'string', SummaryLbl));
        Fields.Add(Contract.ResponseField('nextSteps', 'array', 'Suggested next operations for the caller.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents stable Foundation refusal codes.</summary>
    procedure AddErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, RefusedLbl, NextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedLbl, NextLbl));
    end;
}
