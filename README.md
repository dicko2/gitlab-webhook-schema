# Gitlab Webhook Schema Generator

Auto generates a netcore WebApi project from Gitlab's Markdown documentation that can consume webhooks

### Usage

Run script command line like so
```
.\gen-schema.ps1 -outputPath "<target output path>"
```

After generating the API project create an implementation for IWebHookService and register it in the IoC container.

Note: the script downloads and uses a Json to CSharp class converter published [here](https://github.com/agoda-com/JsonCSharpClassGenerator/releases) 

### Current limitations

Doesn't support Note events or events that dont have "object_kind" in their schema

