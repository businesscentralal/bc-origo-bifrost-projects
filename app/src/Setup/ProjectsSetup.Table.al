namespace Origo.Bifrost.Projects;

using Microsoft.Projects.Resources.Resource;
using Microsoft.Utilities;

/// <summary>Company switch for Projects messages. Administrators manage it through Projects Setup.</summary>
table 70013500 "Projects Setup ori"
{
    Access = Internal;
    Caption = 'Projects Setup', Comment = 'is-IS=Uppsetning verkefna';
    DataClassification = CustomerContent;
    Extensible = false;
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
        field(10; Enabled; Boolean)
        {
            Caption = 'Enabled', Comment = 'is-IS=Virkt';
            InitValue = true;
        }
        field(20; "Travel Work Type Code"; Code[10])
        {
            Caption = 'Travel Work Type Code', Comment = 'is-IS=Vinnutegund ferðar';
            TableRelation = "Work Type";
        }
        field(21; "Mileage Resource No."; Code[20])
        {
            Caption = 'Mileage Resource No.', Comment = 'is-IS=Akstursforði';
            TableRelation = Resource;
        }
        field(22; "Rounding Minutes"; Integer)
        {
            Caption = 'Rounding Minutes', Comment = 'is-IS=Námundun í mínútum';
            InitValue = 1;
        }
        field(23; "Client Time Tolerance Hours"; Integer)
        {
            Caption = 'Client Time Tolerance Hours', Comment = 'is-IS=Vikmörk biðlaratíma (klst.)';
            InitValue = 24;
        }
        field(24; "Allow Unplanned Tasks"; Boolean)
        {
            Caption = 'Allow Unplanned Tasks', Comment = 'is-IS=Leyfa óáætlaða verkþætti';
        }
        field(30; "Project Operations"; Boolean)
        {
            Caption = 'Project operations', Comment = 'is-IS=Verkefnaaðgerðir';
            ToolTip = 'Specifies whether project, task, planning line, WIP, usage link, item cost and quote message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir verkefni, verkþætti, áætlunarlínur, VÍV, notkunartengingar, vörukostnað og tilboð séu tiltækar í þessu fyrirtæki.';
        }
        field(31; "Time Sheets"; Boolean)
        {
            Caption = 'Time sheets', Comment = 'is-IS=Tímaskýrslur';
            ToolTip = 'Specifies whether time sheet, approval and absence message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir tímaskýrslur, samþykktir og fjarvistir séu tiltækar í þessu fyrirtæki.';
        }
        field(32; "Time Sheet Usage"; Boolean)
        {
            Caption = 'Time sheet usage', Comment = 'is-IS=Notkun á tímaskýrslum';
            ToolTip = 'Specifies whether usage registration, approval, transfer and reversal message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir skráningu, samþykkt, flutning og bakfærslu notkunar séu tiltækar í þessu fyrirtæki.';
        }
        field(33; "Field Service and Van"; Boolean)
        {
            Caption = 'Field service and van', Comment = 'is-IS=Vettvangsþjónusta og bíll';
            ToolTip = 'Specifies whether visit, my day, van stock, visit report and sign-off message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir heimsóknir, daginn minn, bílabirgðir, heimsóknarskýrslur og undirritun séu tiltækar í þessu fyrirtæki.';
        }
        field(34; "Follow-up Requests"; Boolean)
        {
            Caption = 'Follow-up requests', Comment = 'is-IS=Eftirfylgnibeiðnir';
            ToolTip = 'Specifies whether follow-up request message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir eftirfylgnibeiðnir séu tiltækar í þessu fyrirtæki.';
        }
        field(35; "Reports and Statistics"; Boolean)
        {
            Caption = 'Reports and statistics', Comment = 'is-IS=Skýrslur og tölfræði';
            ToolTip = 'Specifies whether project statistics, budget versus actual, report, resource allocation and capacity message types are available in this company.', Comment = 'is-IS=Tilgreinir hvort skilaboðategundir fyrir verkefnatölfræði, áætlun á móti rauntölum, skýrslur, forðaúthlutun og afkastagetu séu tiltækar í þessu fyrirtæki.';
        }
        field(87; "Follow-up Task Increment"; Integer)
        {
            Caption = 'Follow-up Task Increment', Comment = 'is-IS=Hækkun verkþáttanúmers við eftirfylgni';
            ToolTip = 'Specifies the numbering step for a new follow-up task. Zero uses one; the task stays within the original task group.', Comment = 'is-IS=Tilgreinir númerahækkun nýs eftirfylgniverkþáttar. Núll notar einn; verkþátturinn helst innan upprunalegs hóps.';
            MinValue = 0;
            MaxValue = 10000;
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
    /// <summary>Initializes the company switch without changing existing administrator choices.</summary>
    procedure InsertIfNotExists()
    begin
        if Get() then
            exit;
        Init();
        Insert(true);
    end;
    /// <summary>Reports whether a domain is on in this company. A missing setup row counts as off (new companies start with every domain off).</summary>
    procedure IsDomainEnabled(Domain: Enum "Projects Domain ori"): Boolean
    begin
        if not Get() then
            exit(false);
        exit(GetDomain(Domain));
    end;

    /// <summary>Reads one domain switch from the current record.</summary>
    procedure GetDomain(Domain: Enum "Projects Domain ori"): Boolean
    begin
        case Domain of
            Domain::ProjectOperations:
                exit("Project Operations");
            Domain::TimeSheets:
                exit("Time Sheets");
            Domain::TimeSheetUsage:
                exit("Time Sheet Usage");
            Domain::FieldService:
                exit("Field Service and Van");
            Domain::FollowUpRequests:
                exit("Follow-up Requests");
            Domain::Reports:
                exit("Reports and Statistics");
        end;
        exit(false);
    end;

    /// <summary>Sets one domain switch on the current record without saving it.</summary>
    procedure SetDomain(Domain: Enum "Projects Domain ori"; NewValue: Boolean)
    begin
        case Domain of
            Domain::ProjectOperations:
                "Project Operations" := NewValue;
            Domain::TimeSheets:
                "Time Sheets" := NewValue;
            Domain::TimeSheetUsage:
                "Time Sheet Usage" := NewValue;
            Domain::FieldService:
                "Field Service and Van" := NewValue;
            Domain::FollowUpRequests:
                "Follow-up Requests" := NewValue;
            Domain::Reports:
                "Reports and Statistics" := NewValue;
        end;
    end;

    /// <summary>Keeps the 28.1.1 behaviour on upgrade (AC4): a company that had Projects enabled, or had no setup row (which meant enabled), gets every domain on. A company that had Projects switched off keeps every domain off.</summary>
    procedure UpgradeDomainsFromEnabled()
    begin
        if not Get() then begin
            Init();
            Enabled := true;
            SetAllDomains(true);
            Insert(true);
            exit;
        end;
        if not Enabled then
            exit;
        SetAllDomains(true);
        Modify(true);
    end;

    /// <summary>Sets every domain switch on the current record without saving it.</summary>
    procedure SetAllDomains(NewValue: Boolean)
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Projects Domain ori".Ordinals() do
            SetDomain(Enum::"Projects Domain ori".FromInteger(Ordinal), NewValue);
    end;

    /// <summary>A missing setup row leaves Projects enabled without writing during discovery.</summary>
    procedure IsEnabled(): Boolean
    begin
        if not Get() then
            exit(true);
        exit(Enabled);
    end;
}
