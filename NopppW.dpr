program NopppW;

uses
  Forms,
  Main in 'Main.pas' {frmMain},
  NopUnit in 'NopUnit.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'NOPPP para Windows';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
