namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost;

/// <summary>Runs the standard creation report in one isolated transaction for the validated resource selection.</summary>
codeunit 70013558 "TS Create Writer ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Resource: Record Resource;
        Header: Record "Time Sheet Header";
        CreateTimeSheets: Report "Create Time Sheets";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ResourceToken: JsonToken;
        Resources: JsonArray;
        Created: JsonArray;
        Skipped: JsonArray;
        Existing: Dictionary of [Text, Boolean];
        StartingDate: Date;
        PeriodStart: Date;
        Periods: Integer;
        PeriodIndex: Integer;
        FromPlanning: Boolean;
    begin
        Request := Rec.GetRequestJson();
        Request.Get('startingDate', Token);
        Evaluate(StartingDate, Token.AsValue().AsText(), 9);
        Request.Get('numberOfPeriods', Token);
        Periods := Token.AsValue().AsInteger();
        Request.Get('createLinesFromPlanning', Token);
        FromPlanning := Token.AsValue().AsBoolean();
        Request.Get('resourceNos', Token);
        Resources := Token.AsArray();
        // Serialize the existence check and report insert to avoid duplicate sheets
        // when two create requests address the same resource and period.
        Header.LockTable();
        foreach ResourceToken in Resources do begin
            Resource.Get(ResourceToken.AsValue().AsText());
            for PeriodIndex := 1 to Periods do begin
                PeriodStart := StartingDate + (PeriodIndex - 1) * 7;
                Header.SetRange("Resource No.", Resource."No.");
                Header.SetRange("Starting Date", PeriodStart);
                Header.SetRange("Ending Date", PeriodStart + 6);
                Existing.Add(Resource."No." + ':' + Format(PeriodStart, 0, 9), not Header.IsEmpty());
            end;
        end;
        foreach ResourceToken in Resources do begin
            Resource.Reset();
            Resource.Get(ResourceToken.AsValue().AsText());
            Resource.SetRange("No.", Resource."No.");
            Clear(CreateTimeSheets);
            CreateTimeSheets.InitParameters(StartingDate, Periods, '', FromPlanning, true);
            CreateTimeSheets.SetTableView(Resource);
            CreateTimeSheets.UseRequestPage(false);
            CreateTimeSheets.RunModal();
            for PeriodIndex := 1 to Periods do begin
                PeriodStart := StartingDate + (PeriodIndex - 1) * 7;
                Header.SetRange("Resource No.", Resource."No.");
                Header.SetRange("Starting Date", PeriodStart);
                Header.SetRange("Ending Date", PeriodStart + 6);
                Header.FindFirst();
                if Existing.Get(Resource."No." + ':' + Format(PeriodStart, 0, 9)) then
                    Skipped.Add(SheetNode(Header))
                else
                    Created.Add(SheetNode(Header));
            end;
        end;
        Response.Add('status', 'Success');
        Response.Add('created', Created);
        Response.Add('skipped', Skipped);
        Rec.SetResponseJson(Response);
    end;

    local procedure SheetNode(Header: Record "Time Sheet Header") Node: JsonObject
    begin
        Node.Add('timeSheetNo', Header."No.");
        Node.Add('resourceNo', Header."Resource No.");
        Node.Add('startingDate', Format(Header."Starting Date", 0, 9));
        Node.Add('endingDate', Format(Header."Ending Date", 0, 9));
    end;
}
