using System;
using System.Linq;
using Nuke.Common;
using Nuke.Common.CI;
using Nuke.Common.Execution;
using Nuke.Common.Git;
using Nuke.Common.IO;
using Nuke.Common.ProjectModel;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.DotNet;
using Nuke.Common.Tools.GitVersion;
using Nuke.Common.Utilities.Collections;
using static Nuke.Common.EnvironmentInfo;
using static Nuke.Common.IO.FileSystemTasks;
using static Nuke.Common.IO.PathConstruction;
using static Nuke.Common.Tools.DotNet.DotNetTasks;

[CheckBuildProjectConfigurations]
[ShutdownDotNetAfterServerBuild]
class Build : NukeBuild
{
    /// Support plugins are available for:
    ///   - JetBrains ReSharper        https://nuke.build/resharper
    ///   - JetBrains Rider            https://nuke.build/rider
    ///   - Microsoft VisualStudio     https://nuke.build/visualstudio
    ///   - Microsoft VSCode           https://nuke.build/vscode

    public static int Main () => Execute<Build>(x => x.Compile);


    [Parameter("Configuration to build - Default is 'Debug' (local) or 'Release' (server)")] 
    readonly Configuration Configuration = IsLocalBuild ? Configuration.Debug : Configuration.Release;
    
    [Parameter] string ApiKey = "";
    [Parameter] string RepositoryApiUrl = "https://api.nuget.org/v3/index.json";


    [Solution] readonly Solution Solution;
    [GitRepository] readonly GitRepository GitRepository;
    [GitVersion(Framework = "netcoreapp3.1")] readonly GitVersion GitVersion;

    AbsolutePath SourceDirectory => RootDirectory / "source";
    AbsolutePath TestsDirectory => RootDirectory / "tests";
    AbsolutePath OutputDirectory => RootDirectory / "output";

    Target Clean => _ => _
        .Before(Restore)
        .Executes(() =>
        {
            SourceDirectory.GlobDirectories("**/bin", "**/obj").ForEach(DeleteDirectory);
            TestsDirectory.GlobDirectories("**/bin", "**/obj").ForEach(DeleteDirectory);
            EnsureCleanDirectory(OutputDirectory);
        });

    Target Restore => _ => _
        .Executes(() =>
        {
            DotNetRestore(s => s
                .SetProjectFile(Solution));
        });

    Target Compile => _ => _
        .DependsOn(Restore)
        .Executes(() =>
        {
            DotNetBuild(s => s
                .SetProjectFile(Solution)
                .SetConfiguration(Configuration)
                .SetAssemblyVersion(GitVersion.AssemblySemVer)
                .SetFileVersion(GitVersion.AssemblySemFileVer)
                .SetInformationalVersion(GitVersion.InformationalVersion)
                .SetVerbosity(DotNetVerbosity.Minimal)
                .EnableNoRestore());
        });


    Target Pack => _ => _
		.DependsOn(Compile)
		
	    .Executes(() =>
	    {
		    DotNetPack(_ => _
		                    .SetProject(Solution.GetProject("Core"))
		                    .SetOutputDirectory(OutputDirectory)
		                    .SetAssemblyVersion(GitVersion.AssemblySemVer)
		                    .SetFileVersion(GitVersion.AssemblySemFileVer)
		                    .SetInformationalVersion(GitVersion.InformationalVersion)
                            .SetVersion(GitVersion.NuGetVersionV2));
            DotNetPack(_ => _
		                    
                            .SetProject(Solution.GetProject("Printer"))
		                    .SetOutputDirectory(OutputDirectory)
                            .SetAssemblyVersion(GitVersion.AssemblySemVer)
                            .SetFileVersion(GitVersion.AssemblySemFileVer)
                            .SetInformationalVersion(GitVersion.InformationalVersion)
                            .SetVersion(GitVersion.NuGetVersionV2));
	    });

    Target Publish => _ => _
       .DependsOn(Pack)
       .Requires(() => ApiKey)
       .Requires(() => RepositoryApiUrl)
       .Executes(() =>
       {
	       GlobFiles(OutputDirectory, "*.nupkg")
		       .NotEmpty()
		       .Where(x => !x.EndsWith("symbols.nupkg"))
		       .ForEach(x =>
		       {
			       DotNetNuGetPush(s => s
			                            .SetTargetPath(x)
			                            .SetSource(RepositoryApiUrl)
			                            .SetApiKey(ApiKey)
			       );
		       });

       });
}
