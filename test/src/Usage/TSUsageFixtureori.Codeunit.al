namespace Origo.Bifrost.Projects.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Projects.Resources.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Projects.TimeSheet;
using Origo.Bifrost.Projects;

/// <summary>Seeds and removes the fixed MCP and UI verification records for usage lines (projects#52). Own tenant only.</summary>
codeunit 97155 "TS Usage Fixture ori"
{
    Access = Internal;

    /// <summary>Creates the fixture sheet XU52FIX1 owned by the current user, one line, one item and one resource.</summary>
    procedure Create()
    var
        Header: Record "Time Sheet Header";
        Item: Record Item;
        Line: Record "Time Sheet Line";
        Resource: Record Resource;
        UnitOfMeasure: Record "Unit of Measure";
    begin
        Remove();
        if not UnitOfMeasure.Get('PCS') then begin
            UnitOfMeasure.Init();
            UnitOfMeasure.Code := 'PCS';
            UnitOfMeasure.Insert();
        end;
        Item.Init();
        Item."No." := 'XU52ITEM';
        Item.Insert(true);
        Item.Description := 'Usage fixture item';
        Item.Validate("Base Unit of Measure", 'PCS');
        Item.Modify(true);
        Resource.Init();
        Resource."No." := 'XU52RES';
        Resource.Insert(true);
        Resource.Name := 'Usage fixture resource';
        Resource.Validate("Base Unit of Measure", 'PCS');
        Resource.Modify(true);
        Header.Init();
        Header."No." := 'XU52FIX1';
        Header."Resource No." := Resource."No.";
        Header."Starting Date" := WorkDate();
        Header."Ending Date" := WorkDate() + 6;
        Header."Owner User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Owner User ID"));
        Header."Approver User ID" := 'XAPPROVER';
        Header.Insert(false);
        Line.Init();
        Line."Time Sheet No." := Header."No.";
        Line."Line No." := 10000;
        Line."Time Sheet Starting Date" := Header."Starting Date";
        Line.Type := Line.Type::Resource;
        Line.Insert(false);
    end;

    /// <summary>Makes the current user the approver and another user the owner of the fixture sheet.</summary>
    procedure SwapToApprover()
    var
        Header: Record "Time Sheet Header";
    begin
        Header.Get('XU52FIX1');
        Header."Owner User ID" := 'XOWNER';
        Header."Approver User ID" := CopyStr(UserId(), 1, MaxStrLen(Header."Approver User ID"));
        Header.Modify(false);
    end;

    /// <summary>Removes the fixture sheet, usage lines, journal lines, item and resource.</summary>
    procedure Remove()
    var
        Header: Record "Time Sheet Header";
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        Line: Record "Time Sheet Line";
        Resource: Record Resource;
        ResJournalLine: Record "Res. Journal Line";
        Usage: Record "TS Usage Line ori";
    begin
        Usage.SetRange("Time Sheet No.", 'XU52FIX1');
        Usage.DeleteAll();
        ItemJournalLine.SetRange("Item No.", 'XU52ITEM');
        ItemJournalLine.DeleteAll();
        ResJournalLine.SetRange("Resource No.", 'XU52RES');
        ResJournalLine.DeleteAll();
        Line.SetRange("Time Sheet No.", 'XU52FIX1');
        Line.DeleteAll();
        if Header.Get('XU52FIX1') then
            Header.Delete(false);
        if Item.Get('XU52ITEM') then
            Item.Delete(true);
        if Resource.Get('XU52RES') then
            Resource.Delete(true);
    end;
}
