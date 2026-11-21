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
    /// <summary>A missing setup row leaves Projects enabled without writing during discovery.</summary>
    procedure IsEnabled(): Boolean
    begin
        if not Get() then
            exit(true);
        exit(Enabled);
    end;
}
