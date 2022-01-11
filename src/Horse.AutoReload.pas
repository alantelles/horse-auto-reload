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

function AutoReload: THorseCallback; overload;
function AutoReload(APort: integer): THorseCallback; overload;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
procedure SendWithReloader(Res: THorseResponse; AContent: string);

var
  DetectChangeScript: string;
  LastModFile: longint = -1;
  FilesCount: longint = -1;
  FirstScan: boolean = True;

implementation

function DetectChanges: boolean;
var
  FileInfo: TSearchRec;
  HasChanges: boolean = False;
  Count: integer = 0;
begin
  if FindFirst('*', faAnyFile, FileInfo) = 0 then
  begin
    Repeat
      Count := Count + 1;
      if LastModFile < FileInfo.Time then
      begin
        HasChanges := True;
        LastModFile := FileInfo.Time;
      end;
    until FindNext(FileInfo) <> 0;
    FindClose(FileInfo);
    if FilesCount <> Count then
    begin
      FilesCount := Count;
      HasChanges := True;
    end;
  end;
  if FirstScan then
    WriteLn(#$F0, #$9F, #$91, #$80,' Horse AutoReload: Filesystem was scanned. Respond a request with SendWithReloader function to reload page when detecting changes.');
  if HasChanges and not FirstScan then
    WriteLn(#$E2, #$9F, #$B3, ' Horse AutoReload: Filesystem of application containing folder has changed. Reload signal will be sent.');
  FirstScan := False;
  Result := HasChanges;
end;

procedure ReportChanges(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
var
  ResultStatus: integer = 200;
begin
  if DetectChanges then
    ResultStatus := 204;
  Res.Status(ResultStatus);
end;

function AutoReload: THorseCallback;
begin
  Result := AutoReload(9000);
end;

function AutoReload(APort: integer): THorseCallback;
var
  Fmt: string;
begin
  DetectChanges;
  THorse.Get('/__auto-reload-detect-changes', @ReportChanges);
  Fmt := '<script>setInterval(() =>  fetch("http://localhost:%d/__auto-reload-detect-changes").then(response => { if (response.status == 204) {console.log("Change detected. Reloading"); location.reload();} }),2000);</script>';
  DetectChangeScript := Format(Fmt, [APort]);
  Result := Middleware;
end;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Next();
end;

procedure SendWithReloader(Res: THorseResponse; AContent: string);
begin
  Res.Send(AContent + DetectChangeScript);
end;


end.

