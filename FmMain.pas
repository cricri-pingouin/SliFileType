unit FmMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, Menus, ExtCtrls, Grids, XMLDoc, XMLIntf;

type
  TfrmType = class(TForm)
    strgrd: TStringGrid;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure strgrdDblClick(Sender: TObject);
    procedure strgrdDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure FormActivate(Sender: TObject);
  private
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
  public
    { Public declarations }
    SelectedFileName: string;
  end;

var
  frmType: TfrmType;
  HeadDB, ExtDB, SigDB: array of string;
  DBsize: Integer;
  FullFilesNames: TStringList;
  FilesDropped: Boolean;
  ReadFileHeaderSize: Integer;
  ExtensionMatches: array of Boolean;

implementation

uses
  ShellAPI, UFileCatcher, filehistounit;

{$R *.dfm}

function IntToStrDelimited(aNum: integer): string;
// Formats the integer aNum with the default Thousand Separator
var
  D: Double;
begin
  D := aNum;
  Result := Format('%.0n', [D]); // ".0" -> no decimals, n -> thousands separators
end;

function GetSizeOfFile(const FileName: string): Int64;
var
  Rec: TSearchRec;
begin
  Result := 0;
  if (FindFirst(FileName, faAnyFile, Rec) = 0) then
  begin
    Result := Rec.Size;
    FindClose(Rec);
  end;
end;

function ExtractFileNameWoExt(const FileName: string): string;
var
  i: integer;
begin
  i := LastDelimiter('.' + PathDelim + DriveDelim, FileName);
  if (i = 0) or (FileName[i] <> '.') then
    i := MaxInt;
  Result := ExtractFileName(Copy(FileName, 1, i - 1));
end;

function ReadFileHeader(const FileName: string): string;
var
  Stream: TFileStream;
  Buffer: array of AnsiChar;
  i: Integer;
begin
  SetLength(Buffer, ReadFileHeaderSize);
  //Populate buffer elements
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    Stream.Read(Buffer[0], ReadFileHeaderSize);
  finally
    Stream.Free;
  end;
  Result := '';
  for i := 0 to ReadFileHeaderSize do
    Result := Result + IntToHex(Ord(Buffer[i]), 2) + ' ';
end;

function CompareVsHeader(const FileHeader: string; const BaseHeader: string): boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Length(BaseHeader) do
    if (BaseHeader[i] <> ' ') and (BaseHeader[i] <> '?') and (BaseHeader[i] <> FileHeader[i]) then
    begin
      Result := False;
      Exit;
    end;
end;

procedure TfrmType.FormActivate(Sender: TObject);
var
  i, j: Integer;
  FullName, FileHeader: string;
  ThisFileSize: Int64;
begin
  //Command line parameters
  if ParamCount = 0 then
    Exit;
  //ParamCount > 0: some parameters passed, see below
  strgrd.visible := False;
  strgrd.RowCount := ParamCount + 1;
  SetLength(ExtensionMatches, ParamCount + 1);
  for i := 0 to ParamCount do
    ExtensionMatches[i] := True;
  FullFilesNames := TStringList.Create;
  for i := 1 to ParamCount do //ParamStr(0) is app path and name, (1) is first parameter
  begin
      //Get file properties
    FullName := ParamStr(i);
    FullFilesNames.Add(FullName);
    ThisFileSize := GetSizeOfFile(FullName);
    FileHeader := ReadFileHeader(FullName);
      //Populate StringGrid
    strgrd.Cells[0, i] := ExtractFileNameWoExt(FullName);
    strgrd.Cells[1, i] := UpperCase(StringReplace(ExtractFileExt(FullName), '.', '', []));
    strgrd.Cells[2, i] := IntToStrDelimited(ThisFileSize div 1024);
    strgrd.Cells[3, i] := FileHeader;
      //Identify file header
    strgrd.Cells[5, i] := '';
    for j := 0 to DBsize - 1 do
      if CompareVsHeader(FileHeader, HeadDB[j]) then
      begin
        strgrd.Cells[4, i] := SigDB[j];
        strgrd.Cells[5, i] := ExtDB[j];
        Break;
      end;
      //Flag discrepancies for stringgrid highlighting
    if (Pos(strgrd.Cells[1, i], strgrd.Cells[5, i]) = 0) then
      ExtensionMatches[i] := False;
      //If no match was found: mark as unknown
    if (strgrd.Cells[5, i] = '') then
    begin
      strgrd.Cells[4, i] := 'Unknown, maybe text based';
      strgrd.Cells[5, i] := '?';
    end;
  end;
  FilesDropped := True;
  strgrd.visible := True;
end;

procedure TfrmType.FormCreate(Sender: TObject);
var
  DOC: IXMLDocument;
  FileTypeNode: IXMLNode;
  i, l: Integer;
begin
  // Tell windows we accept file drops
  DragAcceptFiles(Self.Handle, True);
  //Init StringGrid
  strgrd.Width := frmType.ClientWidth;
  strgrd.Height := frmType.ClientHeight;
  strgrd.Cells[0, 0] := 'File name';
  strgrd.Cells[1, 0] := 'Extension';
  strgrd.Cells[2, 0] := 'Size (KB)';
  strgrd.Cells[3, 0] := 'Header';
  strgrd.Cells[4, 0] := 'Type detected';
  strgrd.Cells[5, 0] := 'Expected extension';
  //Load signatures
  DOC := LoadXMLDocument('filetypes.xml');
  DBsize := DOC.ChildNodes.Nodes['filetypes'].ChildNodes.Count;
  SetLength(HeadDB, DBsize);
  SetLength(ExtDB, DBsize);
  SetLength(SigDB, DBsize);
  ReadFileHeaderSize := 0;
  for i := 0 to DBsize - 1 do
  begin
    FileTypeNode := DOC.ChildNodes.Nodes['filetypes'].ChildNodes[i];
    HeadDB[i] := FileTypeNode.ChildNodes['header'].NodeValue;
    l := length(HeadDB[i]);
    if (l > ReadFileHeaderSize) then
      ReadFileHeaderSize := l;
    ExtDB[i] := FileTypeNode.ChildNodes['extension'].NodeValue;
    SigDB[i] := FileTypeNode.ChildNodes['description'].NodeValue;
  end;
  FilesDropped := False;
  ReadFileHeaderSize := (ReadFileHeaderSize + 1) div 3;
end;

procedure TfrmType.FormDestroy(Sender: TObject);
begin
  // Cancel acceptance of file drops
  DragAcceptFiles(Self.Handle, False);
end;

procedure TfrmType.strgrdDblClick(Sender: TObject);
begin
  //Make sure files were dropped, otherwise program would crash
  if not FilesDropped then
    Exit;
  SelectedFileName := FullFilesNames[strgrd.Row - 1];
  //Stop if selected file > 2GB
  if GetSizeOfFile(SelectedFileName) > 2147483648 then
  begin
    showmessage('Sorry, files larger than 2GB are not supported for analysis!');
    Exit;
  end;
  if frmHisto.Visible = False then
    frmHisto.Visible := True
  else
    frmHisto.Visible := False;
end;

procedure TfrmType.strgrdDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
begin
  //Make sure files were dropped, otherwise program would crash
  if (not FilesDropped) or (ARow < 1) or ((ACol <> 1) and (ACol <> 5)) then
    Exit;
  with strgrd.Canvas do
  begin
    if (ExtensionMatches[ARow] = True) then
    begin
      Font.Color := clBlack;
      Font.Style := [];
    end
    else
    begin
      Font.Color := clRed;
      Font.Style := [fsBold];
    end;
    TextRect(Rect, Rect.Left, Rect.Top, strgrd.Cells[ACol, ARow]);
  end;
end;

procedure TfrmType.WMDropFiles(var Msg: TWMDropFiles);
var
  i, j, FileCount: Integer;
  Catcher: TFileCatcher; //File catcher class
  FullName, FileHeader: string;
  ThisFileSize: Int64;
begin
  inherited;
  // Create file catcher object to hide all messy details
  Catcher := TFileCatcher.Create(Msg.Drop);
  FileCount := Pred(Catcher.FileCount) + 1; //Not sure why +1 needed
  strgrd.visible := False;
  strgrd.RowCount := FileCount + 1; //+1 for header
  SetLength(ExtensionMatches, FileCount + 1);
  for i := 0 to FileCount do
    ExtensionMatches[i] := True;
  FullFilesNames := TStringList.Create;
  try
    // Try to add each dropped file to display
    for i := 0 to FileCount - 1 do  //-1 due to base 0
    begin
      Application.ProcessMessages;
      //Get file properties
      FullName := Catcher.Files[i];
      FullFilesNames.Add(FullName);
      ThisFileSize := GetSizeOfFile(FullName);
      FileHeader := ReadFileHeader(FullName);
      //Populate StringGrid
      strgrd.Cells[0, i + 1] := ExtractFileNameWoExt(FullName);
      strgrd.Cells[1, i + 1] := UpperCase(StringReplace(ExtractFileExt(FullName), '.', '', []));
      strgrd.Cells[2, i + 1] := IntToStrDelimited(ThisFileSize div 1024);
      strgrd.Cells[3, i + 1] := FileHeader;
      //Identify file header
      strgrd.Cells[5, i + 1] := '';
      for j := 0 to DBsize - 1 do
        if CompareVsHeader(FileHeader, HeadDB[j]) then
        begin
          strgrd.Cells[4, i + 1] := SigDB[j];
          strgrd.Cells[5, i + 1] := ExtDB[j];
          Break;
        end;
      //Flag discrepancies for stringgrid highlighting
      if (Pos(strgrd.Cells[1, i + 1], strgrd.Cells[5, i + 1]) = 0) then
        ExtensionMatches[i + 1] := False;
      //If no match was found: mark as unknown
      if (strgrd.Cells[5, i + 1] = '') then
      begin
        strgrd.Cells[4, i + 1] := 'Unknown, maybe text based';
        strgrd.Cells[5, i + 1] := '?';
      end;
    end;
    FilesDropped := True;
  finally
    Catcher.Free;
  end;
  // Notify Windows we handled message
  Msg.Result := 0;
  strgrd.visible := True;
end;

end.

