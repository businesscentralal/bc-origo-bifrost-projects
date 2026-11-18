namespace Origo.Bifrost.Projects;

/// <summary>
/// Session state for one usage write. The runner reads it inside Codeunit.Run so a failed
/// write rolls back and the manager maps the failure to a clean refusal.
/// </summary>
codeunit 70013401 "TS Usage Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Operation: Integer;
        Params: JsonObject;
        ResultText: Text;

    /// <summary>Stores the operation (1 register, 2 submit, 3 approve, 4 reject, 5 transfer, 6 reverse) and its validated parameters.</summary>
    procedure SetOperation(NewOperation: Integer; NewParams: JsonObject)
    begin
        ClearAll();
        Operation := NewOperation;
        Params := NewParams;
    end;

    /// <summary>Returns the operation number.</summary>
    procedure GetOperation(): Integer
    begin
        exit(Operation);
    end;

    /// <summary>Returns the validated parameters.</summary>
    procedure GetParams(): JsonObject
    begin
        exit(Params);
    end;

    /// <summary>Stores the response JSON text.</summary>
    procedure SetResult(NewResult: Text)
    begin
        ResultText := NewResult;
    end;

    /// <summary>Returns the response JSON text.</summary>
    procedure GetResult(): Text
    begin
        exit(ResultText);
    end;

    /// <summary>Clears the stored state.</summary>
    procedure Clear()
    begin
        ClearAll();
    end;
}
