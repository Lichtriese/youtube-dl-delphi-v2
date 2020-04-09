unit FH.YouTube;

interface

uses
  System.Classes,
  System.Json,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.DateUtils,
  System.SyncObjs,
  System.RegularExpressions,
  System.NetEncoding,
  System.Net.HttpClient,
  System.Net.Socket,
  System.Net.URLClient,
  FH.YouTube.Utils,
  FH.YouTube.Decipher;

type     
  ICDNMediaTag = interface
  ['{9F340235-2699-4181-B826-4BB9A068AE15}']
    function GetTag(): Integer; stdcall;
  end;

  ICDNMediaStream = interface   
  ['{47A45292-DA57-4360-8E12-56BD6127777F}']
    function GetURL(): WideString; stdcall;
    function GetMediaType():WideString; stdcall;
    function GetITag(): ICDNMediaTag; stdcall;
  end;

  ICDNMediaThumbnail = interface
  ['{5CC05A46-F708-4940-BF25-12BBAFC9E70C}']
    function GetURL(): WideString; stdcall;
  end;

  ICDNMediaStreams = interface
  ['{8FDBE905-FE88-4536-B13D-D82BF9D5C65E}']
    
  end;

  ICDNMediaInfo = interface
  ['{EE23D72D-B8F3-4655-9234-6CA7262EBCF8}']
    function GetMediaStreams(): ICDNMediaStreams; stdcall;
    function GetTitle(): WideString; stdcall;
    function GetThumbnail(): ICDNMediaThumbnail; stdcall;
    function GetAuthor(): WideString; stdcall;
    function GetVideoID(): WideString; stdcall;
  end;

  ICDNMediaDownloader = interface
  ['{8015076A-F5C7-4E55-B8F1-079D589F7D4D}']
    procedure Download(AFileName: string; AOnReceiveData: TDownloadReceive;  AOnComplete: TDownloadComplete;  AOnBeforeStart: TDownloadBeforeStart);
  end;

  IVideoHostingService = interface
  ['{7AA18828-84F0-4FDD-98B7-9863D38F2AAF}']
  end;

type
  TYouTubeClient = class;

  TYouTubeStream = class
  private
    FOwner              : TYouTubeClient;
    FURL                : TURI;
    FITag               : integer;
    FType               : string;
    FSIG                : string;
    FS                  : string;
    FQualityLabel       : string;
    FQuality            : string;
    FSize               : string;
    FBitrate            : integer;
    FCodecs             : string;
    FFPS                : double;
    FContentLength      : integer;
    FDuration           : integer;
    procedure StreamPropertyParse(AStreamProperty: TJSONValue);
    function GetURL: TURI;
  public
    constructor Create(const AOwner: TYouTubeClient; const AStreamProperty: TJSONValue); overload;
    destructor Destroy; override;
    property URL : TURI read GetURL;
    property ITag : integer read FITag;
    property MediaType : string read FType;
    property SIG : string read FSIG;
    property S : string read FS;
    property Quality: string read FQuality;
    property QualityLabel: string read FQualityLabel;
    property Size: string read FSize;
    property Bitrate: integer read FBitrate;
    property Codecs: string read FCodecs;
    property FPS: double read FFPS;
    property ContentLength: integer read FContentLength;
    property Duration: integer read FDuration;
    function Download(AFileName: string; AOnReceiveData: TDownloadReceive;  AOnComplete: TDownloadComplete;  AOnBeforeStart: TDownloadBeforeStart): TDownloadHTTP;
  end;

  TYouTubeStreams = class(TObjectList<TYouTubeStream>)
  end;

  TYouTubeURL = record
  private
    FURL      : string;
    FProtocol : string;
    FSubdomain: string;
    FDomain   : string;
    FPath     : string;
    FVideoID  : string;
    function GetURL: string;
    function GetEmbedUrl: string;
  public
    class function ValidateUrl(const AUrl: string): boolean; overload; static;
    class function ValidateUrl(const AUrl: string; out AYouTubeURL: TYouTubeURL): boolean; overload; static;
    class function Create(const AUrl: string): TYouTubeURL; overload; static;
    function isEmbed    : boolean;
    property ToString   : string read GetURL;
    property Url        : string read GetURL;
    property EmbedUrl   : string read GetEmbedUrl;
    property Protocol   : string read FProtocol;
    property Subdomain  : string read FSubdomain;
    property Domain     : string read FDomain;
    property Path       : string read FPath;
    property VideoID    : string read FVideoID;
  end;

  TYouTubeClient = class
  private
    FURI                : TYouTubeURL;
    FEncoding           : TEncoding;
    FVideoInfo           : TJSONObject;

    FYouTubeStreams     : TYouTubeStreams;
    FYouTubeThumbnail   : TYouTubeThumbnail;
    function GetTitle: string;

    function GetAuthor: string;
    function GetFmtStreamMap: string;
    function GetAdaptiveFmts: string;
    function GetThumbnailUrl: TURI;
    function GetLengthSeconds: integer;
    function GetKeywords: TArray<string>;
    function GetVideoID: string;

    procedure ParseStreams;
  public
    constructor Create(AURI: string); overload;
    destructor Destroy; override;
    property URI: TYouTubeURL read FURI;

    property VideoInfo: TJSONObject read FVideoInfo write FVideoInfo;
    property Streams: TYouTubeStreams read FYouTubeStreams;
    property Title: string read GetTitle;
    property Thumbnail: TYouTubeThumbnail read FYouTubeThumbnail;
    property Duration: integer read GetLengthSeconds;
    property Author: string read GetAuthor;
    property VideoId: string read GetVideoID;
    property Keywords: TArray<string> read GetKeywords;

    class function ParseEmbeded(const AUrl: string): TJSONObject; static;
    class function ParseYTPlayer(AResponseData: string): TJSONObject;  static;
    class function DownloadWebPage(const AURL: string): string; static;
    class function GetVideoInfo(const AUrl: string): TJSONObject; static;
    class function GetVideoTitle(const AUrl: string): string; static;
    class function GetDesriptionHTML(const AWebPage: string): string; static;
    class function GetTitleHTML(const AWebPage: string): string; static;
    class function GetJSPlayerUrlHTML(const AWebPage: string): string; static; deprecated 'not use';
    class function BuildDecipherScript(const AJSPlayerUrl: string): string; static;
    class function GetDatePublishedHTML(const AWebPage: string): string; static;
  end;

implementation

class function TYouTubeURL.Create(const AUrl: string): TYouTubeURL;
const
  //cYouTubeUrlRegExp = '(?:.+?)?(?:\/v\/|watch\/|\?v=|\&v=|youtu\.be\/|\/v=|^youtu\.be\/)(?<VideoID>[a-zA-Z0-9_-]{11})+';
  cYouTubeUrlRegExp = '(?P<YouTubeURL>(?P<Protocol>(?:https?:)?\/\/)?(?P<Subdomain>(?:www|m)\.)?(?P<Domain>(?:youtube\.com|youtu.be))(?P<Path>\/(?:[\w\-]+\?v=|embed\/|v\/)?)(?P<VideoID>[a-zA-Z0-9_-]{11})+)';
var
  LRegEx      : TRegEx;
begin
  try
    if AUrl.IsEmpty then
      exit;

    FillChar(result, SizeOf(TYouTubeURL), #0);

    LRegEx := TRegEx.Create(cYouTubeUrlRegExp, [roIgnoreCase, roMultiLine]);
    if LRegEx.IsMatch(AUrl) then
    begin
      Result.FURL := LRegEx.Match(AUrl).Groups['YouTubeURL'].Value;
      Result.FProtocol := LRegEx.Match(AUrl).Groups['Protocol'].Value;
      Result.FSubdomain := LRegEx.Match(AUrl).Groups['Subdomain'].Value;
      Result.FDomain := LRegEx.Match(AUrl).Groups['Domain'].Value;
      Result.FPath := LRegEx.Match(AUrl).Groups['Path'].Value;
      Result.FVideoID := LRegEx.Match(AUrl).Groups['VideoID'].Value;
    end;

  except
    ;
  end;
end;


class function TYouTubeURL.ValidateUrl(const AUrl: string): boolean;
begin
  result := not TYouTubeURL.Create(AUrl).ToString.IsEmpty
end;

class function TYouTubeURL.ValidateUrl(const AUrl: string; out AYouTubeURL: TYouTubeURL): boolean;
begin
  AYouTubeURL := TYouTubeURL.Create(AUrl);
  result := not AYouTubeURL.ToString.IsEmpty;
end;

function TYouTubeURL.GetURL: string;
begin
  result := FURL;
end;

function TYouTubeURL.GetEmbedUrl: string;
begin
  result := Format('%swww.youtube.com/embed/%s',[Self.FProtocol, Self.VideoID]);
end;


function TYouTubeURL.isEmbed: boolean;
begin
  result := false;
  if pos('embed', Self.FPath) > 0  then
    result := true;
end;

(*  *)
constructor TYouTubeStream.Create(const AOwner: TYouTubeClient; const AStreamProperty: TJSONValue);
begin
  inherited Create;
  FOwner := AOwner;
  StreamPropertyParse(AStreamProperty);
end;

destructor TYouTubeStream.Destroy;
begin
  inherited Destroy;
end;

function TYouTubeStream.GetURL: TURI;
var
  i             : integer;
  LJSONValue    : TJSONvalue;
  LPlayerPage   : string;
begin
  try
    // Try Decipher
    if not Self.FS.IsEmpty then
    begin
      if Self.FOwner.VideoInfo.TryGetValue<TJSONValue>('player_url', LJSONValue) then
      begin
        if not LJSONValue.Value.IsEmpty then
        begin
          LPlayerPage := Self.FOwner.DownloadWebPage(LJSONValue.Value);
          if not LPlayerPage.IsEmpty then
          begin
            Self.FSIG := TYouTubeSig.Decipher(LPlayerPage, Self.FS);
          end;
        end;
      end;

      // remove old signature from url if present
      for I := 0 to Length(Self.FURL.Params) - 1 do
      begin
        if SameText(Self.FURL.Params[i].Name, 'sig') then
        begin
          Self.FURL.DeleteParameter(i);
          Break;
        end;
      end;

      // add  decipher signature to url
      if Self.FSIG <> '' then
      Self.FURL.AddParameter('sig', Self.FSig) else
      Self.FURL.AddParameter('sig', Self.FS);

    end;
  finally
    result := Self.FURL
  end;
end;

procedure TYouTubeStream.StreamPropertyParse(AStreamProperty: TJSONValue);

function ExistsParameter(const Params: TURIParameters; const AName: string): boolean;
var
  I: Integer;
  LName: string;
begin
  Result := false;
  LName := TNetEncoding.URL.EncodeQuery(AName);
  for I := 0 to Length(Params) - 1 do
    if Params[I].Name = LName then
      Exit(true);
end;

var
  i: integer;
  v,v1: TJSONValue;
  s: string;
  sa: TArray<string>;
begin
  with AStreamProperty do
  begin
    if TryGetValue('quality', v) then
    FQuality := TNetEncoding.URL.Decode(StringReplace(v.ToString, '"', '', [rfReplaceAll]));
    if TryGetValue('qualityLabel', v) then
    FQualityLabel := TNetEncoding.URL.Decode(StringReplace(v.ToString, '"', '', [rfReplaceAll]));
    if TryGetValue('mimeType', v) then
    begin
      s := TNetEncoding.URL.Decode(StringReplace(v.ToString, '"', '', [rfReplaceAll]));
      s := StringReplace(s, '\/', '/', [rfReplaceAll]);
      if s <> '' then
      FType := s.Split([';'])[0];
      if Pos('=', s) <> 0 then
      FCodecs := StringReplace(s.Split(['='])[1], '\', '', [rfReplaceAll]);
    end;
    if not TryGetValue('itag', v) or not TryStrToInt(v.Value, FITag) then
    FITag := 0;
    if not TryGetValue('bitrate', v) or not TryStrToInt(v.Value, FBitrate) then
    FBitrate := 0;
    if TryGetValue('width', v) and  TryGetValue('height', v1)  then
    FSize := v.Value + ' x ' + v1.Value;
    if not TryGetValue('contentLength', v) or not TryStrToInt(v.Value, FContentLength) then
    FContentLength := 0;
    if not TryGetValue('fps', v) or not TryStrToFloat(v.Value, FFPS) then
    FFPS := 0;
    if not TryGetValue('approxDurationMs', v) or not TryStrToInt(v.Value, FDuration) then
    FDuration := 0;
    if TryGetValue('cipher', v) then
    begin
      s := StringReplace(v.ToString, '"', '', [rfReplaceAll]);
      //s := TNetEncoding.URL.Decode(s);
      s := StringReplace(s, '\/', '/', [rfReplaceAll]);
      s := StringReplace(s, '\\u0026', '&', [rfReplaceAll]);
      sa := s.Split(['&']);
      for i := Low(sa) to High(sa) do
      if SameText(sa[i].Split(['='])[0], 'url') then
      begin
        FURL := TURI.Create(TNetEncoding.URL.Decode(UTF8ToString(AnsiString(sa[i].Split(['='])[1]))));
        if ExistsParameter(FURL.Params, 'ratebypass') then
        begin
          FURL.ParameterByName['ratebypass'] := 'yes';
        end else
        begin
          FURL.AddParameter('ratebypass', 'yes');
        end;
      end else
      if SameText(sa[i].Split(['='])[0], 's') then
      begin
        FS := TNetEncoding.URL.Decode(sa[i].Split(['='])[1]);
      end;
    end else
    if TryGetValue('url', v) then
    begin
      s := StringReplace(v.ToString, '"', '', [rfReplaceAll]);
      s := StringReplace(s, '\/', '/', [rfReplaceAll]);
      FURL := TURI.Create(TNetEncoding.URL.Decode(UTF8ToString(AnsiString(s))));
    end;
  end;
  if ExistsParameter(FURL.Params, 'ratebypass') then
  FURL.ParameterByName['ratebypass'] := 'yes' else
  FURL.AddParameter('ratebypass', 'yes');
end;

function TYouTubeStream.Download(AFileName: string; AOnReceiveData: TDownloadReceive; AOnComplete: TDownloadComplete; AOnBeforeStart: TDownloadBeforeStart): TDownloadHTTP;
var
  LDownloadThread : TDownloadHTTP;
begin
  LDownloadThread := TDownloadHTTP.Create(FURL.ToString);
  try
    LDownloadThread.DownloadStream := TFileStream.Create(AFileName, fmCreate);
    LDownloadThread.DownloadStream.Position := 0;
    LDownloadThread.OnReceiveData := AOnReceiveData;
    LDownloadThread.OnComplete := AOnComplete;
    //LDownloadThread.OnError :=
    LDownloadThread.OnBeforeStart := AOnBeforeStart;
    LDownloadThread.Start;
  finally
    result := LDownloadThread;
  end;
end;

(*  *)
constructor TYouTubeClient.Create(AURI: string);
begin
  if not TYouTubeURL.ValidateUrl(AURI, FURI) then
    raise Exception.Create('YouTube URL not find');

  inherited Create;
  FEncoding := TEncoding.UTF8;

  FYouTubeStreams := TYouTubeStreams.Create;
  FVideoInfo := TYouTubeClient.GetVideoInfo(FURI.ToString);
  ParseStreams;
  FYouTubeThumbnail := TYouTubeThumbnail.Create(GetThumbnailUrl);
end;

destructor TYouTubeClient.Destroy;
begin
  if Assigned(FYouTubeThumbnail) then
    FreeAndNil(FYouTubeThumbnail);
    
  if Assigned(FYouTubeStreams) then
    FreeAndNil(FYouTubeStreams);

  if Assigned(FVideoInfo) then
    FreeAndNil(FVideoInfo);
  inherited Destroy;
end;

procedure TYouTubeClient.ParseStreams;
  var
  i : integer;
  j: TJSONObject;
  v: TJSONValue;
begin
  j := TJSONObject.Create;
  j.Parse(TEncoding.UTF8.GetBytes('{"streams":' + Self.GetFmtStreamMap + '}'), 0, true);
  if j.TryGetValue('streams', v) and (v is TJSONArray) then
  with TJSONArray(v) do
  for i := 0 to Count-1 do
  FYouTubeStreams.Add(TYouTubeStream.Create(Self, Items[i]));
  FreeAndNil(j);
  j := TJSONObject.Create;
  j.Parse(TEncoding.UTF8.GetBytes('{"streams":' + Self.GetAdaptiveFmts + '}'), 0, true);
  if j.TryGetValue('streams', v) and (v is TJSONArray) then
  with TJSONArray(v) do
  for i := 0 to Count-1 do
  FYouTubeStreams.Add(TYouTubeStream.Create(Self, Items[i]));
  FreeAndNil(j);
end;

function TYouTubeClient.GetTitle: string;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('title', LJSONValue) then
    result := LJSONValue.Value;
end;

function TYouTubeClient.GetKeywords: TArray<string>;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('tags', LJSONValue) then
    result := LJSONValue.Value.Split([',']);
end;

function TYouTubeClient.GetVideoID: string;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('video_id', LJSONValue) then
    result := LJSONValue.Value;
end;

function TYouTubeClient.GetAuthor: string;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('author', LJSONValue) then
    result := LJSONValue.Value;
end;

function TYouTubeClient.GetFmtStreamMap: string;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('fmts', LJSONValue) then
    result := LJSONValue.Value;
end;

function TYouTubeClient.GetAdaptiveFmts: string;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('adaptive_fmts', LJSONValue) then
    result := LJSONValue.Value;
end;

function TYouTubeClient.GetThumbnailUrl: TURI;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('thumbnails.default', LJSONValue) then
  if LJSONValue is TJSONString then
    result := TURI.Create(TNetEncoding.URL.Decode(LJSONValue.Value));
end;

function TYouTubeClient.GetLengthSeconds: integer;
var
  LJSONValue : TJSONValue;
begin
  if FVideoInfo.TryGetValue<TJSONValue>('duration', LJSONValue) then
    result := TJSONNumber(LJSONValue).AsInt else
    Result := 0;
end;

class function TYouTubeClient.DownloadWebPage(const AURL: string): string;
var
  LHTTPClient       : THTTPClient;
  LResponse         : IHTTPResponse;
  LRequest          : IHTTPRequest;
  LResponseContent  : TStringStream;
begin
  LResponseContent := TStringStream.Create('', TEncoding.UTF8);
  try
    LHTTPClient:=THTTPClient.Create;
    try
      LHTTPClient.ContentType:='application/timestamp-query';
      LRequest := LHTTPClient.GetRequest('GET', TURI.Create(AURL));
      LRequest.AddHeader('Cookie', 'PREF=f1=50000000&hl=en');
      LResponse := IHTTPResponse(LHTTPClient.Execute(LRequest, LResponseContent));
      if (((LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300)) or (LResponse.StatusCode = 304))  then
      begin
        result := LResponseContent.DataString;
      end else
        raise Exception.CreateFmt('Error Request Content: %s [%d - %s]',[AURL, LResponse.StatusCode, LResponse.StatusText]);
    finally
      FreeAndNil(LHTTPClient);
    end;
  finally
    FreeAndNil(LResponseContent);
  end;
end;

class function TYouTubeClient.ParseYTPlayer(AResponseData: string): TJSONObject;
const
    cYTPLAYER_CONFIG_RE = ';ytplayer\.config\s*=\s*({.+?});ytplayer';
    cYTPLAYER_CONFIG1_RE = ';ytplayer\.config\s*=\s*({.+?});';
var
    LConfigObject : TJSONObject;
    LMatch        : TMatch;
    LConfigStr    : string;
begin
  Result := nil;
    try
      LConfigObject := TJSONObject.Create;
      try
        LMatch := TRegEx.Match(AResponseData, cYTPLAYER_CONFIG1_RE, [roIgnoreCase]);
        if LMatch.Groups.Count >= 2 then
        begin
          LConfigStr := LMatch.Groups.Item[1].Value;
          LConfigStr := System.NetEncoding.TNetEncoding.HTML.Decode(LConfigStr.Trim);
        end else
        begin
          LMatch := TRegEx.Match(AResponseData, cYTPLAYER_CONFIG_RE, [roIgnoreCase]);
          if LMatch.Groups.Count >= 2 then
          begin
            LConfigStr := LMatch.Groups.Item[1].Value;
            LConfigStr := System.NetEncoding.TNetEncoding.HTML.Decode(LConfigStr.Trim);
          end;
        end;
        LConfigObject.Parse(TEncoding.UTF8.GetBytes(LConfigStr), 0, true);
      finally
        result := LConfigObject.Clone as TJSONObject;
        FreeAndNil(LConfigObject);
      end;
    except  end;
end;

class function TYouTubeClient.ParseEmbeded(const AUrl: string): TJSONObject;
const
  cASSETS_RE  = '"assets":.+?"js":\s*("(?P<url>[^"]+)")';
  cPLAYER_RE =  '"url"\s*:\s*("(?P<url>[^"]+)")';
var
  LYouTebeUrl : TYouTubeUrl;
  LVideoInfo  : TJSONObject;
  LJSONObject : TJSONObject;
  LRegEx  : TRegEx;
  LEmbedUrl : string;
  LEmbedPage : string;
  LVideoInfoUrl : TURI;
  LVideoInfoPage : string;
  LStsValue : string;
  LVideoInfoArr : TArray<string>;
  I: Integer;
  LPair : TPair<string, string>;
  LAssetsUrl : string;
  LPlayerUrl : string;
  LPlayerConfig : string;
begin
  LYouTebeUrl := TYouTubeUrl.Create(AUrl);
  LEmbedUrl := LYouTebeUrl.GetEmbedUrl;
  LEmbedPage := TYouTubeClient.DownloadWebPage(LEmbedUrl);

  // GET PLAYER CONFIG
  LRegEx := TRegEx.Create('yt.setConfig\(\{\s*''PLAYER_CONFIG'':\s*(?P<PLAYER_CONFIG>{.*?})\s*}\);');
  if LRegEx.IsMatch(LEmbedPage) then
  begin
    LPlayerConfig := LRegEx.Match(LEmbedPage).Groups['PLAYER_CONFIG'].Value;
    LRegEx := TRegEx.Create(cASSETS_RE);
    if LRegEx.isMatch(LPlayerConfig) then
    begin
      LAssetsUrl := TNetEncoding.URL.Decode(LRegEx.Match(LPlayerConfig).Groups['url'].Value);
    end;
    LRegEx := TRegEx.Create(cPLAYER_RE);
    if LRegEx.isMatch(LPlayerConfig) then
    begin
      LPlayerUrl :=  TNetEncoding.URL.Decode(LRegEx.Match(LPlayerConfig).Groups['url'].Value);
    end;
  end;

  // Get Sts Value
  LStsValue := '';
  LRegEx := TRegEx.Create('"sts"\s*:\s*(?P<value>\d+)');
  if LRegEx.IsMatch(LEmbedPage) then
  begin
    LStsValue := LRegEx.Match(LEmbedPage).Groups['value'].Value;
  end;

  // Create Request
  LVideoInfoUrl := TURI.Create(Format('%swww.youtube.com/get_video_info',[LYouTebeUrl.FProtocol]));
  LVideoInfoUrl.AddParameter('video_id', LYouTebeUrl.VideoID);
  LVideoInfoUrl.AddParameter('eurl', 'https://youtube.googleapis.com/v/' + LYouTebeUrl.VideoID);
  LVideoInfoUrl.AddParameter('sts', LStsValue);

  // Get  get_video_info
  LVideoInfoPage := DownloadWebPage(LVideoInfoUrl.ToString);

  // Split Response Values
  LVideoInfoArr := LVideoInfoPage.Split(['&']);

  LJSONObject  := TJSONObject.Create;
  try
    LVideoInfo  := TJSONObject.Create;
    try
      for I := 0 to Length(LVideoInfoArr) - 1 do
      begin
        try
          LPair := TPair<string, string>.Create(LVideoInfoArr[i].Split(['='])[0], System.NetEncoding.TNetEncoding.URL.Decode(LVideoInfoArr[i].Split(['='])[1]));
          if SameText(LPair.Value, 'true') then
            LVideoInfo.AddPair(TJSONPair.Create(LPair.Key, TJSONTrue.Create()))
          else if SameText(LPair.Value, 'false') then
             LVideoInfo.AddPair(TJSONPair.Create(LPair.Key, TJSONFalse.Create()))
          else
            LVideoInfo.AddPair(TJSONPair.Create(LPair.Key, TJSONString.Create(LPair.Value)));
        except
          ;
        end;
      end;
    finally
      LJSONObject.AddPair('args', LVideoInfo)
    end;

    if not LAssetsUrl.IsEmpty then
     LJSONObject.AddPair('assets', TJSONObject.Create(TJSONpair.Create('js', LAssetsUrl)));
    if not LPlayerUrl.IsEmpty then
     LJSONObject.AddPair('url', TJSONString.Create(LPlayerUrl));

    result := LJSONObject.Clone as TJSONObject;
  finally
    FreeAndNil(LJSONObject);
  end;
end;

class function TYouTubeClient.GetVideoTitle(const AUrl: string): string;
var
  LYouTubeClient : TYouTubeClient;
begin
  LYouTubeClient := TYouTubeClient.Create(AUrl);
  try
    result := LYouTubeClient.Title;
  finally
    FreeAndNil(LYouTubeClient);
  end;
end;

class function TYouTubeClient.GetDesriptionHTML(const AWebPage: string): string;
var
   LRegEx : TRegEx;
   LDescription : string;
begin

  if AWebPage.Contains('eow-description') then
  begin
    Result := THtmlHelper.GetElementById('eow-description', AWebPage);
     (*

        video_description = get_element_by_id("eow-description", video_webpage)
        if video_description:
            video_description = re.sub(r'''(?x)
                <a\s+
                    (?:[a-zA-Z-]+="[^"]*"\s+)*?
                    (?:title|href)="([^"]+)"\s+
                    (?:[a-zA-Z-]+="[^"]*"\s+)*?
                    class="[^"]*"[^>]*>
                [^<]+\.{3}\s*
                </a>
            ''', r'\1', video_description)
            video_description = clean_html(video_description)

     *)
  end else
  begin
    LRegEx := TRegEx.Create('<meta name="description" content="(?P<description>[^"]+)"');
    if LRegEx.isMatch(AWebPage) then
    begin
      result :=  System.NetEncoding.THTMLEncoding.HTML.Decode(LRegEx.Match(AWebPage).Groups['description'].Value);
    end;
  end;
end;

class function TYouTubeClient.GetDatePublishedHTML(const AWebPage: string): string;
var
   LRegEx : TRegEx;
begin
  LRegEx := TRegEx.Create('<meta itemprop="datePublished" content="(?P<datePublished>[^"]+)"');
  if LRegEx.isMatch(AWebPage) then
  begin
    result := LRegEx.Match(AWebPage).Groups['datePublished'].Value;
  end;
end;

class function TYouTubeClient.GetTitleHTML(const AWebPage: string): string;
var
   LRegEx : TRegEx;
   LTitle : string;
begin
  if AWebPage.Contains('eow-title') then
  begin
    LTitle := THtmlHelper.GetElementById('eow-title', AWebPage);
  end else
  begin
    LRegEx := TRegEx.Create('<meta name="name" content="(?P<title>[^"]+)"');
    if LRegEx.isMatch(AWebPage) then
    begin
      result := System.NetEncoding.THTMLEncoding.HTML.Decode(LRegEx.Match(AWebPage).Groups['title'].Value);
    end;
  end;
end;

class function TYouTubeClient.GetJSPlayerUrlHTML(const AWebPage: string): string;
const
  cASSETS_RE  = '"assets":.+?"js":\s*("(?P<assets_url>[^"]+)")';
  cPLAYER_RE =  'ytplayer\.config.*?"url"\s*:\s*("(?P<ytplayer_url>[^"]*)")';

  cPLAYER_URL_RE= '(?P<URL>(?:https|http):(?:\/|\\)+([a-zA-Z0-9\-\.\/\\]+)((?:player-([^/]+)(?:\/|\\)watch_as3)\.swf|(?:player-([^/]+)(?:\/|\\)base)\.js))';
var
   LRegEx     : TRegEx;
   LPlayerUrl : string;
   LAssetsUrl : string;
begin
  Result := '';

  LRegEx := TRegEx.Create(cASSETS_RE);
  if LRegEx.isMatch(AWebPage) then
  begin
    LAssetsUrl := TNetEncoding.URL.Decode(LRegEx.Match(AWebPage).Groups['assets_url'].Value);
  end;

  LRegEx := TRegEx.Create(cPLAYER_RE);
  if LRegEx.isMatch(AWebPage) then
  begin
    LPlayerUrl :=  TNetEncoding.URL.Decode(LRegEx.Match(AWebPage).Groups['ytplayer_url'].Value);
  end;

  if LPlayerUrl.IsEmpty then
  begin
    LRegEx := TRegEx.Create(cPLAYER_URL_RE);
    if LRegEx.isMatch(AWebPage) then
    begin
      LPlayerUrl :=  TNetEncoding.URL.Decode(LRegEx.Match(AWebPage).Groups['URL'].Value);
    end;
  end;
  LAssetsUrl := StringReplace(LAssetsUrl, '\/', '/', [rfReplaceAll, rfIgnoreCase]);
  LPlayerUrl := StringReplace(LPlayerUrl, '\/', '/', [rfReplaceAll, rfIgnoreCase]);

  if not LAssetsUrl.IsEmpty and not LPlayerUrl.IsEmpty then
    result := TURI.PathRelativeToAbs(LAssetsUrl, TURI.Create(LPlayerUrl));
end;


class function TYouTubeClient.BuildDecipherScript(const AJSPlayerUrl: string): string;
const
  cPLAYERPARSE_RE= '.*?-(?P<id>[a-zA-Z0-9_-]+)(?:/watch_as3|/html5player(?:-new)?|/base)?\.(?P<ext>[a-z]+)$"';
  cJSPLAYER1_RE = 'html5player-([^/]+?)(?:/html5player(?:-new)?)?\.js';
  cJSPLAYER_RE = '(?:www|player)-([^/]+)/base\.js';
  cSWFPLAYER_RE = '-(.+?)(?:/watch_as3)?\.swf';
var
  LRegEx      : TRegEx;
begin
    LRegEx := TRegEx.Create(cPLAYERPARSE_RE);
    if LRegEx.isMatch(result) then
    begin
      //LPlayerUrl := LRegEx.Match(result).Groups['id'].Value;
      //LPlayerUrl := LRegEx.Match(result).Groups['ext'].Value;
    end;
end;

class function TYouTubeClient.GetVideoInfo(const AUrl: string): TJSONObject;
var
  LJSONObject         : TJSONObject;
  LJSONObject2        : TJSONObject;
  LVideoInfo          : TJSONObject;
  LThumbnails         : TJSONObject;
  LJSONValue          : TJSONValue;
  LWebPage,s          : string;
  LValueStr           : string;
  LUrlValueStr        : string;
  LAgeGate            : boolean;
begin
  LVideoInfo := nil;
  LAgeGate := false;
  LValueStr := '';
  LWebPage := '';

  try
    LWebPage := TYouTubeClient.DownloadWebPage(AURL);
  except end;

  if TYouTubeURL.Create(AURL).isEmbed or LWebPage.IsEmpty then
  begin
    LVideoInfo := ParseEmbeded(AURL);
  end else
  if LWebPage.Contains('player-age-gate-content">') then
   begin
      LAgeGate := true;
      LVideoInfo := ParseEmbeded(AURL);
   end else
     LVideoInfo := ParseYTPlayer(LWebPage);
  try
    LJSONObject := TJSONObject.Create;
    LJSONObject2 := TJSONObject.Create;
    try
      // maps LVideoInfo to result JSONObject

      // player_url
      if LVideoInfo.TryGetValue<TJSONValue>('url', LJSONValue) then
      begin
        LUrlValueStr := LJSONValue.Value;
      end;
      if LUrlValueStr.IsEmpty then
        LUrlValueStr := 'https://www.youtube.com/';
      if LVideoInfo.TryGetValue<TJSONValue>('assets.js', LJSONValue) then
      begin
        if not LJSONValue.Value.IsEmpty and not LUrlValueStr.IsEmpty then
        begin
          try
            LValueStr := TURI.PathRelativeToAbs(LJSONValue.Value.Replace('\/', '/'), TURI.Create(LUrlValueStr.Replace('\/', '/')));
          except    end;
          if not LValueStr.IsEmpty then
            LJSONObject.AddPair(TJSONPair.Create('player_url', TJSONString.Create(LValueStr)));
        end;
      end;

      if LVideoInfo.TryGetValue<TJSONValue>('args.player_response', LJSONValue) then
      begin
        s := LJSONValue.Value;
        LJSONObject2.Parse(TEncoding.UTF8.GetBytes(s), 0, true);
      end;

      // fmts
      if LJSONObject2.TryGetValue<TJSONValue>('streamingData.formats', LJSONValue) then
      begin
        s := LJSONValue.ToString;
        LJSONObject.AddPair(TJSONPair.Create('fmts', TJSONString.Create(s)));
      end;
      // adaptive_fmts
      if LJSONObject2.TryGetValue<TJSONValue>('streamingData.adaptiveFormats', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('adaptive_fmts', TJSONString.Create(LJSONValue.ToString)));
      // title
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.title', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('title', TJSONString.Create(LJSONValue.Value)));
      // video_id
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.videoId', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('video_id', TJSONString.Create(LJSONValue.Value)));
      // view_count
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.viewCount', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('view_count', TJSONNumber.Create(StrToInt(LJSONValue.Value))));
      // tags
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.keywords', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('tags', TJSONString.Create(LJSONValue.Value)));
      // author & author_url
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.author', LJSONValue) then
      begin
        LJSONObject.AddPair(TJSONPair.Create('author', TJSONString.Create(LJSONValue.Value)));
        LJSONObject.AddPair(TJSONPair.Create('author_url', TJSONString.Create(Format('https://www.youtube.com/user/%s', [LJSONValue.Value]))));
      end;
      // duration
      if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.lengthSeconds', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('duration', TJSONNumber.Create(StrToInt(LJSONValue.Value))));
      // url
      if LVideoInfo.TryGetValue<TJSONValue>('args.loaderUrl', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('url', TJSONString.Create(LJSONValue.Value)));
      // thumbnails
      LThumbnails := TJSONObject.Create;
      try
        if LJSONObject2.TryGetValue<TJSONValue>('videoDetails.thumbnail.thumbnails', LJSONValue) then
        if LJSONValue is TJSONArray then
        with TJSONArray(LJSONValue) do
        begin
          s := StringReplace(Items[Count-1].P['url'].ToString, '\/', '/', [rfReplaceAll]);
          s := StringReplace(s, '"', '', [rfReplaceAll]);
          LThumbnails.AddPair(TJSONPair.Create('default', TJSONString.Create(s)));
        end;
      finally
        LJSONObject.AddPair(TJSONPair.Create('thumbnails', LThumbnails));
      end;

      // provider_name
      LJSONObject.AddPair(TJSONPair.Create('provider_name', TJSONString.Create('YouTube')));
      // provider_url
      LJSONObject.AddPair(TJSONPair.Create('provider_url', TJSONString.Create('https://www.youtube.com')));
      // uri
      if not LJSONObject.TryGetValue<TJSONValue>('url', LJSONValue) then
        LJSONObject.AddPair(TJSONPair.Create('url', TJSONString.Create(TYouTubeURL.Create(AURL).ToString)));
      // title
      if not LJSONObject.TryGetValue<TJSONValue>('title', LJSONValue) then
      begin
        LValueStr := TYouTubeClient.GetTitleHTML(LWebPage);
        LJSONObject.AddPair(TJSONPair.Create('title', TJSONString.Create(LValueStr)));
      end;
      // player_url
      if not LJSONObject.TryGetValue<TJSONValue>('player_url', LJSONValue) then
      begin
        LValueStr := TYouTubeClient.GetJSPlayerUrlHTML(LWebPage);
        LJSONObject.AddPair(TJSONPair.Create('player_url', TJSONString.Create(LValueStr)));
      end;
      // upload_date
      LValueStr := TYouTubeClient.GetDatePublishedHTML(LWebPage);
      LJSONObject.AddPair(TJSONPair.Create('upload_date', TJSONString.Create(LValueStr)));
      // description
      //LValueStr := TYouTubeClient.GetDesriptionHTML(LWebPage);
      LValueStr := '';
      LJSONObject.AddPair(TJSONPair.Create('description', TJSONString.Create(LValueStr)));
      // license
      LJSONObject.AddPair(TJSONPair.Create('license', TJSONString.Create('')));
      // age_gate
      if LAgeGate then
        LJSONObject.AddPair(TJSONPair.Create('age_gate', TJSONTrue.Create()))
      else LJSONObject.AddPair(TJSONPair.Create('age_gate', TJSONFalse.Create()));


      result := LJSONObject.Clone as TJSONObject;
    finally
      FreeAndNil(LJSONObject);
      FreeAndNil(LJSONObject2);
    end;

            //use_cipher_signature
  finally
    if assigned(LVideoInfo) then
      FreeAndNil(LVideoInfo);
  end;
end;

end.
