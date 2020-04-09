unit Unit1;

interface

uses
  System.SysUtils, System.UITypes, System.Classes, System.Variants,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Edit,
  FMX.StdCtrls, FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation,
  FH.YouTube, FH.YouTube.Utils, System.Net.URLClient, FMX.Layouts,
  FMX.TabControl, FMX.Menus, FMX.Types, FMX.Controls, FMX.ListBox;

type
  TForm1 = class(TForm)
    StatusBar1: TStatusBar;
    TabControl1: TTabControl;
    TabItem3: TTabItem;
    Memo1: TMemo;
    Layout2: TLayout;
    Button9: TButton;
    TabItem2: TTabItem;
    Memo2: TMemo;
    Layout1: TLayout;
    Button3: TButton;
    Button1: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Edit1: TEdit;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    Layout3: TLayout;
    ProgressBar1: TProgressBar;
    Label1: TLabel;
    SaveDialog1: TSaveDialog;
    ComboBox1: TComboBox;
    procedure Button9Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FYouTubeClient: TYouTubeClient;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.Button9Click(Sender: TObject);
var
  i : integer;
begin
 Memo1.Lines.Clear;
 ComboBox1.Clear;
 if Assigned(FYouTubeClient) then
 FreeAndNil(FYouTubeClient);
 FYouTubeClient := TYouTubeClient.Create(Edit1.Text);
 try
   if FYouTubeClient.VideoId = '' then
   begin
     Memo1.Lines.Add('Video not found');
     Exit;
   end;
   Memo1.Lines.Add(Format('Title: %s', [FYouTubeClient.Title]));
   Memo1.Lines.Add(Format('Author: %s', [FYouTubeClient.Author]));

   Memo1.Lines.Add(Format('VideoID: %s', [FYouTubeClient.VideoId]));
   Memo1.Lines.Add(Format('Keywords: %s', [string.Join(';', FYouTubeClient.Keywords)]));
   Memo1.Lines.Add(Format('Duration: %d sec', [FYouTubeClient.Duration]));
   Memo1.Lines.Add(Format('Thumbnail url: %s', [FYouTubeClient.Thumbnail.URL.ToString]));
   for I := 0 to FYouTubeClient.Streams.Count - 1 do
   with FYouTubeClient.Streams.Items[i] do
   begin
     Memo1.Lines.Add(Format('Stream[%d]:', [i]));
     Memo1.Lines.Add(Format('   ITag: %d', [ITag]));
     Memo1.Lines.Add(Format('   MediaType: %s', [MediaType]));
     //Memo1.Lines.Add(Format('   SIG: %s', [FYouTubeClient.Streams.Items[i].SIG]));
     //Memo1.Lines.Add(Format('   CIPHER S: %s', [FYouTubeClient.Streams.Items[i].S]));
     Memo1.Lines.Add(Format('   Quality: %s', [Quality]));
     Memo1.Lines.Add(Format('   QualityLabel: %s', [QualityLabel]));
     Memo1.Lines.Add(Format('   Screen Size: %s', [Size]));
     Memo1.Lines.Add(Format('   Duration: %s', [FormatDateTime('hh:nn:ss', Duration /( 24*60*60*1000))]));
     Memo1.Lines.Add(Format('   Used codecs: %s', [Codecs]));
     Memo1.Lines.Add(Format('   File Size: %0.2f MB', [ContentLength / 1024000]));
     ComboBox1.Items.Add(Format('Stream[%d] Type: %s ITag: %d Size: %s Length: %0.2f MB', [i, MediaType, ITag, Size, ContentLength / 1024000]))
   end;
 finally
   ComboBox1.Enabled := ComboBox1.Items.Count > 0;
   Button1.Enabled := ComboBox1.Enabled;
   if ComboBox1.Enabled and (ComboBox1.ItemIndex < 0) then
   ComboBox1.ItemIndex := 0;
 end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FYouTubeClient := nil;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FYouTubeClient) then
  FreeAndNil(FYouTubeClient);
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  LDownloadThread : TDownloadHTTP;
begin
  if not SaveDialog1.Execute then Exit;
  LDownloadThread := TDownloadHTTP.Create(FYouTubeClient.Streams.Items[ComboBox1.ItemIndex].URL.ToString);
  LDownloadThread.DownloadStream := TFileStream.Create(SaveDialog1.FileName, fmCreate);
  LDownloadThread.DownloadStream.Position := 0;
  LDownloadThread.OnReceiveData := procedure(const ASender: TObject; ASpeed: Integer; AContentLength: Int64; AReadCount: Int64; var Abort: Boolean)
      begin
        TThread.Synchronize(nil,
        procedure
        begin
           label1.Text := Format('%d KB/s', [ASpeed div 1024]);
           if AContentLength > 0 then
            progressbar1.Value := (AReadCount / AContentLength) * 100;//AReadCount;
        end);
      end;

  LDownloadThread.OnComplete :=  procedure(const Sender: TObject)
      begin
        TThread.Synchronize(nil,
        procedure
        begin
          label1.Text := Format('Finished. Average Speed: %d KB/s', [TDownloadHTTP(Sender).AverageSpeed div 1024]);
        end);
      end;

  LDownloadThread.OnError := procedure(const Sender: TObject; AMessage: string)
  begin
    TThread.Synchronize(nil,
    procedure
    begin
      showmessage(AMessage);
    end);
  end;
  LDownloadThread.OnBeforeStart :=  procedure(const Sender: TObject)
      begin
        TThread.Synchronize(nil,
        procedure
        begin
          progressbar1.Max := 100;//TDownloadHTTP(Sender).ContentSize;
          progressbar1.Min := 0;
          progressbar1.Value := 0;
        end);
      end;

  LDownloadThread.Start;

end;

procedure TForm1.Button3Click(Sender: TObject);
var
  i : integer;
begin
  for I := 0 to memo2.Lines.Count - 1 do
  begin
    memo2.Lines.Strings[i] :=  booltostr(TYouTubeURL.ValidateUrl(memo2.Lines.Strings[i]), true) + ': '+memo2.Lines.Strings[i];
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  edit1.Text := 'https://www.youtube.com/watch?v=IZ8RiSZBCaM';
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  edit1.Text := 'https://www.youtube.com/watch?v=gBAfejjUQoA';
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  edit1.Text := 'https://www.youtube.com/watch?v=LXb3EKWsInQ';
end;

procedure TForm1.Button7Click(Sender: TObject);
begin
  edit1.Text := 'https://www.youtube.com/watch?v=zbBYpZwAQvU';
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  edit1.Text := 'https://youtube.com/embed/DFYRQ_zQ-gk';

end;



end.




