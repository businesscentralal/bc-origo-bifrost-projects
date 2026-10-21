namespace Origo.Bifrost.Projects;

using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Reports;
using Microsoft.Projects.Project.Setup;
using Microsoft.Projects.Project.WIP;
using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>Validates typed project report selectors and renders the native report as a PDF without changing project data.</summary>
codeunit 70009235 "Projects Report ori"
{
    Access = Internal;

    var
        ReportLbl: Label 'Use one of the values listed in the help.', Comment = 'is-IS=Notaðu eitt gildanna sem talin eru upp í hjálpinni.';
        MissingLbl: Label 'Pass the filter named in the refusal.', Comment = 'is-IS=Sendu síuna sem nefnd er í synjuninni.';
        FormatLbl: Label 'Use json or pdf.', Comment = 'is-IS=Notaðu json eða pdf.';
        IdentifierLbl: Label 'Pass an existing project, task or register number.', Comment = 'is-IS=Sendu verkefnis-, verkhluta- eða færsluskrárnúmer sem er til.';
        PermissionsLbl: Label 'Ask an administrator for BIFROST Read ori and native project report read permissions.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Read ori og innbyggðar lesheimildir fyrir verkefnaskýrslur.';
        TaskFilterLbl: Label 'Omit taskNo for wipToGL; use projectNo and posting dates.', Comment = 'is-IS=Slepptu taskNo fyrir wipToGL; notaðu projectNo og bókunardagsetningar.';
        RegisterFilterLbl: Label 'Use registerNo only with report register.', Comment = 'is-IS=Notaðu registerNo aðeins með skýrslunni register.';
        ConflictLbl: Label 'Use a task belonging to the selected project.', Comment = 'is-IS=Notaðu verkhluta sem tilheyrir völdu verkefni.';
        RangeLbl: Label 'Use a date range ending on or after fromDate.', Comment = 'is-IS=Notaðu dagsetningabil sem endar á eða eftir fromDate.';

    /// <summary>Checks effective feature enablement and all persistent native report data reads.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Projects Gate ori";
    begin
        exit(Gate.IsEnabled(Database::Job, false) and Gate.IsEnabled(Database::"Job Task", false) and
             Gate.IsEnabled(Database::"Job Register", false) and Gate.IsEnabled(Database::"Job Ledger Entry", false) and
             Gate.IsEnabled(Database::"Job Planning Line", false) and Gate.IsEnabled(Database::"General Ledger Setup", false) and
             Gate.IsEnabled(Database::"G/L Account", false) and Gate.IsEnabled(Database::"G/L Entry", false) and
             Gate.IsEnabled(Database::"Job WIP G/L Entry", false));
    end;

    /// <summary>Validates every filter and returns a clean native rendering error without persistent business writes.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request := Argument.GetRequestJson();
        if not Validate(Argument, Request) then
            exit;
        if not TryRender(Request, Response) then begin
            Argument.RespondWithLastError();
            exit;
        end;
        Argument.SetResponseJson(Response);
    end;

    [TryFunction]
    local procedure TryRender(Request: JsonObject; var Response: JsonObject)
    begin
        Response.Add('status', 'Success');
        Response.Add('report', Request.GetText('report'));
        Response.Add('format', Request.GetText('format'));
        if Request.GetText('format') = 'json' then
            Response.Add('rows', RenderJson(Request))
        else begin
            Response.Add('contentType', 'application/pdf');
            Response.Add('pdfBase64', RenderPdf(Request));
        end;
    end;

    /// <summary>Declares typed report selection and exact native filters.</summary>
    procedure Parameters() Result: JsonArray
    var
        Input: Codeunit "Projects Followup Input ori";
        SelectorLbl: Label 'Required report: actualToBudget, analysis, wipToGL or register.', Comment = 'is-IS=Nauðsynleg skýrsla: actualToBudget, analysis, wipToGL eða register.';
        OutputLbl: Label 'Required output format: json or pdf.', Comment = 'is-IS=Nauðsynlegt úttakssnið: json eða pdf.';
        ProjectLbl: Label 'Exact project number; required for actualToBudget, analysis and wipToGL.', Comment = 'is-IS=Nákvæmt verkefnisnúmer; nauðsynlegt fyrir actualToBudget, analysis og wipToGL.';
        TaskLbl: Label 'Optional exact posting task within projectNo; applies to project detail reports and register entries.', Comment = 'is-IS=Valfrjáls nákvæmur bókunarverkhluti innan projectNo; gildir um ítarlegar verkefnaskýrslur og færsluskrárfærslur.';
        RegisterLbl: Label 'Exact positive project register number; required for register.', Comment = 'is-IS=Nákvæmt jákvætt verkefnisfærsluskrárnúmer; nauðsynlegt fyrir register.';
        FromLbl: Label 'Optional inclusive first posting date in ISO YYYY-MM-DD format; requires toDate.', Comment = 'is-IS=Valfrjáls fyrsti bókunardagur, meðtalinn, á ISO-sniðinu YYYY-MM-DD; krefst toDate.';
        ToLbl: Label 'Optional inclusive last posting date in ISO YYYY-MM-DD format; requires fromDate.', Comment = 'is-IS=Valfrjáls síðasti bókunardagur, meðtalinn, á ISO-sniðinu YYYY-MM-DD; krefst fromDate.';
    begin
        Result.Add(Input.Parameter('report', 'string', true, SelectorLbl, 0));
        Result.Add(Input.Parameter('format', 'string', true, OutputLbl, 0));
        Result.Add(Input.Parameter('projectNo', 'string', false, ProjectLbl, 20));
        Result.Add(Input.Parameter('taskNo', 'string', false, TaskLbl, 20));
        Result.Add(Input.Parameter('registerNo', 'integer', false, RegisterLbl, 0));
        Result.Add(Input.Parameter('fromDate', 'date', false, FromLbl, 0));
        Result.Add(Input.Parameter('toDate', 'date', false, ToLbl, 0));
    end;

    /// <summary>Returns confirmed BC 28 standard report IDs; arbitrary report execution is excluded.</summary>
    procedure ReportId(ReportName: Text): Integer
    begin
        case ReportName of
            'actualToBudget': exit(Report::"Job Actual To Budget");
            'analysis': exit(Report::"Job Analysis");
            'wipToGL': exit(Report::"Job WIP To G/L");
            'register': exit(Report::"Job Register");
        end;
        exit(0);
    end;

    /// <summary>Validates every report selector and filter before any report is run.</summary>
    procedure Validate(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        Project: Record Job;
        Task: Record "Job Task";
        Register: Record "Job Register";
        Input: Codeunit "Projects Followup Input ori";
        FirstDate: Date;
        LastDate: Date;
    begin
        if not Input.Validate(Argument, Request, Parameters()) then
            exit(false);
        if ReportId(Request.GetText('report')) = 0 then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'report', ReportLbl));
        if not (Request.GetText('format') in ['json', 'pdf']) then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'format', FormatLbl));
        if (Request.GetText('report') <> 'register') and (Input.TextValue(Request, 'projectNo') = '') then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'projectNo', MissingLbl));
        if Request.GetText('report') = 'register' then begin
            if not Request.Contains('registerNo') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'registerNo', MissingLbl));
            if Request.GetInteger('registerNo') = 0 then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'registerNo', IdentifierLbl));
        end;
        if Request.Contains('fromDate') <> Request.Contains('toDate') then
            if Request.Contains('fromDate') then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'toDate', MissingLbl))
            else
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'fromDate', MissingLbl));
        if Request.Contains('fromDate') then begin
            Evaluate(FirstDate, Request.GetText('fromDate'), 9);
            Evaluate(LastDate, Request.GetText('toDate'), 9);
            if (FirstDate = 0D) or (LastDate < FirstDate) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'toDate', RangeLbl));
        end;
        if (Request.GetText('report') = 'wipToGL') and Request.Contains('taskNo') then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'taskNo', TaskFilterLbl));
        if (Request.GetText('report') <> 'register') and Request.Contains('registerNo') then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'registerNo', RegisterFilterLbl));
        if not IsEnabled() then
            exit(Input.Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, '', PermissionsLbl));
        Project.ReadIsolation := IsolationLevel::ReadCommitted;
        Task.ReadIsolation := IsolationLevel::ReadCommitted;
        Register.ReadIsolation := IsolationLevel::ReadCommitted;
        if Input.TextValue(Request, 'projectNo') <> '' then
            if not Project.Get(Request.GetText('projectNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'projectNo', IdentifierLbl));
        if Input.TextValue(Request, 'taskNo') <> '' then begin
            if Input.TextValue(Request, 'projectNo') = '' then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'projectNo', MissingLbl));
            if not Task.Get(Request.GetText('projectNo'), Request.GetText('taskNo')) then begin
                Task.SetRange("Job Task No.", Request.GetText('taskNo'));
                if not Task.IsEmpty() then
                    exit(Input.Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'taskNo', ConflictLbl));
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'taskNo', IdentifierLbl));
            end;
        end;
        if Request.GetText('report') = 'register' then
            if not Register.Get(Request.GetInteger('registerNo')) then
                exit(Input.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'registerNo', IdentifierLbl));
        exit(true);
    end;

    /// <summary>Serializes native filtered views using XML nodes, preventing request-filter XML injection.</summary>
    procedure RequestXml(Request: JsonObject): Text
    var
        Project: Record Job;
        Task: Record "Job Task";
        Register: Record "Job Register";
        Ledger: Record "Job Ledger Entry";
        Input: Codeunit "Projects Followup Input ori";
        Document: XmlDocument;
        Root: XmlElement;
        Items: XmlElement;
        Options: XmlElement;
        Index: Integer;
        FirstDate: Date;
        LastDate: Date;
        Result: Text;
    begin
        Root := XmlElement.Create('ReportParameters');
        Root.SetAttribute('id', Format(ReportId(Request.GetText('report')), 0, 9));
        Options := XmlElement.Create('Options');
        if Request.GetText('report') = 'analysis' then
            for Index := 1 to 8 do begin
                AddOption(Options, 'AmountField[' + Format(Index, 0, 9) + ']', Format(Index, 0, 9));
                AddOption(Options, 'CurrencyField[' + Format(Index, 0, 9) + ']', '0');
            end;
        if Request.GetText('report') = 'actualToBudget' then
            AddOption(Options, 'CurrencyField', '0');
        Root.Add(Options);
        Items := XmlElement.Create('DataItems');
        if Input.TextValue(Request, 'projectNo') <> '' then begin
            Project.SetRange("No.", Request.GetText('projectNo'));
            Ledger.SetRange("Job No.", Request.GetText('projectNo'));
        end;
        if Input.TextValue(Request, 'taskNo') <> '' then begin
            Task.SetRange("Job Task No.", Request.GetText('taskNo'));
            Ledger.SetRange("Job Task No.", Request.GetText('taskNo'));
        end;
        if Request.Contains('fromDate') then begin
            Evaluate(FirstDate, Request.GetText('fromDate'), 9);
            Evaluate(LastDate, Request.GetText('toDate'), 9);
            Project.SetRange("Posting Date Filter", FirstDate, LastDate);
            Project.SetRange("Planning Date Filter", FirstDate, LastDate);
            Ledger.SetRange("Posting Date", FirstDate, LastDate);
        end;
        if Request.GetText('report') = 'register' then begin
            Register.SetRange("No.", Request.GetInteger('registerNo'));
            AddView(Items, 'Job Register', Register.GetView(false));
            AddView(Items, 'Job Ledger Entry', Ledger.GetView(false));
        end else begin
            AddView(Items, 'Job', Project.GetView(false));
            if Request.GetText('report') in ['actualToBudget', 'analysis'] then
                AddView(Items, 'Job Task', Task.GetView(false));
        end;
        Root.Add(Items);
        Document := XmlDocument.Create();
        Document.Add(Root);
        Document.WriteTo(Result);
        exit(Result);
    end;

    /// <summary>Renders the native report as base64 PDF using the validated report selector and filters.</summary>
    procedure RenderPdf(Request: JsonObject): Text
    var
        TempBlob: Codeunit "Temp Blob";
        Base64: Codeunit "Base64 Convert";
        Output: OutStream;
        Input: InStream;
    begin
        TempBlob.CreateOutStream(Output);
        Report.SaveAs(ReportId(Request.GetText('report')), RequestXml(Request), ReportFormat::Pdf, Output);
        TempBlob.CreateInStream(Input);
        exit(Base64.ToBase64(Input));
    end;

    /// <summary>Renders shaped rows from the same native dataset used by the PDF report.</summary>
    procedure RenderJson(Request: JsonObject): JsonArray
    var
        TempBlob: Codeunit "Temp Blob";
        Document: XmlDocument;
        Output: OutStream;
        Input: InStream;
    begin
        TempBlob.CreateOutStream(Output, TextEncoding::UTF8);
        Report.SaveAs(ReportId(Request.GetText('report')), RequestXml(Request), ReportFormat::Xml, Output);
        TempBlob.CreateInStream(Input, TextEncoding::UTF8);
        XmlDocument.ReadFrom(Input, Document);
        exit(ShapeDataset(Request.GetText('report'), Document));
    end;

    /// <summary>Maps native BC dataset columns to stable typed rows; caption and total-only rows are excluded.</summary>
    procedure ShapeDataset(ReportName: Text; Document: XmlDocument) Result: JsonArray
    var
        Nodes: XmlNodeList;
        Node: XmlNode;
        Row: JsonObject;
        AccountNo: Text;
        AccountName: Text;
    begin
        Document.SelectNodes('ReportDataSet/DataItems/DataItem', Nodes);
        foreach Node in Nodes do begin
            Clear(Row);
            case ReportName of
                'actualToBudget': ShapeActualToBudget(Node, Row);
                'analysis': ShapeAnalysis(Node, Row);
                'wipToGL':
                    begin
                        if ColumnText(Node, 'GLAcc__No__') <> '' then begin
                            AccountNo := ColumnText(Node, 'GLAcc__No__');
                            AccountName := ColumnText(Node, 'GLAcc_Name');
                        end;
                        ShapeWip(Node, AccountNo, AccountName, Row);
                    end;
                'register': ShapeRegister(Node, Row);
            end;
            if Row.Keys().Count() > 0 then
                Result.Add(Row);
        end;
    end;

    local procedure ShapeActualToBudget(Node: XmlNode; var Row: JsonObject)
    var
        Suffix: Text;
        Index: Integer;
        Amounts: JsonArray;
        Names: List of [Text];
    begin
        if ColumnText(Node, 'JobDiffBufferNo') <> '' then
            Suffix := ''
        else
            if ColumnText(Node, 'JobDiffBuffer2No') <> '' then
                Suffix := '2'
            else
                exit;
        Row.Add('projectNo', ColumnText(Node, 'No_Job'));
        Row.Add('taskNo', ColumnText(Node, 'JobTaskNo_JobTask'));
        if Suffix = '' then begin
            Row.Add('type', ColumnText(Node, 'JobDiffBufferType1'));
            Row.Add('no', ColumnText(Node, 'JobDiffBufferNo'));
            Row.Add('unitOfMeasureCode', ColumnText(Node, 'JobDiffBufferUOMcode'));
            Row.Add('workTypeCode', ColumnText(Node, 'JobDiffBufferWorkTypeCode'));
            for Index := 1 to 9 do
                Amounts.Add(ColumnDecimal(Node, 'Amt' + Format(Index, 0, 9)));
        end else begin
            Row.Add('type', ColumnText(Node, 'JobDiffBuffer2Type1'));
            Row.Add('no', ColumnText(Node, 'JobDiffBuffer2No'));
            Row.Add('unitOfMeasureCode', ColumnText(Node, 'JobDiffBuffer2UOMcode'));
            Row.Add('workTypeCode', ColumnText(Node, 'JobDiffBuffer2WorkTypeCode'));
            Names.Add('Amt12');
            Names.Add('Amt21');
            Names.Add('Amt39');
            Names.Add('Amt40');
            Names.Add('Amt55');
            Names.Add('Amt66');
            Names.Add('Amt77');
            Names.Add('Amt88');
            Names.Add('Amt99');
            for Index := 1 to Names.Count() do
                Amounts.Add(ColumnDecimal(Node, Names.Get(Index)));
        end;
        AddBudgetValues(Row, Amounts);
    end;

    local procedure AddBudgetValues(var Row: JsonObject; Amounts: JsonArray)
    var
        Names: List of [Text];
        Value: JsonToken;
        Index: Integer;
    begin
        Names.Add('budgetQuantity');
        Names.Add('actualQuantity');
        Names.Add('quantityDifference');
        Names.Add('budgetCostLCY');
        Names.Add('actualCostLCY');
        Names.Add('costDifferenceLCY');
        Names.Add('budgetPriceLCY');
        Names.Add('actualPriceLCY');
        Names.Add('priceDifferenceLCY');
        for Index := 1 to Names.Count() do begin
            Amounts.Get(Index - 1, Value);
            Row.Add(Names.Get(Index), Value);
        end;
    end;

    local procedure ShapeAnalysis(Node: XmlNode; var Row: JsonObject)
    var
        NativeFlag: XmlNode;
        Names: List of [Text];
        Index: Integer;
    begin
        if ColumnText(Node, 'JobTaskNo_JobTask') = '' then
            exit;
        if Node.SelectSingleNode('.//Column[@name="ShowIntBody1"]', NativeFlag) then
            if not (ColumnBoolean(Node, 'ShowIntBody1') or ColumnBoolean(Node, 'ShowIntBody2') or ColumnBoolean(Node, 'ShowIntBody3')) then
                exit;
        Row.Add('projectNo', ColumnText(Node, 'No_Job'));
        Row.Add('taskNo', ColumnText(Node, 'JobTaskNo_JobTask'));
        Row.Add('description', ColumnText(Node, 'Indentation_JobTask'));
        Names.Add('budgetPriceLCY');
        Names.Add('actualPriceLCY');
        Names.Add('billablePriceLCY');
        Names.Add('invoicedPriceLCY');
        Names.Add('budgetCostLCY');
        Names.Add('actualCostLCY');
        Names.Add('billableCostLCY');
        Names.Add('invoicedCostLCY');
        for Index := 1 to Names.Count() do
            Row.Add(Names.Get(Index), ColumnDecimal(Node, 'Amt' + Format(Index, 0, 9)));
    end;

    local procedure ShapeWip(Node: XmlNode; AccountNo: Text; AccountName: Text; var Row: JsonObject)
    begin
        if (AccountNo = '') or (ColumnText(Node, 'JobBuffer__Account_No__2_') = '') then
            exit;
        Row.Add('accountNo', AccountNo);
        Row.Add('accountName', AccountName);
        Row.Add('postingGroup', ColumnText(Node, 'JobBuffer__Account_No__2_'));
        Row.Add('wipCostLCY', ColumnDecimal(Node, 'JobBuffer__Amount_1_'));
        Row.Add('wipAccruedCostsLCY', ColumnDecimal(Node, 'JobBuffer__Amount_2_'));
        Row.Add('wipInvoicedSalesLCY', ColumnDecimal(Node, 'JobBuffer__Amount_4_'));
        Row.Add('wipAccruedSalesLCY', ColumnDecimal(Node, 'JobBuffer__Amount_5_'));
        Row.Add('glBalanceLCY', ColumnDecimal(Node, 'JobBuffer__Amount_3_'));
        Row.Add('wipAmountLCY', ColumnDecimal(Node, 'GLAccJobTotal'));
        Row.Add('differenceLCY', ColumnDecimal(Node, 'GLAccJobTotal___JobBuffer__Amount_3_'));
    end;

    local procedure ShapeRegister(Node: XmlNode; var Row: JsonObject)
    var
        EntryNo: Integer;
        RegisterNo: Integer;
        PostingDate: Date;
    begin
        if not Evaluate(EntryNo, ColumnText(Node, 'Job_Ledger_Entry__Entry_No__'), 9) then
            exit;
        if EntryNo = 0 then
            exit;
        Row.Add('entryNo', EntryNo);
        if ColumnText(Node, 'Job_Register__No__') <> '' then
            Evaluate(RegisterNo, ColumnText(Node, 'Job_Register__No__'), 9);
        Row.Add('registerNo', RegisterNo);
        Row.Add('projectNo', ColumnText(Node, 'Job_Ledger_Entry__Job_No__'));
        if ColumnText(Node, 'Job_Ledger_Entry__Posting_Date_') <> '' then
            Evaluate(PostingDate, ColumnText(Node, 'Job_Ledger_Entry__Posting_Date_'));
        Row.Add('postingDate', Format(PostingDate, 0, 9));
        Row.Add('documentNo', ColumnText(Node, 'Job_Ledger_Entry__Document_No__'));
        Row.Add('entryType', ColumnText(Node, 'Job_Ledger_Entry__Entry_Type_'));
        Row.Add('type', ColumnText(Node, 'Job_Ledger_Entry_Type'));
        Row.Add('no', ColumnText(Node, 'Job_Ledger_Entry__No__'));
        Row.Add('quantity', ColumnDecimal(Node, 'Job_Ledger_Entry_Quantity'));
        Row.Add('unitOfMeasureCode', ColumnText(Node, 'Job_Ledger_Entry__Unit_of_Measure_Code_'));
        Row.Add('workTypeCode', ColumnText(Node, 'Job_Ledger_Entry__Work_Type_Code_'));
        Row.Add('totalCostLCY', ColumnDecimal(Node, 'Job_Ledger_Entry__Total_Cost__LCY__'));
        Row.Add('lineAmountLCY', ColumnDecimal(Node, 'Job_Ledger_Entry__Line_Amount__LCY__'));
    end;

    local procedure ColumnText(Node: XmlNode; Name: Text): Text
    var
        Column: XmlNode;
    begin
        if Node.SelectSingleNode('.//Column[@name="' + Name + '"]', Column) then
            exit(Column.AsXmlElement().InnerText());
        exit('');
    end;

    local procedure ColumnBoolean(Node: XmlNode; Name: Text): Boolean
    var
        Value: Boolean;
        TextValue: Text;
    begin
        TextValue := ColumnText(Node, Name);
        if TextValue = '' then
            exit(false);
        Evaluate(Value, TextValue, 9);
        exit(Value);
    end;

    local procedure ColumnDecimal(Node: XmlNode; Name: Text): Decimal
    var
        Value: Decimal;
        TextValue: Text;
    begin
        TextValue := ColumnText(Node, Name);
        if TextValue = '' then
            exit(0);
        Evaluate(Value, TextValue, 9);
        exit(Value);
    end;

    local procedure AddOption(var Options: XmlElement; OptionName: Text; OptionValue: Text)
    var
        OptionField: XmlElement;
    begin
        OptionField := XmlElement.Create('Field');
        OptionField.SetAttribute('name', OptionName);
        OptionField.Add(XmlText.Create(OptionValue));
        Options.Add(OptionField);
    end;

    local procedure AddView(var Items: XmlElement; ItemName: Text; View: Text)
    var
        Item: XmlElement;
    begin
        Item := XmlElement.Create('DataItem');
        Item.SetAttribute('name', ItemName);
        Item.Add(XmlText.Create(View));
        Items.Add(Item);
    end;
}
