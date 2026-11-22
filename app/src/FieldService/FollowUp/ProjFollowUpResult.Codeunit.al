namespace Origo.Bifrost.Projects;

/// <summary>Holds only the current session's intentional preview result across rollback.</summary>
codeunit 70013456 "Proj. Follow-up Result ori"
{
    Access = Internal;
    SingleInstance = true;
    var
        Result: JsonObject;
        Ready: Boolean;

    /// <summary>Clears any previous result before starting an operation.</summary>
    procedure Reset()
    begin
        Clear(Result);
        Ready := false;
    end;

    /// <summary>Stores a completed preview immediately before its rollback.</summary>
    procedure SetResult(NewResult: JsonObject)
    begin
        Result := NewResult;
        Ready := true;
    end;

    /// <summary>Consumes a completed preview result exactly once.</summary>
    procedure Take(var NewResult: JsonObject): Boolean
    begin
        if not Ready then
            exit(false);
        NewResult := Result;
        Reset();
        exit(true);
    end;
}
