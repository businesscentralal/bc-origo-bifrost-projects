namespace Origo.Bifrost.Projects;

/// <summary>The retained decision on a follow-up request.</summary>
enum 70013446 "Proj. Follow-up Status ori"
{
    Extensible = false;
    /// <summary>Open follow-up request.</summary>
    value(0; Open) { Caption = 'Open', Comment = 'is-IS=Opin'; }
    /// <summary>Converted follow-up request.</summary>
    value(1; Converted) { Caption = 'Converted', Comment = 'is-IS=Umbreytt'; }
    /// <summary>Rejected follow-up request.</summary>
    value(2; Rejected) { Caption = 'Rejected', Comment = 'is-IS=Hafnað'; }
}
