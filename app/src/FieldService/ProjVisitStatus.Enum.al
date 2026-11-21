namespace Origo.Bifrost.Projects;

/// <summary>State of one field visit.</summary>
enum 70013434 "Proj. Visit Status ori"
{
    Extensible = false;
    Caption = 'Visit Status', Comment = 'is-IS=Staða heimsóknar';

    value(0; Running)
    {
        Caption = 'Running', Comment = 'is-IS=Í gangi';
    }
    value(1; Stopped)
    {
        Caption = 'Stopped', Comment = 'is-IS=Stöðvuð';
    }
    value(2; Completed)
    {
        Caption = 'Completed', Comment = 'is-IS=Lokið';
    }
}
