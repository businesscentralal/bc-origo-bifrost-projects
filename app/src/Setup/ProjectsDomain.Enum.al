namespace Origo.Bifrost.Projects;

/// <summary>Projects domains that an administrator turns on per company (#113, Gunnar 27.11.2026).</summary>
enum 70013480 "Projects Domain ori"
{
    Access = Internal;
    Extensible = false;
    Caption = 'Projects Domain', Comment = 'is-IS=Verkefnasvið';

    value(0; ProjectOperations)
    {
        Caption = 'Project operations', Comment = 'is-IS=Verkefnaaðgerðir';
    }
    value(1; TimeSheets)
    {
        Caption = 'Time sheets', Comment = 'is-IS=Tímaskýrslur';
    }
    value(2; TimeSheetUsage)
    {
        Caption = 'Time sheet usage', Comment = 'is-IS=Notkun á tímaskýrslum';
    }
    value(3; FieldService)
    {
        Caption = 'Field service and van', Comment = 'is-IS=Vettvangsþjónusta og bíll';
    }
    value(4; FollowUpRequests)
    {
        Caption = 'Follow-up requests', Comment = 'is-IS=Eftirfylgnibeiðnir';
    }
    value(5; Reports)
    {
        Caption = 'Reports and statistics', Comment = 'is-IS=Skýrslur og tölfræði';
    }
}
