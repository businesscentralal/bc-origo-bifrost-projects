namespace Origo.Bifrost.Projects;

using Microsoft.Inventory.Location;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Warehouse.Structure;

/// <summary>Van location and default bin of one technician resource (projects#84). Read by Projects.VisitItem.Register and Projects.VanStock.Get.</summary>
table 70013470 "Proj. Technician Setup ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'Technician Setup', Comment = 'is-IS=Uppsetning tæknimanns';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Resource No."; Code[20])
        {
            Caption = 'Resource No.', Comment = 'is-IS=Aðfangsnr. starfsmanns';
            TableRelation = Resource;
        }
        field(2; "Van Location Code"; Code[10])
        {
            Caption = 'Van Location Code', Comment = 'is-IS=Staðsetningarkóði bíls';
            TableRelation = Location;
        }
        field(3; "Default Bin Code"; Code[20])
        {
            Caption = 'Default Bin Code', Comment = 'is-IS=Sjálfgefinn hólfkóði';
            TableRelation = Bin.Code where("Location Code" = field("Van Location Code"));
        }
    }

    keys
    {
        key(PK; "Resource No.")
        {
            Clustered = true;
        }
    }
}
