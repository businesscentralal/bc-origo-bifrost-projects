namespace Origo.Bifrost.Projects;

using Microsoft.Sales.Document;

/// <summary>Stores the time sheet date of a line invoiced from a project planning line (#71).</summary>
tableextension 70013500 "Sales Line TS Date ori" extends "Sales Line"
{
    fields
    {
        field(70013500; "Time Sheet Date ori"; Date)
        {
            Caption = 'Time Sheet Date', Comment = 'is-IS=Dagsetning vinnuskýrslu';
            ToolTip = 'Specifies the date of the time entry that this line invoices.', Comment = 'is-IS=Tilgreinir dagsetningu tímafærslunnar sem þessi lína reikningsfærir.';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
