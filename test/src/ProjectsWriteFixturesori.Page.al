namespace Origo.Bifrost.Projects.Test;

/// <summary>Seeds only owned issue 2 business masters for public queue and Web Client verification.</summary>
page 97112 "Projects Write Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Projects Write Test Fixtures', Comment = 'is-IS=Prófunargögn fyrir skráningu verkefna';
    layout
    {
        area(Content)
        {
            field(Manifest; FixtureManifest)
            {
                ApplicationArea = All;
                Caption = 'Fixture manifest', Comment = 'is-IS=Skrá yfir prófunargögn';
                ToolTip = 'Specifies the self-created business masters for isolated Projects write verification.', Comment = 'is-IS=Tilgreinir eigin stofngögn fyrir aðskilda prófun á skráningu verkefna.';
                Editable = false;
                MultiLine = true;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(SeedMasters)
            {
                ApplicationArea = All;
                Caption = 'Seed write fixtures', Comment = 'is-IS=Stofna prófunargögn fyrir skráningu';
                ToolTip = 'Creates customers and resource, item and G/L account masters in the worker-owned container. It does not write licence or consent data.', Comment = 'is-IS=Stofnar viðskiptamenn, forða, vörur og fjárhagsreikninga í prófunarumhverfi starfsmanns. Skráir ekki leyfis- eða samþykkisgögn.';
                Image = New;
                Enabled = not Seeded;
                trigger OnAction()
                var
                    Fixtures: JsonArray;
                    Manifest: JsonObject;
                begin
                    SeedMaster(Fixtures, 'Resource');
                    SeedMaster(Fixtures, 'Item');
                    SeedMaster(Fixtures, 'G/L Account');
                    Manifest.Add('fixtures', Fixtures);
                    Manifest.Add('seedSucceeded', true);
                    Manifest.WriteTo(FixtureManifest);
                    Seeded := true;
                    CurrPage.Update(false);
                end;
            }
        }
    }
    var
        FixtureManifest: Text;
        Seeded: Boolean;

    local procedure SeedMaster(var Fixtures: JsonArray; Kind: Text)
    var
        Library: Codeunit "Projects Test Library ori";
        Fixture: JsonObject;
        Request: JsonObject;
        CustomerNo: Code[20];
        MasterNo: Code[20];
    begin
        Request := Library.NewProjectRequest();
        CustomerNo := CopyStr(Request.GetText('billToCustomerNo'), 1, MaxStrLen(CustomerNo));
        MasterNo := Library.SeedPlanningMaster(CustomerNo, Kind);
        Fixture.Add('kind', Kind);
        Fixture.Add('customerNo', CustomerNo);
        Fixture.Add('masterNo', MasterNo);
        Fixtures.Add(Fixture);
    end;
}
