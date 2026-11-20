namespace Origo.Bifrost.Projects;

using Microsoft.Sales.Document;

/// <summary>Shows the time sheet date of project-invoiced lines before Description (#71).</summary>
pageextension 70013501 "Sales Cr.Memo Sub. TS Date ori" extends "Sales Cr. Memo Subform"
{
    layout
    {
        addbefore(Description)
        {
            field("Time Sheet Date ori"; Rec."Time Sheet Date ori")
            {
                ApplicationArea = Jobs;
                Editable = false;
                Visible = TimeSheetDateVisible;
                ToolTip = 'Specifies the date of the time entry that this line invoices.', Comment = 'is-IS=Tilgreinir dagsetningu tímafærslunnar sem þessi lína reikningsfærir.';
            }
        }
    }

    var
        TimeSheetDateVisible: Boolean;

    trigger OnOpenPage()
    begin
        TimeSheetDateVisible := TSDateMgt.HasProjectLines(Rec);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        if not TimeSheetDateVisible then
            TimeSheetDateVisible := TSDateMgt.HasProjectLines(Rec);
    end;

    var
        TSDateMgt: Codeunit "Proj. TS Date Mgt ori";
}
