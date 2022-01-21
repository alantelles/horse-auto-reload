unit Horse.AutoReload;

{$IF DEFINED(FPC)}
{$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes,
{$ELSE}
  System.Classes, System.SysUtils,
{$ENDIF}
  Horse;


function AutoReload(APort: integer; Active: boolean): THorseCallback;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
procedure SendWithReloader(Res: THorseResponse; AContent: string);

var
  AutoReloadActivated: boolean;
  DetectChangeScript: string;
  LastModFile: longint = -1;
  FilesCount: longint = -1;
  SessionCount: longint = 0;
  FirstScan: boolean = True;

implementation


function DetectChanges(ADir: string): boolean;
var
  FileInfo: TSearchRec;
  HasChanges: boolean = False;
begin
  if FindFirst(ADir + directorySeparator + '*', faAnyFile, FileInfo) = 0 then
  begin
    Repeat
      if (FileInfo.Name = '.') or (FileInfo.Name = '..') then
        continue;
      SessionCount := SessionCount + 1;
      if LastModFile < FileInfo.Time then
      begin
        HasChanges := True;
        LastModFile := FileInfo.Time;
      end;
      if (FileInfo.Attr and faDirectory) = faDirectory then
      begin
        HasChanges := HasChanges or DetectChanges(ADir + DirectorySeparator + FileInfo.Name);
      end;
    until FindNext(FileInfo) <> 0;
    FindClose(FileInfo);
  end;

  Result := HasChanges;
end;

function RunDetectChanges: boolean;
var
  HasChanges: boolean;
begin
  HasChanges := DetectChanges('.');
  if FirstScan then
    WriteLn(#$F0, #$9F, #$91, #$80,' Horse AutoReload: Filesystem was scanned. Respond a request with SendWithReloader function to reload page when detecting changes.');
  if HasChanges and not FirstScan then
    WriteLn(#$E2, #$9F, #$B3, ' Horse AutoReload: Filesystem of application containing folder has changed. Reload signal will be sent.');
  FirstScan := False;
  if FilesCount <> SessionCount then
  begin
    FilesCount := SessionCount;
    HasChanges := True;
  end;
  SessionCount := 0;
  Result := HasChanges;
end;


procedure ReportChanges(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
var
  ResultStatus: integer = 200;
begin
  if RunDetectChanges then
    ResultStatus := 204;
  Res.Status(ResultStatus);
end;

function AutoReload(APort: integer; Active: boolean): THorseCallback;
var
  Fmt: string;
begin
  if Active then
  begin
    RunDetectChanges;
    THorse.Get('/__auto-reload-detect-changes', @ReportChanges);
    Fmt := '<script>setInterval(() =>  fetch("http://localhost:%d/__auto-reload-detect-changes").then(response => { if (response.status == 204) {console.log("Change detected. Reloading"); location.reload();} }),2000);</script>';
    DetectChangeScript := Format(Fmt, [APort]);
  end
  else
    Writeln(#$F0, #$9F, #$98, #$B4,' Horse AutoReload: Scanning deactivated. Filesystem changes check endpoint was not registered.');
  AutoReloadActivated := Active;
  Result := Middleware;
end;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Next();
end;

procedure SendWithReloader(Res: THorseResponse; AContent: string);
var
  StringSent: string;
begin
  StringSent := AContent;
  if AutoReloadActivated then
    StringSent := StringSent + DetectChangeScript;
  Res.Send(StringSent);
end;


end.

