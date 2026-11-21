namespace Origo.Bifrost.Projects;

using Origo.Bifrost;

/// <summary>Transfers only a JSON response across an intentional native rollback in the current session.</summary>
codeunit 70013422 "Proj. Plan Purchase Result ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Response: JsonObject;
        Ready: Boolean;
        RollbackErr: Label 'PROJECTS74_ROLLBACK', Locked = true;

    /// <summary>Clears previous results before each request.</summary>
    internal procedure Reset()
    begin
        Clear(Response);
        Ready := false;
    end;

    /// <summary>Stores the completed response and rolls back all native database changes.</summary>
    internal procedure Rollback(var Argument: Record "Message Argument ori")
    begin
        Response := Argument.GetResponseJson();
        Ready := true;
        Error(RollbackErr);
    end;

    /// <summary>Consumes an intentional rollback response exactly once.</summary>
    internal procedure Take(var Value: JsonObject): Boolean
    begin
        if not Ready then
            exit(false);
        Value := Response;
        Reset();
        exit(true);
    end;
}
