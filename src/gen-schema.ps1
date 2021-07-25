Param(
[string]$outputPath=""
)

if($outputPath -eq "")
{
    $outputPath= "$PWD\bin"
    if(!(Test-Path bin))
    {
        mkdir bin
    }
    Set-Location bin
    Write-Host "outputPath not set, using $outputPath"
}

$str = invoke-webrequest https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/user/project/integrations/webhooks.md -UseBasicParsing
function ToPascalCase
{
Param([String] $t
)
return (Get-Culture).TextInfo.ToTitleCase(($t.ToLower() -replace "_", " ")) -replace " ", ""
}

$usingStart =@"
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
"@

$ctrlrStart = @"


namespace Gitlab.WebHooks
{
    [ApiController]
    [Route("api/webhook")]
    public class WebHookController : ControllerBase
    {
        private readonly IWebHookService _webHookService;

        public WebHookController(IWebHookService webHookService)
        {
            _webHookService = webHookService;
        }

"@

$ctrlrMid = @"

        [HttpPost("WebHookName")]
        public async Task WebHookName([FromBody] WebHookName webHookName)
        {
            await _webHookService.ProcessWebHookName(webHookName);
        }
"@

$interfaceStart =@"


namespace Gitlab.WebHooks
{
    public interface IWebHookService
    {
  
"@

$interafaceMid =@"

      Task ProcessWebHookName(WebHookName webHookName);
"@

$aryBlocks = $str.Content -Split "``````json"
$x = 0;
$ctrlrFinal=$ctrlrStart
$interfaceFinal=$interfaceStart
$usingFinal = $usingStart
$noteInc=0
$noteTypes = @('_commit','_merge_request','_issue','_code_snippet')
 #commit
        #merge request
        #issue
        #code snip
$currentNote = ""        
foreach($block in $aryBlocks)
{
if($x -eq 0)
{
$x++
continue
}
$json = $block.SubString(0, $block.IndexOf("``````"))

try
{
    $obj = $json | ConvertFrom-Json 

    if($obj.object_kind -eq "Note")
    {
        $currentNote = $noteTypes[$noteInc]
        $noteInc++
    }
    else {
        $currentNote = ""
    }
}
catch
{
    Write-Host "Processing failed for $objKind , skipping"
}
if($null -ne $obj.object_kind)
{
$objKind = ToPascalCase ($obj.object_kind + $currentNote)
Write-Host "Processing $objKind" 
$json | Out-File "$objKind.json"
#remove-item JsonClassGeneratorConsole.exe
if(!(Test-Path "$outputPath\JsonClassGeneratorConsole.exe"))
{
    Write-Host "JsonClassGeneratorConsole missing, downloading"
    Invoke-WebRequest https://github.com/agoda-com/JsonCSharpClassGenerator/releases/download/v1.1.18/win-x64.zip -OutFile win-x64.zip
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    Write-Host "JsonClassGeneratorConsole Extracting"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$outputPath\win-x64.zip",$outputPath)
}

& $outputPath\JsonClassGeneratorConsole.exe -i="$objKind.json" -n="Gitlab.WebHooks.$objKind" -c="Hook$objKind" -t="$outputPath\$objKind" -p

$ctrlrFinal += $ctrlrMid.Replace("WebHookName", "Hook$objKind")
$usingFinal += @"

using Gitlab.WebHooks.$objKind;
"@
$interfaceFinal += $interafaceMid.Replace("WebHookName", "Hook$objKind")
}


}


$ctrlrFinal += @"

    }
}
"@
$interfaceFinal += @"

    }
}
"@

$usingFinal + $ctrlrFinal | Out-File "$outputPath\WebHookController.cs"
$usingFinal + $interfaceFinal | Out-File "$outputPath\IWebHookService.cs"

@"
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net5.0</TargetFramework>
  </PropertyGroup>
  
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.NewtonsoftJson" Version="5.0.8" />
  </ItemGroup>

</Project>
"@ | Out-File "$outputPath\Gitlab.WebHooks.csproj"

@"
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;

namespace Gitlab.WebHooks
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>();
                });
    }
}

"@ | Out-File "$outputPath\Program.cs"

@"

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Gitlab.WebHooks
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddControllers().AddNewtonsoftJson();
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            app.UseRouting();
            app.UseAuthorization();
            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });
        }
    }
}

"@ | Out-File "$outputPath\Startup.cs"