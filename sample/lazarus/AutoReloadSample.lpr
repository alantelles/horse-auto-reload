program AutoReloadSample;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  { you can add units after this }
  // You will have to define Horse Framework path manually
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

  THorse.Use(AutoReload(9000, True)); // or False for disabling in production

  Thorse.Get('/', @HomePage);

  THorse.Listen(9000);

end.

