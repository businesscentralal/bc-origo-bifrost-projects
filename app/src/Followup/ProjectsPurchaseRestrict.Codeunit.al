namespace Origo.Bifrost.Projects;

using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>Routes generic writes to purchase project-link fields to the dedicated safe project messages.</summary>
codeunit 70009245 "Projects Purchase Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictPurchaseProjectFields(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        if IsProjectLinkField(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure ProjectLinkHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if IsProjectLinkField(TableNo, FieldNo) then
            Hint := 'Projects.PurchaseLine.Link, Projects.ItemUsage.Post';
    end;

    local procedure IsProjectLinkField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        exit((TableNo = Database::"Purchase Line") and
             (FieldNo in [PurchaseLine.FieldNo("Job No."), PurchaseLine.FieldNo("Job Task No."), PurchaseLine.FieldNo("Job Line Type"), PurchaseLine.FieldNo("Job Planning Line No.")]));
    end;
}
