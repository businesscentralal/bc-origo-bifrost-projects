namespace Origo.Bifrost.Projects;

/// <summary>State of a time sheet usage line.</summary>
enum 70013400 "TS Usage Status ori"
{
    Extensible = false;
    Caption = 'Usage Status', Comment = 'is-IS=Staða notkunar';

    value(0; Open)
    {
        Caption = 'Open', Comment = 'is-IS=Opin';
    }
    value(1; Submitted)
    {
        Caption = 'Submitted', Comment = 'is-IS=Send inn';
    }
    value(2; Approved)
    {
        Caption = 'Approved', Comment = 'is-IS=Samþykkt';
    }
    value(3; Rejected)
    {
        Caption = 'Rejected', Comment = 'is-IS=Hafnað';
    }
    value(4; Transferred)
    {
        Caption = 'Transferred', Comment = 'is-IS=Flutt í færslubók';
    }
    value(5; Posted)
    {
        Caption = 'Posted', Comment = 'is-IS=Bókað';
    }
}
