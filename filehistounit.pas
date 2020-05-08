unit filehistounit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, StdCtrls, ComCtrls, ExtCtrls, Grids, ImgList;

type
  TfrmHisto = class(TForm)
    MainMenu1: TMainMenu;
    Panel1: TPanel;
    Image1: TImage;
    Label2: TLabel;
    Label3: TLabel;
    StringGrid1: TStringGrid;
    mnuText: TMenuItem;
    mnuGraph: TMenuItem;
    ImageList1: TImageList;
    mnuSave: TMenuItem;
    dlgColor: TColorDialog;
    mnuColours: TMenuItem;
    mnuBgColour: TMenuItem;
    mnuAxesColour: TMenuItem;
    mnuBarsColour: TMenuItem;
    mnuLabelsColour: TMenuItem;
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormCreate(Sender: TObject);
    procedure mnuTextClick(Sender: TObject);
    procedure Graphic1Click(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure StringGrid1SelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure FormShow(Sender: TObject);
    procedure BuildGrid();
    procedure mnuSaveClick(Sender: TObject);
    procedure mnuBgColourClick(Sender: TObject);
    procedure mnuAxesColourClick(Sender: TObject);
    procedure mnuBarsColourClick(Sender: TObject);
    procedure mnuLabelsColourClick(Sender: TObject);
  private
    { Private declarations }
    TB: array[0..255] of int64;
    DB: Byte;
    TeTellenF: file of Byte;
    EenPct: real;
    procedure ClearImage;
    procedure TelFile;
    procedure BuildGraph;
  public
    { Public declarations }
    CancelFlag: Boolean;
  end;

var
  frmHisto: TfrmHisto;
  BottomPos, RightPos: Integer;
  BackgroundColour, AxesColour, LabelsColour, BarsColour: TColor;

const
  LeftPos = 40;
  BufferSize = 4096;

implementation

uses
  filehistU2, FmMain, pngimage;

{$R *.DFM}

function ExtractFileNameWoExt(const FileName: string): string;
var
  i: integer;
begin
  i := LastDelimiter('.' + PathDelim + DriveDelim, FileName);
  if (i = 0) or (FileName[i] <> '.') then
    i := MaxInt;
  Result := ExtractFileName(Copy(FileName, 1, i - 1));
end;

procedure TfrmHisto.TelFile();
var
  ByteMin, ByteMax, I: Integer;
  NumRead: Integer;
  FSize, Totaal: Int64;
  Step: Real;
  buf: array[1..BufferSize] of Byte;
begin
  ByteMax := 0;
  Totaal := 0;
  try
  {$I-}
    AssignFile(TeTellenF, frmType.SelectedFileName);
    FileMode := 0; //Set file access to read only
    Reset(TeTellenF);
    FSize := FileSize(TeTellenF);
  {$I+}
    frmProgress := TfrmProgress.Create(Application);
    frmHisto.Enabled := False;
    frmProgress.Show;
    for i := 0 to 255 do
      TB[i] := 0;
    Step := Round(FSize / 100) + 0.0000001;
    repeat
      BlockRead(TeTellenF, buf, BufferSize, NumRead); //Faster using large buffer
      Totaal := Totaal + NumRead;
      Application.Title := ' ' + FloatToStrF(Totaal / Step, ffGeneral, 2, 0) + '%';
      frmProgress.Progressbar1.Position := Round(Totaal / Step);
      frmProgress.Label2.Caption := IntToStr(ToTaal) + ' Bytes';
      Application.ProcessMessages;
      if CancelFlag = True then
        Exit;
      for I := 1 to NumRead do
      begin
        DB := buf[I];
        Inc(TB[DB]);
      end
    until NumRead = 0;
    //Fill array
    ByteMax := TB[0];
    for I := 1 to 255 do
      if TB[I] > ByteMax then
        ByteMax := TB[I];
    //LeastCommon := Chr(0); //First is LeastCommon
    ByteMin := TB[0];
    for I := 1 to 255 do
      if TB[I] < ByteMin then
        ByteMin := TB[I];
    frmHisto.Caption := 'File : ' + ExtractFileName(frmType.SelectedFileName) + ' ; Size : ' + Format('%.0n', [FSize + 0.0]) + ' Bytes';
  finally
    CloseFile(TeTellenF);
    frmProgress.Release;
    frmProgress := NIL;
    frmHisto.Enabled := True;
    EenPct := (ByteMax / 100) + 0.0001;
  end;
end;

procedure TfrmHisto.ClearImage();
begin
  Image1.Canvas.Brush.Color := BackgroundColour;
  Image1.Canvas.FillRect(ClientRect);
end;

procedure TfrmHisto.BuildGraph();
var
  EenDiv, VertDiv: Real;
  I, IMax: Integer;
  S: string;
begin
  IMax := 10; //10 additional scale vertical
  VertDiv := BottomPos / 11; //Unrounded real
  EenDiv := BottomPos / 110; //Unrounded real
  with Image1.Canvas do
  begin
    Font.Name := 'Courier';
    Font.Size := 8;
    ClearImage();
    //Draw axes
    Pen.Color := AxesColour;
    //Left vertical axis
    MoveTo(LeftPos, (BottomPos - Trunc(VertDiv * 10)) - 10);
    LineTo(LeftPos, BottomPos);
    //Horizontal axis
    MoveTo(LeftPos, BottomPos);
    LineTo(RightPos, BottomPos);
    //Right vertical axis
    MoveTo(RightPos, (BottomPos - Trunc(VertDiv * 10)) - 10);
    LineTo(RightPos, BottomPos);
    //Write %age scale on left Y axis
    Font.Color := LabelsColour;
    for i := 0 to IMax do
    begin
      Str(i * 10:3, S); //:3 = 3 characters width to align right against axis
      S := S + '%_';
      TextOut(0, (BottomPos - Trunc(i * VertDiv) - 12), S)
    end;
    //Write size scale on right Y axis
    for i := 0 to IMax do
    begin
      Str(Trunc(EenPct * 10 * I), S);
      S := '_' + S;
      if i = 0 then
        S := S + ' Bytes';
      TextOut(RightPos + 1, (BottomPos + 10) - Trunc(i * VertDiv) - 22, S)
    end;
    //Draw bar chart
    Pen.Color := BarsColour;
    for i := 1 to 256 do
    begin
      MoveTo(LeftPos + i * 3, BottomPos - Trunc(TB[i - 1] * EenDiv / EenPct));
      LineTo((LeftPos + i * 3), BottomPos);
    end;
  end;
end;

procedure TfrmHisto.StringGrid1SelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  S: string;
  Ch: Char;
  B: Integer;
begin
  Ch := Chr((ACol - 1) * 16 + ARow - 1);
  B := ord(Ch);
  if B in [33..126] then
    S := Ch
  else
    case Ch of
      #09:
        S := 'TAB';
      #10:
        S := 'LF';
      #13:
        S := 'CR';
      #32:
        S := 'space';
    end;
  Label3.Caption := '$' + IntToHex(B, 2) + ' (' + S + ') ; Qty: ' + IntToStr(TB[B]);
end;

procedure TfrmHisto.Image1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  S: string;
  Ch: Char;
  B: Integer;
begin
  if ((X > LeftPos + 2) and (X < RightPos - 1) and (Y < BottomPos)) then
  begin
    Ch := Chr((X - LeftPos) div 3 - 1);
    B := ord(Ch);
    if B in [33..126] then
      S := Ch
    else
      case Ch of
        #09:
          S := 'TAB';
        #10:
          S := 'LF';
        #13:
          S := 'CR';
        #32:
          S := 'space';
      end;
    Label3.Caption := '$' + IntToHex(B, 2) + ' (' + S + ') ; Qty: ' + IntToStr(TB[B]);
  end
  else
    Label3.Caption := '';
end;

procedure TfrmHisto.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  Graphic1Click(Self); //Switch to graph mode by default
  for I := 1 to 16 do
  begin
    StringGrid1.Cells[0, I] := '$' + IntToHex(I - 1, 1) + '   ';
    StringGrid1.Cells[I, 0] := '$' + IntToHex(I - 1, 1) + '0   ';
  end;
  //Initialise graph origin location
  BottomPos := Trunc(Image1.Height * 0.95);  // = 100 % of the scale
  RightPos := LeftPos + 3 * 257; //258: leave 1 blank on both sides
  //Initialise colours
  BackgroundColour := clWebAliceBlue;
  AxesColour := clBlack;
  LabelsColour := clBlack;
  BarsColour := clRed;
end;

procedure TfrmHisto.FormShow(Sender: TObject);
begin
  CancelFlag := False;
  mnuSave.Visible := False;
  TelFile();
  if not cancelFlag then
  begin
    BuildGrid();
    BuildGraph();
    mnuSave.Visible := True;
  end
  else
    PostMessage(Self.Handle, wm_close, 0, 0); //Close form since there's nothing to show
end;

procedure TfrmHisto.BuildGrid();
var
  I: Integer;
  S: string;
begin
  for I := 0 to 255 do
  begin
    S := ' $' + IntToHex(I, 2);
    S := S + ' = ' + IntToStr(TB[I]) + '  ';
    StringGrid1.Cells[(I div 16) + 1, (I mod 16) + 1] := IntToStr(TB[I]);
  end;
end;

procedure TfrmHisto.StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  Texto: string;
const
  ALIGNMENT = DT_RIGHT; //Alignement: DT_LEFT; DT_CENTER; DT_RIGHT
begin
  Grid := TStringGrid(Sender);
  if (ARow < Grid.FixedRows) or (ACol < Grid.FixedCols) then
    Grid.Canvas.Brush.Color := clBtnFace
  else
    Grid.Canvas.Brush.Color := clWhite;
  Grid.Canvas.FillRect(Rect);
  Texto := Grid.Cells[ACol, ARow];
  DrawText(Grid.Canvas.Handle, PChar(Texto), StrLen(PChar(Texto)), Rect, ALIGNMENT);
end;

procedure TfrmHisto.mnuTextClick(Sender: TObject);
begin
  mnuText.Checked := True;
  mnuText.ImageIndex := 1;
  mnuGraph.Checked := False;
  mnuGraph.ImageIndex := 0;
  Image1.Visible := False;
  StringGrid1.Visible := True;
  mnuText.Visible := False;
  mnuText.Visible := True;
  mnuGraph.Visible := False;
  mnuGraph.Visible := True;
  mnuSave.Visible := False;
  mnuColours.Visible := False;
  Label3.Caption := '';
  StringGrid1.SetFocus;
end;

procedure TfrmHisto.Graphic1Click(Sender: TObject);
begin
  mnuText.Checked := False;
  mnuText.ImageIndex := 0;
  mnuGraph.Checked := True;
  mnuGraph.ImageIndex := 1;
  Image1.Visible := True;
  StringGrid1.Visible := False;
  mnuText.Visible := False;
  mnuText.Visible := True;
  mnuGraph.Visible := False;
  mnuGraph.Visible := True;
  mnuSave.Visible := True;
  mnuColours.Visible := True;
  Label3.Caption := '';
end;

procedure TfrmHisto.mnuSaveClick(Sender: TObject);
var
  i: Integer;
  FileName: string;
  PNG: TPNGObject;
begin
  FileName := ExtractFileNameWoExt(frmType.SelectedFileName) + '.png';
  if fileexists(FileName) then
  begin
    i := 0;
    repeat
      Inc(i);
      FileName := ExtractFileNameWoExt(frmType.SelectedFileName) + inttostr(i) + '.png';
    until not fileexists(FileName);
  end;
  PNG := TPNGObject.Create;
  try
    PNG.Assign(Image1.Picture.Bitmap);
    PNG.SaveToFile(FileName);
    ShowMessage('Graph saved in file ' + FileName);
  finally
    PNG.Free;
  end
end;

procedure TfrmHisto.mnuBgColourClick(Sender: TObject);
begin
  if dlgColor.Execute then
  begin
    BackgroundColour := dlgColor.Color;
    BuildGraph();
  end;
end;

procedure TfrmHisto.mnuAxesColourClick(Sender: TObject);
begin
  if dlgColor.Execute then
  begin
    AxesColour := dlgColor.Color;
    BuildGraph();
  end;
end;

procedure TfrmHisto.mnuLabelsColourClick(Sender: TObject);
begin
  if dlgColor.Execute then
  begin
    LabelsColour := dlgColor.Color;
    BuildGraph();
  end;
end;

procedure TfrmHisto.mnuBarsColourClick(Sender: TObject);
begin
  if dlgColor.Execute then
  begin
    BarsColour := dlgColor.Color;
    BuildGraph();
  end;
end;

end.

