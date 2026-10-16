namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Owns isolated native unit-test data. These component tests do not assert feature licensing or shipping MCP acceptance.</summary>
codeunit 97102 "Projects Test Library ori"
{
    Access = Internal;
    /// <summary>Initializes only the owned test company's missing project setup.</summary>
    procedure Initialize()
    var
        JobsSetup: Record "Jobs Setup";
        Setup: Record "Projects Setup ori";
    begin
        if not JobsSetup.Get() then begin
            JobsSetup.Init();
            JobsSetup.Insert(true);
        end;
        Setup.InsertIfNotExists();
        Setup.Enabled := true;
        Setup.Modify(true);
    end;
    /// <summary>Creates a fresh customer and project number for every test.</summary>
    procedure NewProjectRequest() Request: JsonObject
    var
        Customer: Record Customer;
        ProjectNo: Code[20];
    begin
        Initialize();
        ProjectNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(ProjectNo));
        Customer.Init();
        Customer."No." := ProjectNo;
        Customer.Name := 'X Projects unit test';
        Customer.Insert(true);
        Request.Add('projectNo', ProjectNo);
        Request.Add('billToCustomerNo', Customer."No.");
        Request.Add('description', 'X Projects unit test');
    end;
    /// <summary>Runs the native component after validation without initializing licence or backend data.</summary>
    procedure ExecuteNative(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Dispatch: Codeunit "Projects Write ori";
        Kind: Text;
        Operation: Text;
        TypeName: Text;
        Names: List of [Text];
        Ordinals: List of [Integer];
        Parts: List of [Text];
    begin
        TempArgument.Init();
        TempArgument.ID := CreateGuid();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.SetRequestJson(Request);
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        TypeName := Names.Get(Ordinals.IndexOf(MessageType.AsInteger()));
        Parts := TypeName.Split('.');
        Kind := Parts.Get(2);
        Operation := Parts.Get(3);
        Commit();
        Dispatch.Execute(TempArgument, Kind, Operation);
        Response := TempArgument.GetResponseJson();
    end;
    /// <summary>Requires the expected status from the actual JSON response.</summary>
    procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Assert: Codeunit "Library Assert";
    begin
        Assert.AreEqual(Expected, Response.GetText('status'), 'Unexpected native component response: ' + Format(Response));
    end;
}
