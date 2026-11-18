namespace Origo.Bifrost.Projects;

/// <summary>What a usage line registers: an item or a resource.</summary>
enum 70013401 "TS Usage Type ori"
{
    Extensible = false;
    Caption = 'Usage Type', Comment = 'is-IS=Tegund notkunar';

    value(0; Item)
    {
        Caption = 'Item', Comment = 'is-IS=Vara';
    }
    value(1; Resource)
    {
        Caption = 'Resource', Comment = 'is-IS=Aðfang';
    }
}
