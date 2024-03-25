{--------------------------------------------------------------------------
   Unit:         Main
   Programador:  Miguel Sandro Lucero
                 miguel_sandro@yahoo.com - http://www.LSIS.com.ar
   Fecha:        agosto 2002
   Descripción:  NOPPP para Windows (No-parts PIC Programmer)

   NOPPP.C (Revised) - M. Covington 1997, 1998, 1999
   Software for the "No-Parts Pic Programmer"
   Inspired by David Tait's TOPIC; compatible therewith.

   HISTORY OF MODIFICATIONS
   Converted to LINUX by Claus Fuetterer in 1999
   Watchdog-bug removed, C. Fuetterer, June 2000
   PIC read & 16F87x enhancements by Geoff McCaughan
   16F628 support added by James Padfield
   Converted to Delphi for Windows by Miguel Sandro Lucero, august 2002

---------------------------------------------------------------------------}

unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Buttons, Menus, ComCtrls;

type
  TfrmMain = class(TForm)
    MainMenu1: TMainMenu;
    Archivo1: TMenuItem;
    Programador1: TMenuItem;
    TestProgramador1: TMenuItem;
    Salir1: TMenuItem;
    DetectarProgramador1: TMenuItem;
    AbrirHex1: TMenuItem;
    N1: TMenuItem;
    dgOpen: TOpenDialog;
    N2: TMenuItem;
    ProgramarPIC1: TMenuItem;
    VerificarPIC1: TMenuItem;
    BorrarPIC1: TMenuItem;
    sb1: TStatusBar;
    Ayuda1: TMenuItem;
    Acercade1: TMenuItem;
    LeerPIC1: TMenuItem;
    GrabarHex1: TMenuItem;
    dgSave: TSaveDialog;
    GroupBox2: TGroupBox;
    GroupBox1: TGroupBox;
    lbProgramMemory: TLabel;
    lbConfig: TLabel;
    lbIDMemory: TLabel;
    lbDataMemory: TLabel;
    opPic: TRadioGroup;
    lbFileName: TLabel;
    PIC1: TMenuItem;
    edInfo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure Salir1Click(Sender: TObject);
    procedure TestProgramador1Click(Sender: TObject);
    procedure DetectarProgramador1Click(Sender: TObject);
    procedure AbrirHex1Click(Sender: TObject);
    procedure opPicClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ProgramarPIC1Click(Sender: TObject);
    procedure VerificarPIC1Click(Sender: TObject);
    procedure BorrarPIC1Click(Sender: TObject);
    procedure Acercade1Click(Sender: TObject);
    procedure LeerPIC1Click(Sender: TObject);
    procedure GrabarHex1Click(Sender: TObject);
  private

  public

  end;

var
  frmMain: TfrmMain;

implementation

uses NopUnit;

{$R *.DFM}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
     Show;
     // sb1.Panels[0].Text := 'Calculando velocidad procesador ...';
     Update;
     Puts('Calculando velocidad procesador ...', True);
     CalibrateCPU;

     //sb1.Panels[0].Text := 'Configurando programa ...';
     Puts('Configurando programa ...');
     Update;

     ClearArrays;
     AllPinSlow;

     opPic.ItemIndex := 1;
     SelectDevice(1); // PIC16F84 por defecto

     // sb1.Panels[0].Text := 'Listo';
     Puts('Listo');
     Update;

     if ParamCount > 0 then LoadHexFile(ParamStr(1));

end;

procedure TfrmMain.Salir1Click(Sender: TObject);
begin
     Close;
end;

procedure TfrmMain.TestProgramador1Click(Sender: TObject);
begin
     TroubleShoot;
end;

procedure TfrmMain.DetectarProgramador1Click(Sender: TObject);
begin
     HardwareDetect;
end;

procedure TfrmMain.AbrirHex1Click(Sender: TObject);
begin
     with dgOpen do begin
          Title := 'Abrir archivo HEX';
          InitialDir := 'D:\Noppp';
          if Execute then LoadHexFile(FileName);
     end;
end;

procedure TfrmMain.opPicClick(Sender: TObject);
begin
     SelectDevice( opPic.ItemIndex );
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
     AllPinSlow;
     // MessageDlg('Ud puede retirar el PIC del socket ahora.', mtInformation,[mbOk],0);
     Puts('Ud puede retirar el PIC del socket ahora.');
end;

procedure TfrmMain.ProgramarPIC1Click(Sender: TObject);
begin
     ProgramPic(PIC_PROGRAM);
end;

procedure TfrmMain.VerificarPIC1Click(Sender: TObject);
begin
     ProgramPic(PIC_VERIFY);
end;

procedure TfrmMain.BorrarPIC1Click(Sender: TObject);
begin
     if MessageDlg( 'Esta operación borra todo el contenido del PIC'
                    + S_LINEA + '¿Desea borrar PIC?'
                    , mtConfirmation, [mbYes, mbNo],0)=mrYes then ErasePic;
end;

procedure TfrmMain.Acercade1Click(Sender: TObject);
var
   Texto: String;
begin
     Texto := 'NOPPP - No Parts PIC Programmer by Michael A. Covington' + S_LINEA
           + S_LINEA + 'Convertido a Delphi por Miguel Sandro Lucero'
           + S_LINEA + 'miguel_sandro@yahoo.com - http://www.LSIS.com.ar' + S_LINEA
           + S_LINEA + 'Basado en código C para Linux de Claus Fuetterer'
           + S_LINEA
           + S_LINEA + Format('CPU clock = %f MHz', [CPUClock]);
     // MessageDlg(Texto, mtInformation, [mbOK],0);
     Puts(Texto, True);
end;

procedure TfrmMain.LeerPIC1Click(Sender: TObject);
begin
     ProgramPic(PIC_READ);
end;

procedure TfrmMain.GrabarHex1Click(Sender: TObject);
begin
     with dgSave do begin
          FileName := '';
          if Execute then
             if SaveHexFile(FileName) then
                MessageDlg( Format('El archivo: %s se grabó correctamente',[FileName]), mtInformation, [mbOK], 0 )
             else
                 MessageDlg( Format('Error al grabar archivo: %s',[FileName]), mtError, [mbOK], 0 )
     end;
end;

end.
