program filetype;

uses
  Forms,
  FmMain in 'FmMain.pas' {frmType},
  UFileCatcher in 'UFileCatcher.pas',
  filehistounit in 'filehistounit.pas' {frmHisto},
  filehistU2 in 'filehistU2.pas' {frmProgress},
  pngimage in 'png\pngimage.pas',
  pnglang in 'png\pnglang.pas',
  zlibpas in 'png\zlibpas.pas';

{$R *.res}
{$SetPEFlags 1}

begin
  Application.Initialize;
  Application.Title := 'File Type';
  Application.CreateForm(TfrmType, frmType);
  Application.CreateForm(TfrmHisto, frmHisto);
  Application.CreateForm(TfrmProgress, frmProgress);
  Application.Run;
end.
