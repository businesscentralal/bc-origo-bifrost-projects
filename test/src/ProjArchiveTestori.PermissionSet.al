namespace Origo.Bifrost.Projects.Test;

using Origo.Bifrost;
using Origo.Bifrost.Projects;

/// <summary>Test-only role permits feature setup inspection and argument handling, with no native business table rights.</summary>
permissionset 97122 "ProjArchiveTest ori"
{
    Assignable = false;
    Permissions = tabledata "Projects Setup ori" = R,
        tabledata "Message Argument ori" = RIMD,
        codeunit "Projects Gate ori" = X,
        codeunit "Projects Followup Input ori" = X,
        codeunit "Proj. Archive Impl ori" = X,
        codeunit "Proj. Archive Get Impl ori" = X,
        codeunit "Projects Archive ori" = X;
}
