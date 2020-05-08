unit filehistU2;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls;

type
  TfrmProgress = class(TForm)
    ProgressBar1: TProgressBar;
    Label2: TLabel;
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmProgress: TfrmProgress;

implementation

uses
  filehistounit;

{$R *.DFM}

procedure TfrmProgress.Button1Click(Sender: TObject);
begin
  if Application.MessageBox('Cancel reading the file ?', 'Reading File', mb_applmodal + mb_iconquestion + mb_yesno + mb_defbutton1) = 6 then
  begin
    frmHisto.CancelFlag := True;
    Close;
  end;
end;

end.

