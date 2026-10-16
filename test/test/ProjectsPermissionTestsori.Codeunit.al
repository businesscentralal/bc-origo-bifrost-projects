namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Restricted-role tests prove denial before licensing or native writes.</summary>
codeunit 97103 "Projects Permission Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    var
        Assert: Codeunit "Library Assert";
    [Test]
    procedure Scenario_AC01_ReadRole_WithoutNativeRights_Denied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Impl: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Response: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
        Name: Text;
    begin
        // Story #1/#2, AC01 | Time: no date dependency | Risk: None
        // [GIVEN] The caller has the read role, without native project write permission.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        foreach Name in Names do
            if (Ordinals.Get(Names.IndexOf(Name)) >= 10078485) and (Ordinals.Get(Names.IndexOf(Name)) <= 10078584) then begin
                Assert.IsTrue(Name.StartsWith('Projects.'), 'Every owned enum value must use the Projects prefix');
                Clear(TempArgument);
                MessageType := Enum::"Message Type ori".FromInteger(Ordinals.Get(Names.IndexOf(Name)));
                TempArgument.Type := MessageType;
                TempArgument.Version := "Message Version ori"::"1.0";
                TempArgument.Insert(true);
                Impl := MessageType;
                // [WHEN] Each shipping implementation is called.
                Assert.IsFalse(Impl.IsEnabled(), 'Without native rights the role must not advertise enabled operations: ' + Name);
                Impl.ExecuteBifrostTask(TempArgument);
                Response := TempArgument.GetResponseJson();
                // [THEN] PermissionDenied is returned before licensing or input processing.
                Assert.AreEqual('PermissionDenied', Response.GetText('code'), Name + ' must reject the native write');
            end;
    end;
}
