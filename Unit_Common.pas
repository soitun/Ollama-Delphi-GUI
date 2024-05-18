unit Unit_Common;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Types;

type
  TTransCountryCode = (otcc_KO = 0, otcc_EN);

const
  C_Version     = 'v 0.9.1 - beta (2024.05.18)';
  C_MainCaption = 'Ollama Chat CLient '+C_Version;
  C_CoptRights  = '- Copyright ' + Char(169) + ' 2024 - JNJ Labs. Seoul, Korea. All Rights Reserved. -';

const
  C_BTdivGB = 1073741824;
  C_BTdivMB = 1048576;

const
  C_LanguageCode: array [0 .. 10] of string = ('en','ko','ja','zh','hi','fr','de','it','pt','ru','es');
  C_UTF8_LF = #10;
  C_CRLF = #13#10;

function GetUsersWindowsLanguage: string;
function Get_LocaleIDString(const AFlag: Integer = 0): string;
function IOUtils_ReadAllText(const AFilePath: string=''): string;
function IOUtils_WriteAllText(const AFilePath, AContents: string): Boolean;
function Get_SystemInfo(): string;
function Get_DisplayJson(const RespType: Integer; const ModelsFlag: Boolean; const RespStr: string): string;
function Get_DisplayJson_Models(const RespStr: string; var VIndex: Integer): string;
function MSecsToTime(const AMSec: Int64): string;
function MSecsToSeconds(const AMSec: Int64): string;
procedure Global_TrimAppMemorySizeEx(const AStrategy: Integer);
function GetGlobalMemoryUsed2GB(var VTotal, VAvail: string): DWord;

var
  CV_AppPath: string = '';
  CV_TmpPath: string = 'temp';
  CV_LocaleID: string = 'en';

implementation

uses
  System.IOUtils,
  Winapi.PsAPI,
  System.JSON,
  System.JSON.Readers,
  System.JSON.Writers,
  System.JSON.Types,
  Unit_SysInfo,
  Vcl.Styles,
  Vcl.StyleAPI,
  Vcl.Forms;

function IOUtils_ReadAllText(const AFilePath: string=''): string;
begin
  if FileExists( AFilePath ) then
  Result := System.IOUtils.TFile.ReadAllText( AFilePath );
end;

function IOUtils_WriteAllText(const AFilePath, AContents: string): Boolean;
begin
  Result := False;
  System.IOUtils.TFile.WriteAllText( AFilePath, AContents );
  Result := FileExists( AFilePath );
end;

function Get_SystemInfo(): string;
const
  c_Processors: array [TPJProcessorArchitecture] of string = ('paUnknown', 'paX64', 'paIA64', 'paX86');

begin
  Result := '';//+C_CRLF;

  with TPJComputerInfo do
    begin
      Result := Result+'  Computer Name: '+ ComputerName +C_CRLF;
      Result := Result+'  - User Name: '+ Username +C_CRLF;
      Result := Result+'  - Processor Name: '+ ProcessorName +C_CRLF;
      Result := Result+'  - Processor Speed (GHz): '+ Format('%.3f', [ProcessorSpeedMHz / 1024]) +C_CRLF;
      Result := Result+'  - Processor Count: '+ Integer(ProcessorCount).ToString +C_CRLF;
      Result := Result+'  - Processor Architecture: '+ c_Processors[Processor] +C_CRLF;
      Result := Result+'  - Processor Identifier: '+ ProcessorIdentifier +C_CRLF;
    end;

  var _totalmem: string := '';
  var _availmem: string := '';
  var _usagepct: DWord := GetGlobalMemoryUsed2GB(_totalmem, _availmem);
  Result := Result+C_CRLF;
  Result := Result+'  Memory status at present'+C_CRLF;
  Result := Result+'  _ Total Memory: '+ _totalmem +C_CRLF;
  Result := Result+'  - Available Memory: '+ _availmem +C_CRLF;
  Result := Result+'  - Usage percent: '+ _usagepct.ToString +' %'+C_CRLF+C_CRLF;

  var _LocaleID: string := Get_LocaleIDString();
  var _WinLangusage := GetUsersWindowsLanguage;
  Result := Result+'  OS Language: '+_WinLangusage + '  ['+_LocaleID+']';
end;

function Get_DisplayJson(const RespType: Integer; const ModelsFlag: Boolean; const RespStr: string): string;
const
  c_MSGType: array [0 .. 2] of string = ('response', 'content', 'trans');

begin
  Result := '';
  var _parsingsrc_0 := StringReplace(RespStr, C_UTF8_LF, ',',[rfReplaceAll]);
  var _parsingsrc_1 := '{"Ollama":['+_parsingsrc_0+']}';
  var _acceptflag: Boolean := False;
  var _key: String := c_MSGType[RespType];
  if ModelsFlag then
    begin
      Result := ' * Model in loaded : ';
      _key := 'model';
    end;

  var _StringReader: TStringReader := TStringReader.Create(_parsingsrc_1);
  var _JsonReader: TJsonTextReader := TJsonTextReader.Create(_StringReader);
  try
    while _JsonReader.read do
      case _JsonReader.TokenType of
        TJsonToken.PropertyName:
          begin
            _acceptflag := SameText(_JsonReader.Value.ToString, _key);
            if not  _acceptflag then
            Continue;
          end;
        TJsonToken.String:
          begin
            if _acceptflag then
            begin
              _acceptflag := False;
              Result := Result + _JsonReader.Value.ToString;
            end;
          end;
      end;
  finally
    FreeAndNil(_JsonReader);
    FreeAndNil(_StringReader);
  end;
end;

function Get_DisplayJson_Models(const RespStr: string; var VIndex: Integer): string;
begin
  Result := 'Models List at '+FormatDateTime('yyyy-mm-dd HH:NN:SS', Now) +C_CRLF+C_CRLF;

  var _StringReader: TStringReader := TStringReader.Create(RespStr);
  var _JsonReader: TJsonTextReader := TJsonTextReader.Create(_StringReader);
  var _firstflag: Boolean := True;
  var _childflag: Boolean := False;
  var _sizeflag: Boolean := False;
  var _firstname: string := '';
  var _prefix: string := '';
  var _arrayflag: Boolean := False;
  var _key: string := 'name';
  var _fstobject: string := 'models';
  try
    while _JsonReader.read do
      case _JsonReader.TokenType of
        TJsonToken.StartObject:;
        TJsonToken.Startarray:
          if not SameText(_JsonReader.Path, _fstobject) then
            _arrayflag := True;
        TJsonToken.PropertyName:
          begin
            if _firstflag then
            begin
              _firstflag := False;    // Skip for "models"
              Continue;
            end;

            _firstname := _JsonReader.Value.ToString;
            if SameText(_firstname, _key) then
              begin
                Inc(Vindex);
                _prefix := '';
                _childflag := False;
                _arrayflag := False;
                _sizeflag  := False;
                Result := Result + 'Models ['+Vindex.ToString+'] : ';
                Continue;
              end
            else
            if SameText(_firstname, 'details') then
              begin
                Result := Result + _prefix +  _JsonReader.Value.ToString+' : '+ C_CRLF;
                _prefix := '    - ';
                _childflag := True;
                Continue;
              end
            else
              begin
                if not _childflag then
                  _prefix := '  . ';
              end;

            _sizeflag := SameText(_firstname, 'size');
            Result := Result + _prefix + _JsonReader.Value.ToString+' : ';
          end;
        TJsonToken.String, TJsonToken.Float, TJsonToken.Boolean:
          if _arrayflag then
             Result := Result + _JsonReader.Value.ToString +', '
           else
            Result := Result + _JsonReader.Value.ToString+ C_CRLF;
        TJsonToken.Integer:
          if _sizeflag then
            begin
              var _newvalue: string := Format('%.3f GB', [(_JsonReader.Value.AsInt64 / C_BTdivGB)]);
              Result := Result + _newvalue+ C_CRLF;
            end;
        TJsonToken.Null:
          Result := Result + C_CRLF;
        TJsonToken.Endarray:
          begin
            if not SameText(_JsonReader.Path, _fstobject) then
              begin
                Result := Result + C_CRLF;
              end;
            _arrayflag := False;
          end;
        TJsonToken.EndObject:;
      end;
  finally
    FreeAndNil(_JsonReader);
    FreeAndNil(_StringReader);
  end;
end;

function GetGlobalMemoryUsed2GB(var VTotal, VAvail: string): DWord;
begin
  Result := 0;
  var _MemBuffer: _MEMORYSTATUS;
  GlobalMemoryStatus(_MemBuffer);

  VTotal := Format('%.3f GB', [(_MemBuffer.dwTotalPhys / C_BTdivGB)]);
  VAvail := Format('%.3f GB', [(_MemBuffer.dwAvailPhys / C_BTdivGB)]);
  Result := _MemBuffer.dwMemoryLoad;
end;

procedure Global_TrimAppMemorySizeEx(const AStrategy: Integer);
begin
  if AStrategy = 0 then
  begin
    var _MainHandle: THandle := Winapi.Windows.OpenProcess(PROCESS_ALL_ACCESS, False, Winapi.Windows.GetCurrentProcessID);
    if _MainHandle > 0 then
    try
      Winapi.Windows.SetProcessWorkingSetSize(_MainHandle, High(SIZE_T), High(SIZE_T));   // Win64
    finally
      Winapi.Windows.CloseHandle(_MainHandle);
    end;
  end;
  Application.ProcessMessages;
end;

function GetProcessMemory2MB: string;
var
  _MemCounters: TProcessMemoryCounters;
begin
  Result := '';
  _MemCounters.cb := SizeOf(_MemCounters);
  if GetProcessMemoryInfo(GetCurrentProcess, @_MemCounters, SizeOf(_MemCounters)) then
    begin
      var _result: NativeUInt := _MemCounters.WorkingSetSize;
      Result := Format('%.3f MB', [ _result / C_BTdivMB ]);
    end
  else
    RaiseLastOSError;
end;

function MSecsToTime(const AMSec: Int64): string;
begin
  var _dt: TDateTime := AMSec / MSecsPerSec / SecsPerDay;
  Result := FormatDateTime('hh:nn:ss.zzz', Frac(_dt));
end;

function MSecsToSeconds(const AMSec: Int64): string;
begin
  var _dt: TDateTime := AMSec / MSecsPerSec;
  Result := Format('%.3f sec', [_dt]);
end;

{ System for LocaleName / Windows Kernal ... }

const
  LOCALE_NAME_MAX_LENGTH = 85;

function LCIDToLocaleName(Locale: LCID; lpName: LPWSTR; cchName: Integer; dwFlags: DWORD): Integer; stdcall;external kernel32 name 'LCIDToLocaleName';

function Get_LocaleName():  string;
var
  _strNameBuffer: array [0 .. LOCALE_NAME_MAX_LENGTH - 1] of WideChar;
begin
  Result := '';
  if (LCIDToLocaleName(1033, _strNameBuffer, LOCALE_NAME_MAX_LENGTH, 0) = 0) then
    RaiseLastOSError
  else
    Result := _strNameBuffer;

  if (LCIDToLocaleName(1041, _strNameBuffer, LOCALE_NAME_MAX_LENGTH, 0) = 0) then
    RaiseLastOSError
  else
   Result := Result +'  /  '+_strNameBuffer;
end;

function Get_LocaleIDString(const AFlag: Integer = 0): string;
var
  _strNameBuffer: array [0 .. 255] of WideChar;
begin
  Result := 'en';
  if (LCIDToLocaleName(LOCALE_USER_DEFAULT, _strNameBuffer, 255, 0) > 0) then
    for var _i := 0 to 255 do
      begin
        if _strNameBuffer[_i] = #0 then
          Break
        else
          Result := Result + _strNameBuffer[_i];
      end;

  if (Length(Result) = 0) and (LCIDToLocaleName(0, _strNameBuffer, 255, 0) > 0) then
    for var _i := 0 to 255 do
      begin
        if _strNameBuffer[_i] = #0 then
          Break
        else
          Result := Result + _strNameBuffer[_i];
      end;

  if Length(Result) = 0 then
    Result := 'NR-NR' // defaulting to [No Reply - No Reply]
  else
    if AFlag = 1 then
    begin
       Result := LowerCase(Copy(Result, 1,2));
    end;
end;

function GetUserDefaultUILanguage: LANGID; stdcall; external 'kernel32';

function GetUsersWindowsLanguage: string;
var
  _WinLanguage: array [0..50] of char;
begin
  VerLanguageName(GetUserDefaultUILanguage, _WinLanguage, 50);
  Result := _WinLanguage;
end;

initialization
  CV_LocaleID := Get_LocaleIDString(1);


end.
