namespace Origo.Bifrost.Projects;

using Microsoft.Projects.TimeSheet;

/// <summary>Runs native line creation atomically; failure rolls back all newly added lines.</summary>
codeunit 70013562 "TS Fill Runner ori"
{
    Access = Internal;

    trigger OnRun()
    var
        Header: Record "Time Sheet Header";
        Line: Record "Time Sheet Line";
        Context: Codeunit "TS Fill Context ori";
        NativeMgt: Codeunit "TS Fill Mgt ori";
        TimeSheetMgt: Codeunit "Time Sheet Management";
        Lines: JsonArray;
        Node: JsonObject;
        Response: JsonObject;
        BeforeLines: List of [Integer];
        ResultText: Text;
        Created: Integer;
    begin
        if not NativeMgt.CanFillLines(Context.GetFromPlanning()) then
            Error(PermissionErr);
        // Serialize number allocation and recheck ownership in the write transaction.
        Header.LockTable();
        Header.Get(Context.GetSheetNo());
        Header.TestField("Owner User ID", UserId());
        Line.LockTable();
        Line.SetRange("Time Sheet No.", Header."No.");
        if Line.FindSet() then
            repeat
                BeforeLines.Add(Line."Line No.");
            until Line.Next() = 0;
        if Context.GetFromPlanning() then
            TimeSheetMgt.CreateLinesFromJobPlanning(Header)
        else
            TimeSheetMgt.CopyPrevTimeSheetLines(Header);
        if Line.FindSet() then
            repeat
                if not BeforeLines.Contains(Line."Line No.") then begin
                    Clear(Node);
                    Node.Add('timeSheetNo', Line."Time Sheet No.");
                    Node.Add('lineNo', Line."Line No.");
                    Node.Add('status', Line.Status.Names().Get(Line.Status.Ordinals().IndexOf(Line.Status.AsInteger())));
                    Node.Add('lineType', Line.Type.Names().Get(Line.Type.Ordinals().IndexOf(Line.Type.AsInteger())));
                    Node.Add('changed', true);
                    Lines.Add(Node);
                    Created += 1;
                end;
            until Line.Next() = 0;
        Response.Add('status', 'Success');
        if Context.GetFromPlanning() then
            Response.Add('created', Created)
        else
            Response.Add('copied', Created);
        Response.Add('lines', Lines);
        Response.WriteTo(ResultText);
        Context.SetResult(ResultText);
    end;

    var
        PermissionErr: Label 'Time sheet permissions changed. Retry with the required permission set.', Comment = 'is-IS=Tímaskýrsluheimildir breyttust. Reyndu aftur með nauðsynlegri heimildasamstæðu.';
}
