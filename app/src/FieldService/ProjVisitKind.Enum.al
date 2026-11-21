namespace Origo.Bifrost.Projects;

/// <summary>Whether a field visit records travel or work.</summary>
enum 70013435 "Proj. Visit Kind ori"
{
    Extensible = false;
    Caption = 'Visit Kind', Comment = 'is-IS=Tegund heimsóknar';

    value(0; Travel)
    {
        Caption = 'Travel', Comment = 'is-IS=Ferð';
    }
    value(1; Work)
    {
        Caption = 'Work', Comment = 'is-IS=Vinna';
    }
}
