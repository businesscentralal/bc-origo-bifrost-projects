namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Foundation.Navigate;
using Origo.Bifrost;

/// <summary>Owns the atomic native planning and purchase boundary, including rollback-only preview.</summary>
codeunit 70013421 "Proj. Plan Purchase Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        Execute(Rec);
    end;

    // Native order planning commits after calculation. Ignore keeps its work inside this Codeunit.Run boundary.
    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure Execute(var Argument: Record "Message Argument ori")
    var
        Project: Record Job;
        Planning: Record "Job Planning Line";
        Selected: Record "Job Planning Line" temporary;
        ReqLine: Record "Requisition Line";
        TempDemand: Record "Unplanned Demand" temporary;
        Demand: Codeunit "Get Unplanned Demand";
        OrderPlanning: Codeunit "Order Planning Mgt.";
        Scope: Codeunit "Proj. Plan Purchase Scope ori";
        Input: Codeunit "Projects Followup Input ori";
        Result: Codeunit "Proj. Plan Purchase Result ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Request: JsonObject;
        Response: JsonObject;
        Summary: JsonObject;
        Proposals: JsonArray;
        Skipped: JsonArray;
        Orders: JsonArray;
        HasItems: Boolean;
        Preview: Boolean;
        MissingLbl: Label 'Select an existing project, task, planning line and vendor.', Comment = 'is-IS=Veldu fyrirliggjandi verkefni, verkhluta, áætlunarlínu og lánardrottin.';
        StatusLbl: Label 'Use an open, unblocked project.', Comment = 'is-IS=Notaðu opið verkefni sem er ekki lokað.';
        ScratchLbl: Label 'Finish or clear your lines on the Order Planning page before retrying.', Comment = 'is-IS=Ljúktu eða hreinsaðu línurnar þínar á síðunni Pöntunaráætlun áður en þú reynir aftur.';
        CountLbl: Label 'project planning lines to order', Comment = 'is-IS=áætlunarlínur verkefnis sem á að panta';
    begin
        BindSubscription(Scope);
        Request := Argument.GetRequestJson();
        if Request.Contains('preview') then
            Preview := Request.GetBoolean('preview');
        Project.LockTable();
        if not Project.Get(Request.GetText('projectNo')) then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', MissingLbl);
            exit;
        end;
        if (Project.Status <> Project.Status::Open) or (Project.Blocked <> Project.Blocked::" ") then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'projectNo', StatusLbl);
            exit;
        end;
        Planning.LockTable();
        if not SelectLines(Argument, Request, Selected) then
            exit;
        if not ValidateOverrides(Argument, Request, Selected) then
            exit;
        ReqLine.LockTable();
        SetOwnScratch(ReqLine);
        if not ReqLine.IsEmpty() then begin
            Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, '', ScratchLbl);
            exit;
        end;
        if Selected.FindSet() then
            repeat
                HasItems := HasItems or ((Selected.Type = Selected.Type::Item) and Selected."Schedule Line");
            until Selected.Next() = 0;
        if HasItems then begin
            // The native planner throws when all demand already has supply. Ask its demand reader first.
            Demand.SetIncludeMetDemandForSpecificJobNo(Project."No.");
            Demand.Run(TempDemand);
            TempDemand.SetRange("Demand Type", TempDemand."Demand Type"::Job);
            TempDemand.SetRange("Demand Order No.", Project."No.");
            TempDemand.SetRange(Level, 1);
            TempDemand.SetFilter("Needed Qty. (Base)", '>0');
            if not TempDemand.IsEmpty() then
                OrderPlanning.PlanSpecificJob(ReqLine, Project."No.");
        end;
        if not BuildProposals(Argument, Request, Selected, Proposals, Skipped) then begin
            Result.Rollback(Argument);
            exit;
        end;
        if not Preview then
            if not ConfirmGate.Confirm(Argument, Proposals.Count(), CountLbl) then begin
                Result.Rollback(Argument);
                exit;
            end;
        if not Preview and (Proposals.Count() > 0) then
            CreateOrders(ReqLine, Project."No.", Orders);
        Summary.Add('planningLineCount', Proposals.Count());
        Summary.Add('purchaseOrderCount', Orders.Count());
        Summary.Add('skippedCount', Skipped.Count());
        Response.Add('status', 'Success');
        Response.Add('projectNo', Project."No.");
        Response.Add('proposals', Proposals);
        Response.Add('purchaseOrders', Orders);
        Response.Add('skipped', Skipped);
        Response.Add('summary', Summary);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
        if Preview then begin
            Result.Rollback(Argument);
            exit;
        end;
        // The locked preflight proved there were no caller lines. These are exclusively this call's scratch rows.
        SetOwnScratch(ReqLine);
        ReqLine.DeleteAll(true);
    end;

    local procedure SetOwnScratch(var ReqLine: Record "Requisition Line")
    begin
        ReqLine.Reset();
        ReqLine.SetRange("Worksheet Template Name", '');
        ReqLine.SetRange("User ID", UserId());
    end;

    local procedure SelectLines(var Argument: Record "Message Argument ori"; Request: JsonObject; var Selected: Record "Job Planning Line" temporary): Boolean
    var
        Planning: Record "Job Planning Line";
        Task: Record "Job Task";
        Input: Codeunit "Projects Followup Input ori";
        Token: JsonToken;
        Numbers: List of [Integer];
        NumberValue: Integer;
        MissingLbl: Label 'Select an existing task or planning line in this project.', Comment = 'is-IS=Veldu fyrirliggjandi verkhluta eða áætlunarlínu í þessu verkefni.';
        FormatLbl: Label 'Use a nonempty array of unique positive whole planning line numbers.', Comment = 'is-IS=Notaðu fylki sem er ekki tómt með einstökum jákvæðum heiltölunúmerum áætlunarlína.';
        AmbiguousLbl: Label 'Select the task instead; the planning line number occurs in more than one task.', Comment = 'is-IS=Veldu verkhlutann í staðinn; númer áætlunarlínunnar kemur fyrir í fleiri en einum verkhluta.';
    begin
        Planning.SetRange("Job No.", Request.GetText('projectNo'));
        if Request.Contains('taskNo') then begin
            if not Task.Get(Request.GetText('projectNo'), Request.GetText('taskNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', MissingLbl));
            Planning.SetRange("Job Task No.", Request.GetText('taskNo'));
        end;
        if Request.Contains('planningLineNos') then begin
            foreach Token in Request.GetArray('planningLineNos') do begin
                if not ReadPositiveInteger(Token, NumberValue) then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineNos', FormatLbl));
                if Numbers.Contains(NumberValue) then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineNos', FormatLbl));
                Numbers.Add(NumberValue);
                Planning.SetRange("Line No.", NumberValue);
                if Planning.IsEmpty() then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'planningLineNos', MissingLbl));
                if Planning.Count() > 1 then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'planningLineNos', AmbiguousLbl));
            end;
            if Numbers.Count() = 0 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineNos', FormatLbl));
            Planning.SetRange("Line No.");
        end;
        if Planning.FindSet() then
            repeat
                if (not Request.Contains('planningLineNos')) or Numbers.Contains(Planning."Line No.") then begin
                    Selected := Planning;
                    Selected.Insert();
                end;
            until Planning.Next() = 0;
        exit(true);
    end;

    local procedure ReadPositiveInteger(Token: JsonToken; var NumberValue: Integer): Boolean
    var
        Raw: Text;
        NumberDecimal: Decimal;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or not Evaluate(NumberDecimal, Raw, 9) then
            exit(false);
        if (NumberDecimal <= 0) or (NumberDecimal > 2147483647) or (NumberDecimal <> Round(NumberDecimal, 1)) then
            exit(false);
        NumberValue := NumberDecimal;
        exit(true);
    end;

    local procedure ValidateOverrides(var Argument: Record "Message Argument ori"; Request: JsonObject; var Selected: Record "Job Planning Line" temporary): Boolean
    var
        Vendor: Record Vendor;
        Input: Codeunit "Projects Followup Input ori";
        Token: JsonToken;
        ValueToken: JsonToken;
        Override: JsonObject;
        Seen: List of [Integer];
        NumberValue: Integer;
        ParameterName: Text;
        Raw: Text;
        FormatLbl: Label 'Each vendor override must contain only a unique positive planningLineNo and a nonempty vendorNo of at most 20 characters.', Comment = 'is-IS=Hver breyting lánardrottins verður að innihalda aðeins einstakt jákvætt planningLineNo og vendorNo sem er ekki tómt og er að hámarki 20 stafir.';
        MissingLbl: Label 'Select an existing vendor and a planning line in the requested scope.', Comment = 'is-IS=Veldu fyrirliggjandi lánardrottin og áætlunarlínu innan umbeðins umfangs.';
    begin
        if not Request.Contains('vendorOverrides') then
            exit(true);
        foreach Token in Request.GetArray('vendorOverrides') do begin
            if not Token.IsObject() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'vendorOverrides', FormatLbl));
            Override := Token.AsObject();
            foreach ParameterName in Override.Keys() do
                if not (ParameterName in ['planningLineNo', 'vendorNo']) then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName, FormatLbl));
            if not Override.Get('planningLineNo', ValueToken) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'planningLineNo', FormatLbl));
            if not ReadPositiveInteger(ValueToken, NumberValue) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineNo', FormatLbl));
            if Seen.Contains(NumberValue) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'planningLineNo', FormatLbl));
            Seen.Add(NumberValue);
            if not Override.Get('vendorNo', ValueToken) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'vendorNo', FormatLbl));
            if not ValueToken.IsValue() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'vendorNo', FormatLbl));
            ValueToken.WriteTo(Raw);
            if not Raw.StartsWith('"') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'vendorNo', FormatLbl));
            if (StrLen(ValueToken.AsValue().AsText()) > 20) or (ValueToken.AsValue().AsText().Trim() = '') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'vendorNo', FormatLbl));
            if not Vendor.Get(ValueToken.AsValue().AsText()) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'vendorNo', MissingLbl));
            Selected.SetRange("Line No.", NumberValue);
            if Selected.IsEmpty() then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'planningLineNo', MissingLbl));
            if Selected.Count() > 1 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'planningLineNo', FormatLbl));
            Selected.SetRange("Line No.");
        end;
        exit(true);
    end;

    local procedure BuildProposals(var Argument: Record "Message Argument ori"; Request: JsonObject; var Selected: Record "Job Planning Line" temporary; var Proposals: JsonArray; var Skipped: JsonArray): Boolean
    var
        ReqLine: Record "Requisition Line";
        Vendor: Record Vendor;
        Input: Codeunit "Projects Followup Input ori";
        Proposal: JsonObject;
        Skip: JsonObject;
        Token: JsonToken;
        VendorNo: Code[20];
        Reason: Text;
        VendorLbl: Label 'Set an unblocked purchase vendor on the item or supply a vendor override.', Comment = 'is-IS=Stilltu virkan innkaupalánardrottin á vörunni eða sendu breytingu á lánardrottni.';
    begin
        SetOwnScratch(ReqLine);
        ReqLine.ModifyAll("Accept Action Message", false);
        Selected.Reset();
        if Selected.FindSet() then
            repeat
                Clear(Reason);
                if Selected.Type <> Selected.Type::Item then
                    Reason := 'notItem'
                else
                    if not Selected."Schedule Line" then
                        Reason := 'billableOnly'
                    else begin
                        ReqLine.SetRange("Demand Type", Database::"Job Planning Line");
                        ReqLine.SetRange("Demand Order No.", Selected."Job No.");
                        ReqLine.SetRange("Demand Line No.", Selected."Job Contract Entry No.");
                        ReqLine.SetFilter(Quantity, '>0');
                        if not ReqLine.FindFirst() then
                            Reason := 'coveredByStockOrSupply'
                        else begin
                            VendorNo := ReqLine."Vendor No.";
                            if Request.Contains('vendorOverrides') then
                                foreach Token in Request.GetArray('vendorOverrides') do
                                    if Token.AsObject().GetInteger('planningLineNo') = Selected."Line No." then
                                        VendorNo := CopyStr(Token.AsObject().GetText('vendorNo'), 1, MaxStrLen(VendorNo));
                            if not Vendor.Get(VendorNo) then
                                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'vendorNo', VendorLbl));
                            if Vendor.Blocked <> Vendor.Blocked::" " then
                                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'vendorNo', VendorLbl));
                            ReqLine.Validate("Replenishment System", ReqLine."Replenishment System"::Purchase);
                            ReqLine.Validate("Vendor No.", VendorNo);
                            ReqLine.Validate(Reserve, false);
                            ReqLine."Accept Action Message" := true;
                            ReqLine.Modify(true);
                            Clear(Proposal);
                            Proposal.Add('planningLineNo', Selected."Line No.");
                            Proposal.Add('taskNo', Selected."Job Task No.");
                            Proposal.Add('itemNo', ReqLine."No.");
                            Proposal.Add('variantCode', ReqLine."Variant Code");
                            Proposal.Add('locationCode', ReqLine."Location Code");
                            Proposal.Add('quantityToOrder', ReqLine.Quantity);
                            Proposal.Add('vendorNo', VendorNo);
                            Proposal.Add('expectedReceiptDate', Format(ReqLine."Due Date", 0, 9));
                            Proposals.Add(Proposal);
                        end;
                    end;
                if Reason <> '' then begin
                    Clear(Skip);
                    Skip.Add('planningLineNo', Selected."Line No.");
                    Skip.Add('taskNo', Selected."Job Task No.");
                    Skip.Add('reason', Reason);
                    Skipped.Add(Skip);
                end;
            until Selected.Next() = 0;
        exit(true);
    end;

    local procedure CreateOrders(var ReqLine: Record "Requisition Line"; ProjectNo: Code[20]; var Orders: JsonArray)
    var
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Documents: Record "Document Entry" temporary;
        MakeOrders: Codeunit "Req. Wksh.-Make Order";
        Order: JsonObject;
        OrderLine: JsonObject;
        Lines: JsonArray;
    begin
        SetOwnScratch(ReqLine);
        ReqLine.SetRange("Demand Order No.", ProjectNo);
        ReqLine.SetRange("Accept Action Message", true);
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.FindFirst();
        Header."Order Date" := WorkDate();
        Header."Posting Date" := WorkDate();
        MakeOrders.Set(Header, WorkDate(), false);
        MakeOrders.SetSuppressCommit(true);
        MakeOrders.SetCreatedDocumentBuffer(Documents);
        MakeOrders.CarryOutBatchAction(ReqLine);
        if Documents.FindSet() then
            repeat
                Header.Get(Header."Document Type"::Order, Documents."Document No.");
                Clear(Order);
                Clear(Lines);
                Order.Add('number', Header."No.");
                Order.Add('vendorNo', Header."Buy-from Vendor No.");
                Line.SetRange("Document Type", Line."Document Type"::Order);
                Line.SetRange("Document No.", Header."No.");
                Line.SetRange(Type, Line.Type::Item);
                if Line.FindSet() then
                    repeat
                        Line.TestField("Job No.", ProjectNo);
                        Line.TestField("Job Task No.");
                        Line.TestField("Job Planning Line No.");
                        Clear(OrderLine);
                        OrderLine.Add('lineNo', Line."Line No.");
                        OrderLine.Add('taskNo', Line."Job Task No.");
                        OrderLine.Add('planningLineNo', Line."Job Planning Line No.");
                        Lines.Add(OrderLine);
                    until Line.Next() = 0;
                Order.Add('lines', Lines);
                Orders.Add(Order);
            until Documents.Next() = 0;
    end;
}
