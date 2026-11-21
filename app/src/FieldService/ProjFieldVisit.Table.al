namespace Origo.Bifrost.Projects;

/// <summary>
/// One field visit for a resource. Status, times, hours and time sheet keys change only through
/// Projects.Visit.Start, Projects.Visit.Stop and Projects.Visit.Complete.
/// </summary>
table 70013433 "Proj. Field Visit ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'Field Visit', Comment = 'is-IS=Vettvangsheimsókn';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "Resource No."; Code[20])
        {
            Caption = 'Resource No.', Comment = 'is-IS=Aðfangsnr. starfsmanns';
        }
        field(3; "Project No."; Code[20])
        {
            Caption = 'Project No.', Comment = 'is-IS=Verkefnisnr.';
        }
        field(4; "Task No."; Code[20])
        {
            Caption = 'Task No.', Comment = 'is-IS=Verkþáttanr.';
        }
        field(5; Date; Date)
        {
            Caption = 'Date', Comment = 'is-IS=Dagsetning';
        }
        field(6; Kind; Enum "Proj. Visit Kind ori")
        {
            Caption = 'Kind', Comment = 'is-IS=Tegund';
        }
        field(7; "Started At"; DateTime)
        {
            Caption = 'Started At', Comment = 'is-IS=Hófst';
        }
        field(8; "Stopped At"; DateTime)
        {
            Caption = 'Stopped At', Comment = 'is-IS=Stöðvaðist';
        }
        field(9; "Hours Written"; Decimal)
        {
            Caption = 'Hours Written', Comment = 'is-IS=Skrifaðar stundir';
            DecimalPlaces = 0 : 5;
        }
        field(10; "Time Sheet No."; Code[20])
        {
            Caption = 'Time Sheet No.', Comment = 'is-IS=Tímaskýrslunr.';
        }
        field(11; "Time Sheet Line No."; Integer)
        {
            Caption = 'Time Sheet Line No.', Comment = 'is-IS=Línunr. tímaskýrslu';
        }
        field(12; Status; Enum "Proj. Visit Status ori")
        {
            Caption = 'Status', Comment = 'is-IS=Staða';
        }
        field(13; Outcome; Text[250])
        {
            Caption = 'Outcome', Comment = 'is-IS=Niðurstaða';
        }
        field(14; Note; Text[250])
        {
            Caption = 'Note', Comment = 'is-IS=Athugasemd';
        }
        field(15; "Client Request Id"; Text[100])
        {
            Caption = 'Client Request Id', Comment = 'is-IS=Auðkenni beiðni';
        }
        field(16; "Request Id 1"; Text[100])
        {
            Caption = 'Request Id 1', Comment = 'is-IS=Beiðniauðkenni 1';
        }
        field(17; "Request Result 1"; Text[500])
        {
            Caption = 'Request Result 1', Comment = 'is-IS=Niðurstaða beiðni 1';
        }
        field(18; "Request Id 2"; Text[100])
        {
            Caption = 'Request Id 2', Comment = 'is-IS=Beiðniauðkenni 2';
        }
        field(19; "Request Result 2"; Text[500])
        {
            Caption = 'Request Result 2', Comment = 'is-IS=Niðurstaða beiðni 2';
        }
        field(20; "Request Id 3"; Text[100])
        {
            Caption = 'Request Id 3', Comment = 'is-IS=Beiðniauðkenni 3';
        }
        field(21; "Request Result 3"; Text[500])
        {
            Caption = 'Request Result 3', Comment = 'is-IS=Niðurstaða beiðni 3';
        }
        field(22; "Usage Entry No."; Integer)
        {
            Caption = 'Usage Entry No.', Comment = 'is-IS=Færslunr. notkunar';
        }
        field(23; "Signer Name"; Text[100])
        {
            Caption = 'Signer Name', Comment = 'is-IS=Nafn undirritanda';
        }
        field(24; "Signed At"; DateTime)
        {
            Caption = 'Signed At', Comment = 'is-IS=Undirritað þann';
        }
        field(25; "Signature Id"; Guid)
        {
            Caption = 'Signature Id', Comment = 'is-IS=Auðkenni undirskriftar';
        }
        field(26; "Signed"; Boolean)
        {
            Caption = 'Signed', Comment = 'is-IS=Undirritað';
        }
        field(27; "Locked"; Boolean)
        {
            Caption = 'Locked', Comment = 'is-IS=Læst';
        }
        field(28; "Signature"; Blob)
        {
            Caption = 'Signature', Comment = 'is-IS=Undirskrift';
        }
        field(29; "Signature Content Type"; Text[100])
        {
            Caption = 'Signature Content Type', Comment = 'is-IS=Efnisgerð undirskriftar';
        }
        field(30; "Signature File Name"; Text[250])
        {
            Caption = 'Signature File Name', Comment = 'is-IS=Skráarheiti undirskriftar';
        }
        field(31; "Sign Request Id"; Text[100])
        {
            Caption = 'Sign Request Id', Comment = 'is-IS=Auðkenni undirritunarbeiðni';
        }
        field(32; Photos; MediaSet)
        {
            Caption = 'Photos', Comment = 'is-IS=Ljósmyndir';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(UsageBoundary; "Time Sheet No.", "Time Sheet Line No.", Date)
        {
        }
        key(ResourceStatus; "Resource No.", Status)
        {
        }
    }

    /// <summary>Stores one client request id and its compact JSON result in the first free slot.</summary>
    procedure StoreRequest(RequestId: Text; ResultText: Text)
    begin
        if RequestId = '' then
            exit;
        if "Request Id 1" = '' then begin
            "Request Id 1" := CopyStr(RequestId, 1, MaxStrLen("Request Id 1"));
            "Request Result 1" := CopyStr(ResultText, 1, MaxStrLen("Request Result 1"));
            exit;
        end;
        if "Request Id 2" = '' then begin
            "Request Id 2" := CopyStr(RequestId, 1, MaxStrLen("Request Id 2"));
            "Request Result 2" := CopyStr(ResultText, 1, MaxStrLen("Request Result 2"));
            exit;
        end;
        "Request Id 3" := CopyStr(RequestId, 1, MaxStrLen("Request Id 3"));
        "Request Result 3" := CopyStr(ResultText, 1, MaxStrLen("Request Result 3"));
    end;

    /// <summary>Returns the stored JSON result when this row holds the request id.</summary>
    procedure TryGetRequest(RequestId: Text; var ResultText: Text): Boolean
    begin
        if RequestId = '' then
            exit(false);
        if "Request Id 1" = RequestId then begin
            ResultText := "Request Result 1";
            exit(ResultText <> '');
        end;
        if "Request Id 2" = RequestId then begin
            ResultText := "Request Result 2";
            exit(ResultText <> '');
        end;
        if "Request Id 3" = RequestId then begin
            ResultText := "Request Result 3";
            exit(ResultText <> '');
        end;
        exit(false);
    end;
}
