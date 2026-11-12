namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Microsoft.Finance.Dimension;
using Microsoft.Projects.Project.Job;

/// <summary>Seeds isolated copy sources and dimensions for public queue acceptance in an owned development container.</summary>
page 97114 "Projects Copy Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Projects Copy Test Fixtures', Comment = 'is-IS=Prófunargögn fyrir afritun verkefna';

    layout
    {
        area(Content)
        {
            field(Manifest; FixtureManifest)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest', Comment = 'is-IS=Skrá yfir prófunargögn';
                ToolTip = 'Specifies the self-created copy source for each verification language.', Comment = 'is-IS=Tilgreinir eigin afritunargrunn fyrir hvert prófunartungumál.';
                Editable = false;
                MultiLine = true;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SeedSources)
            {
                ApplicationArea = All;
                Caption = 'Seed copy fixtures', Comment = 'is-IS=Stofna prófunargögn fyrir afritun';
                ToolTip = 'Creates two isolated source projects with tasks, budget and billable lines and a dimension. Does not write consent or licence state.', Comment = 'is-IS=Stofnar tvö aðskilin grunnverkefni með verkhlutum, áætlunar- og reikningsfærslulínum og vídd. Skráir ekki samþykki eða leyfisgögn.';
                Image = New;
                Enabled = not Seeded;

                trigger OnAction()
                begin
                    SeedFixtures();
                end;
            }
        }
    }

    var
        FixtureManifest: Text;
        Seeded: Boolean;

    local procedure SeedFixtures()
    var
        ManifestObject: JsonObject;
        Sources: JsonArray;
    begin
        SeedSource(Sources, 1033);
        SeedSource(Sources, 1039);
        ManifestObject.Add('sources', Sources);
        ManifestObject.WriteTo(FixtureManifest);
        Seeded := true;
    end;

    local procedure SeedSource(var Sources: JsonArray; Lcid: Integer)
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        DefaultDimension: Record "Default Dimension";
        Library: Codeunit "Projects Test Library ori";
        PlanRequest: JsonObject;
        TaskRequest: JsonObject;
        Source: JsonObject;
        DimensionCode: Code[20];
    begin
        PlanRequest := Library.NewPlanningRequest('Resource');
        PlanRequest.Replace('lineType', 'Budget');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanRequest), 'Success');
        PlanRequest.Replace('lineNo', 20000);
        PlanRequest.Replace('lineType', 'Billable');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.PlanningLine.Create", PlanRequest), 'Success');
        TaskRequest.Add('projectNo', PlanRequest.GetText('projectNo'));
        TaskRequest.Add('taskNo', 'X200');
        TaskRequest.Add('description', 'X Excluded task');
        Library.AssertStatus(Library.ExecuteNative("Message Type ori"::"Projects.Task.Create", TaskRequest), 'Success');
        DimensionCode := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Dimension.Code := DimensionCode;
        Dimension.Name := 'X Copy verification dimension';
        Dimension.Insert(true);
        DimensionValue."Dimension Code" := DimensionCode;
        DimensionValue.Code := 'XVALUE';
        DimensionValue.Name := 'X Copy verification value';
        DimensionValue.Insert(true);
        DefaultDimension."Table ID" := Database::Job;
        DefaultDimension."No." := CopyStr(PlanRequest.GetText('projectNo'), 1, 20);
        DefaultDimension."Dimension Code" := DimensionCode;
        DefaultDimension."Dimension Value Code" := DimensionValue.Code;
        DefaultDimension.Insert(true);
        Source.Add('lcid', Lcid);
        Source.Add('projectNo', PlanRequest.GetText('projectNo'));
        Source.Add('dimensionCode', DimensionCode);
        Source.Add('resourceNo', PlanRequest.GetText('no'));
        Sources.Add(Source);
    end;
}
