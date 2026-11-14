namespace Origo.Bifrost.Projects.Test;

/// <summary>Opening this page seeds the issue #15 MCP fixture in the worker-owned tenant (idempotent).</summary>
page 97141 "Proj. Quote Send Fixture ori"
{
    Caption = 'Projects Quote Send MCP Fixture', Comment = 'is-IS=MCP-prófunargögn fyrir sendingu verkefnistilboðs';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;

    layout
    {
        area(Content)
        {
            field(SeededField; Seeded)
            {
                Caption = 'Seeded', Comment = 'is-IS=Stofnað';
                ToolTip = 'Shows that the XQ15 fixture exists.', Comment = 'is-IS=Sýnir að XQ15-prófunargögnin eru til.';
            }
        }
    }

    trigger OnOpenPage()
    begin
        Codeunit.Run(Codeunit::"Proj. Quote Send Fixture ori");
        Seeded := 'XQ15 fixture ready';
    end;

    var
        Seeded: Text;
}
