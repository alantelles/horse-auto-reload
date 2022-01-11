program AutoReloadSample;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  { you can add units after this }
  Horse, Horse.AutoReload;

procedure HomePage(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  with TStringList.Create do
  begin
    LoadFromFile('index.html');
    SendWithReloader(Res, Text);
    Free;
  end;
end;

begin

  THorse.Use(AutoReload);

  Thorse.Get('/', @HomePage);

  THorse.Listen(9000);

end.

