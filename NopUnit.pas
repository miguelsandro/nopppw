{--------------------------------------------------------------------------
   Unit:         NopUnit
   Programador:  Miguel Sandro Lucero
                 miguel_sandro@yahoo.com - http://www.LSIS.com.ar
   Fecha:        agosto 2002
   Descripción:  Funciones y procedimientos para el manejo
                 del programador para PIC's NOPPP
---------------------------------------------------------------------------}

unit NopUnit;

interface

uses
    Windows, Messages, SysUtils, Classes, Forms, Dialogs;

const

     S_LINEA = #13#10;

     LPT1_BASE = $378;             // LPT1
     LPT2_BASE = $278;             // LPT2

     lp_data   = LPT1_BASE;        // Bytes de DATA. Escribir aquí para cambiar D0-D7
     lp_status = LPT1_BASE+1;      // Bytes de STATUS. Leer desde aquí para recuperar estados
     lp_ctl    = LPT1_BASE + 2;    // Bytes de CONTROL. Escribir para cambiar las líneas de control

     PIC16C84  = 1;                // Modelos de PIC soportados
     PIC16F84  = 2;
     PIC16F83  = 3;
     PIC16F874 = 4;
     PIC16F877 = 5;
     PIC16C74  = 6;
     PIC16F628 = 7;

     PIC_PROGRAM   = 1;            // Programar PIC
     PIC_VERIFY    = 0;            // Verificar PIC
     PIC_READ      = 2;            // Leer pic

     PBASE = $0000;                // Dirección base para cada memoria
     IBASE = $2000;
     CBASE = $2007;
     DBASE = $2100;

     PSIZEMAX = 8192;              // Max tamaño para cada memoria
     ISIZEMAX = 4;
     CSIZEMAX = 1;
     DSIZEMAX = 256;

     PMASK    =  $3FFF;            // Que bits son usados en cada word
     DMASK    =  $00FF;

var
   DEVICE: Integer  = 0;            // Que PIC estamos programando
   Verbose: Integer = 1;            // 1 == display información

   BITS: byte = $0F;

   PSIZE: word      = PSIZEMAX;     // Tamaño actual, puede ser seteado menor
   ISIZE: word      = ISIZEMAX;     // para un PIC en particular
   CSIZE: word      = CSIZEMAX;
   DSIZE: word      = DSIZEMAX;

   PMEM: array [0..PSIZEMAX] of word;   // Arrays representando las diferentes memorias
   IMEM: array [0..ISIZEMAX] of word;
   CMEM: array [0..CSIZEMAX] of word;
   DMEM: array [0..DSIZEMAX] of word;

   PUSED: word      = 0;                // Número de words válidos en el array
   CUSED: word      = 0;
   IUSED: word      = 0;
   DUSED: word      = 0;

   CMASK: word          = $001F;        // CMASK depende del procesador
   IMASK: word          = $3fff;        // IMASK depende del procesador

   DEFAULTCONFIG: word  = $1B;          // Inicialización de word de configuración

   LOADCONFIG: byte        = 0;         // Comandos de programación de PIC
   LOADPROGRAM: byte       = 2;
   READPROGRAM: byte       = 4;
   INCREMENTADDRESS: byte  = 6;
   BEGINPROGRAMMING: byte  = 8;
   LOADDATA: byte          = 3;
   READDATA: byte          = 5;
   ERASEPROGRAM: byte      = 9;
   ERASEDATA: byte         = 11;

   CPUClock: Extended      = 0;    // Número de ciclos del clock de la CPU en 1 microsegundo

   Sum: Integer;

   FileRead: TStringList;          // Leer programa desde el pic

// Funciones y procedimientos globales
procedure TroubleShoot;
procedure AllPinSlow;
procedure HardwareDetect;
procedure ClearArrays;
procedure SelectDevice(choice: Integer);
procedure ProgramPic(mode: integer);
procedure ErasePic;
procedure GetModelPIC;
procedure LoadHexFile(FileName: string);
function SaveHexFile(FileName: String): boolean;

function CalibrateCPU: int64;
function GetCPUTick: Int64;
function TicksToStr(const Value: int64): string;
procedure Delay(MicroS: DWORD); // retardo en microsegundos
procedure DelayM(MiliS: DWORD); // retardo en milisegundos
procedure Puts(Texto: String; Limpiar: Boolean = False; AddLine: Boolean = True);

procedure Out_Byte(Port:Integer; Data: Byte); stdcall external 'IO.DLL' name 'PortOut';
function In_Byte(Port: Integer): Byte; stdcall external 'IO.DLL' name 'PortIn';

implementation

uses Main;

function IIF(Condicion: Boolean; ValorV, ValorF: Variant): Variant;
begin
     if Condicion=True then
        Result := ValorV
     else
         Result := ValorF;
end;

function GetCPUTick: Int64;
asm
   DB $0F,$31
end;

// Calcular número de ciclos del clock de la CPU en 1 microsegundo (1 µs)
function CalibrateCPU: Int64;
var
   t: cardinal;
begin
     t := GetTickCount;
     while t=GetTickCount do;
     Result := GetCPUTick;
     while GetTickCount<(t+4000) do;
     Result := GetCPUTick - Result;
     CPUClock := 2.5e-7 *Result;
end;

function TicksToStr(const Value: int64): string;
begin
     Result := FloatToStrF(Value/CPUClock,ffFixed,10,2)+ ' µs';
end;

// Retardo en microsegundos
procedure Delay(MicroS: DWORD);
var
   ticks: Int64;
begin
     ticks := GetCPUTick;
     repeat
           // Application.ProcessMessages;
     until (GetCPUTick - ticks)/CPUClock>=MicroS;
end;

// Delay en Milisegundos
procedure DelayM(MiliS: DWORD);
var
   FirstTickCount: DWORD;
begin
     FirstTickCount := GetTickCount;
     repeat
           Application.ProcessMessages;
     until ((GetTickCount-FirstTickCount) >= MiliS);
end;

// Mostrar información en cuadro de status
procedure Puts(Texto: String; Limpiar: Boolean = False; AddLine: Boolean = True);
begin
     if Verbose=1 then begin
        frmMain.sb1.Panels[0].Text := Texto;
        frmMain.sb1.Refresh;
        //
        if Limpiar then frmMain.edInfo.Lines.Clear;
        if AddLine then
           frmMain.edInfo.Lines.Add( Texto )
        else
            frmMain.edInfo.Lines[frmMain.edInfo.Lines.Count-1] := Texto;

     end;
end;

{
// Procedimientos y funciones para el manejo del puertos
// en Windows 95/98 (No NT/2000/XP)

// Enviar un byte por puerto
procedure out_byte(Direccion: Word; Valor: Byte);
begin
     asm
        mov dx,Direccion // Dirección del puerto
        mov AL,Valor     // Valor
        out DX,AL        // Enviar
     end;
end;

// Leer un byte del puerto
function in_byte(Direccion: Word):Byte;
begin
     asm
        mov dx,Direccion // Dirección del puerto
        in AL,dx         // Leer
        mov Result,AL    //
     end;
end;
}

// *********************************************************************
// INTERFACE DE HARDWARE PARA PUERTO PARALELO
// *********************************************************************

// Protocolo serie sincrono de dos líneas (Two-wire) por puerto de impresora.
// Pin  1, STROBE, CLOCK serial;
// Pin 14, AUTOFD, Salida de DATA serial al PIC;
// Pin 11, BUSY,   Entrada de DATA serial desde PIC;
// Pin 17, SLCTIN, Bajo (0) cuando escribe, alto (1) para proveer polarización (pull-up) cuando se lee;
// Pin  2, D0,     Bajo (0) para aplicar Vpp (Tensión de programación).

// SLCTIN y BUSY son enlazados juntos para polarización (pull-up) y para la detección de hardware.
// (En la versión actual esto se hace con diodos o puertas lógicas.)

// SLCTIN es un colector abierto (open-collector) de salida con polarización (pull-up).
// Si está con polaridad baja, algunos puertos de impresora lo dejan bajo.
// Por ende, esto y todos los otros bits de control son asegurados
// cada vez que son necesitados.

// procedimientos para SET y CLEAR las líneas de datos (DATA)

// SLCTIN, AUTOFD bajo
procedure DataWritable;
begin
     BITS :=  BITS or $0A;
     out_byte(lp_ctl,BITS);
end;

// SLCTIN, AUTOFD alto
procedure DataReadable;
begin
     BITS := BITS and not $0A;
     out_byte(lp_ctl,BITS);
end;

// AUTOFD bajo
procedure DataDown;
begin
     BITS := BITS or $02;
     out_byte(lp_ctl, BITS);
end;

// AUTOFD alto
procedure DataUp;
begin
     BITS := BITS and not $02;
     out_byte(lp_ctl, BITS);
end;

// STROBE bajo
procedure ClockDown;
begin
     BITS := BITS or $01;
     out_byte(lp_ctl, BITS);
end;

// STROBE alto
procedure ClockUp;
begin
     BITS := BITS and not $01;
     out_byte(lp_ctl, BITS);
end;

// Vpp ON
procedure VppOn;
begin
     BITS := BITS and not 04;
     out_byte(lp_ctl, BITS);
     out_byte(lp_data, 0);
end;

// Vpp OFF
procedure VppOff;
begin
     BITS := BITS or $04;
     out_byte(lp_ctl, BITS);
     out_byte(lp_data,   1);
end;

// Data IN
function DataIn: Byte;
begin
     Result := ((not in_byte(lp_status)) and $80) shr 7;
end;

// All Pin Slow
procedure AllPinSlow;
begin
     VppOff;
     DataWritable;
     DataDown;
     ClockDown;
     BITS := $0F;
     out_byte(lp_data, BITS);
end;

// True si BUSY y SLCTIN son tied juntos
function DetectHardware: Boolean;
begin
     Result := False;
     DataWritable;
     DataUp;
     Delay(10);
     if DataIn = 1 then Exit;
     DataReadable;
     DataUp;
     Delay(10);
     if DataIn = 0 then Exit;
     Result := True;
end;

// *********************************************************************
// RUTINAS DE COMUNICACION CON PIC
// *********************************************************************

// Enviar 1 bit al PIC
procedure SendBit(b: byte);
begin
     if b>0 then
        DataUp
     else
         DataDown;
     ClockUp;
     Delay(1);             // tset1
     ClockDown;            // data es clocked dentro del PIC en este lado
     Delay(1);             // thld1
     DataDown;             // idle con data line bajo
end;

// Recibir un bit desde el PIC
function RecvBit: byte;
var
   b: byte;
begin
     ClockUp;
     Delay(1);             // tdly3
     ClockDown;            // data está listo justo antes de esto
     b := DataIn;          // leer data
     Delay(1);             // thld1
     Result := b;
end;

// Enviar comando de 6-bit desde abajo de b
procedure SendCmd(b: byte);
var
   i: integer;
begin
     DataWritable;
     Delay(2);                   // thld0
     for i:=6 downto 1 do begin
         SendBit( b and 1);
         b := b shr 1;
     end;
     Delay(2);                   // tdly2
end;

// Enviar palabra de 14-bit desde abajo de w
procedure SendData(w: word);
var
   i: integer;
begin
     DataWritable;
     Delay(2);                   // thld0
     SendBit(0);                 // un bit basura
     for i:=14 downto 1 do begin
         SendBit( w and 1 );     // 14 data bits
         w := w shr 1;
     end;
     SendBit(0);                 // un bit basura
     Delay(2);                   // tdly2
end;

// Recibir palabra de 14-bit, lsb primero
function RecvData: word;
var
   i: integer;
   b: byte;
   w: word;
begin
     w := 0;
     DataReadable();             // SLCTIN alto para pull-up
     Delay(2);                   // thld0
     RecvBit;                    // un bit basura
     for i:=0 to 14-1 do begin
         b := RecvBit;
         w := w or (b shl i);    // 14 data bits
     end;
     RecvBit;                    // otro bit basura
     Delay(2);                   // tdly2
     Result := w;
end;

// *********************************************************************
// ALGORITMOS DE PROGRAMACION DE PIC
// *********************************************************************

// Marcar los array de memoria vacios
procedure ClearArrays;
begin
     PUSED := 0;
     IUSED := 0;
     CUSED := 0;
     DUSED := 0;
end;

// Colocar data en el arrar de memoria correspondiente.
// Retorna verdadero si tuvo éxito.
function StuffArray( address: word;
                     var array1: array of word;
                     base: word;
                     size: word;
                     var used: word;
                     data: array of word;
                     count: integer): boolean;
var
   i: integer;
begin
     Result := False;
     if (address-base+count-1 > size) then begin
         // MessageDlg( Format('Invalid address: %.4XH', [address+count-1]), mtError, [mbOK], 0 );
         Puts( Format('Invalid address: %.4XH', [address+count-1]) );
         Exit;
     end;
     for i:=0 to count-1 do begin
         array1[i+address-base] := data[i];
         if (used < address-base+count) then used := address-base+count;
     end;
     Result := True;
end;

// *********************************************************************
// PROCEDIMIENTOS DE PROGRAMACION
// *********************************************************************

// Reset PIC, aplicar Vpp
procedure VppReset;
begin
     VppOff;
     DataWritable;
     DataDown;
     ClockDown;
     DelayM(25);
     VppOn();
     DelayM(25);
end;

// Enviar un commando y un argumento,y programar EPROM.
procedure ProgCycle(cmd: byte; arg: word);
begin
     SendCmd(cmd);
     SendData(arg);
     SendCmd(BEGINPROGRAMMING);
     DelayM(20);
end;

// Programar una memoria desde el array correspondiente
// Retorna verdadero si tuvo éxito.
{$WARNINGS OFF}
function ProgramAll( mode: integer;             // programar, verificar o leer
                     mask: word;                // para descartar bits irrelevantes
                     writecommand: byte;        // commando para escribir esta memoria
                     readcommand: byte;         // commando para leer esta memoria
                     var array1: array of word; // que array de memoria se usa
                     base: word;                // dirección base
                     used: word):word;          // número de palabras validas en el array
var
   w: word;
   i: integer;
begin
     Result := 0;
     case mode of
          PIC_PROGRAM:  Puts('programando...', True);
          PIC_VERIFY:   Puts('verificando...', True);
          PIC_READ:     Puts('leyendo...', True);
     end;
     for i:=0 to used-1 do begin
         if mode <> PIC_READ then
            if mode = PIC_PROGRAM then
               ProgCycle(writecommand,(array1[i] and mask));
         SendCmd(readcommand);
         w := RecvData and mask;
         Puts( Format('Dirección %.4X: Data %.4X ', [i+base, w]) );
         if mode = PIC_READ then
            array1[i] := w
         else begin
              if w <> array1[i] and mask then begin
                 // MessageDlg( Format('Error en %.4X: Esperaba %.4X, Leido %04X.', [i+base, (array1[i] and mask), w]), mtError, [mbOK], 0 );
                 Puts( Format('Error en %.4X: Esperaba %.4X, Leido %04X.', [i+base, (array1[i] and mask), w]) );
                 Exit;
              end;
         end;
         SendCmd(INCREMENTADDRESS);
     end;
     Result := i;
end;
{$WARNINGS ON}

// *********************************************************************
// FUNCIONES Y PROCEDIMIENTOS DE LECTURA DE ARCHIVO HEX
// *********************************************************************

// Para archivo hex con formato Intel INHX8M (8-bit combinados) solamente.
// Este tipo de archivo usa dos bytes para cada palabra, bajo y alto.
// Todas las direcciones están duplicadas. ej. $2001 está codificada como $4002.
// Cada registro de datos comienza con un prefijo de 9 caracteres
// y termina con 2 caracteres de checksum.

// Funciones auxiliares
function HexToInt(Valor:String): integer;
begin
     Result := StrToInt('$'+Valor);
end;

// Controlar sintáxis y byte de checksum.
// Para todos los formatos de HEX, no solamente 8M.
function ValidHexLine(s: string): boolean;
var
   cksum: byte;
   bytecount, i, b: integer;
begin
     Result := False;
     if s[1] <> ':' then Exit;                 // Indicador de inicio de registro
     bytecount := HexToInt( Copy(S,2,2) );
     if bytecount > 32 then Exit;              // Byte de conteo válido
     cksum := bytecount;
     i := 3;
     bytecount := bytecount+3;
     while bytecount>0 do begin
           Dec(bytecount);
           b := HexToInt( Copy(S,i+1,2) );
           cksum := cksum+b;                   // Calcular checksum
           i := i+2;
     end;

     b := HexToInt( Copy(S,i+1,2) );
     cksum := -cksum;
     if cksum <> b then Exit;                  // Verificar checksum
     Result := True;
end;

// Leer archivo hex y guardar en array de memoria.
procedure LoadHexFile(FileName: string);
var
   Lineas: TStringList;
   s, d, Texto: String;
   i,lo,hi: word;
   linetype: word;                // 0 para data, 1 para final de archivo
   wordcount: word;               // número de palabras de 16 bit en esta línea
   address: word;                 // dirección de comienzo
   data: array [0..8] of word;    // 16 bytes = 8 palabras máximo por línea de hex
   xi: integer;

label bailout, finished;

begin
     Lineas := TStringList.Create; // Leer archivo hex
     Lineas.LoadFromFile(FileName);

     linetype := 0;   // data

     ClearArrays;

     for xi:=0 to Lineas.Count-1 do begin
         if linetype <> 1 then begin
            s := Lineas[xi];                       // obtener línea
            if not ValidHexLine(s) then begin      // controlar sintáxis
               if s[1]<>':' then
                  MessageDlg( Format('Línea inválida (salteada): %s', [s]), mtError, [mbOK], 0 )
               else
                   MessageDlg( Format('Imposible decodificar línea:  %s',[s]), mtError, [mbOK], 0 );
               goto bailout;
               break;
            end;
            wordcount := HexToInt( Copy(s,2,2) );  // Parsear la línea - Intel Hex8M
            wordcount := Trunc(wordcount/2);       // (doble bytes, dirección duplicada)
            address := HexToInt( Copy(s,4,4) );
            address := Trunc(address/2);

            linetype := HexToInt( Copy(s,8,2) );
            if linetype=1 then begin
               goto finished;
               break;
            end;
            for i:=0 to wordcount-1 do begin           // Guardar los datos
                d := Copy(s,10+4*i,4);
                lo := HexToInt( Copy(d,1,2) );
                hi := HexToInt( Copy(d,3,2) );
                data[i] := (hi shl 8) or lo;
            end;
            if address >= DBASE then begin
               if not StuffArray(address,DMEM,DBASE,DSIZE,DUSED,data,wordcount) then
                  goto bailout;
            end else if address >= CBASE then begin
                if not StuffArray(address,CMEM,CBASE,CSIZE,CUSED,data,wordcount) then
                   goto bailout;
            end else if address >= IBASE then begin
                if not StuffArray(address,IMEM,IBASE,ISIZE,IUSED,data,wordcount) then
                   goto bailout;
            end else begin
                if not StuffArray(address,PMEM,PBASE,PSIZE,PUSED,data,wordcount) then
                   goto bailout;
            end
         end
     end;

finished:

  // Mostrar información
  frmMain.lbProgramMemory.Caption := Format('%d', [PUSED]);
  frmMain.lbConfig.Caption := Format('%d', [CUSED]);
  frmMain.lbIDMemory.Caption := Format('%d', [IUSED]);
  frmMain.lbDataMemory.Caption := Format('%d', [DUSED]);;
  frmMain.lbFileName.Caption := FileName;

  Texto := '';
  if CUSED=0 then begin
     Texto := 'Precaución: El archivo HEX no contiene valores de configuración.'
           + S_LINEA + 'El siguiente seteo será usado:'
           + S_LINEA + '  RC oscillator'
           + S_LINEA + '  Watchdog timer disabled'
           + S_LINEA + '  Power-up timer enabled'
           + S_LINEA + '  Code not read-protected'
           + S_LINEA + 'Ud. puede especificar otros valores de seteo en el código assembler.';
  end else if CMEM[0] <> (CMEM[0] and CMASK) then begin
      Texto := 'Precaución: Los valores de configuración contienen bits inválidos.'
            + S_LINEA + 'El programa puede estar ensamblado para otro tipo de PIC'
            + S_LINEA + 'Revise la selección del PIC cuidadosamente.';
  end;
  if Texto<>'' then MessageDlg(Texto, mtInformation, [mbOK],0);

  Exit;

bailout:
  ClearArrays;
  MessageDlg( Format('Imposible leer archivo: %s', [FileName]), mtError,[mbOk], 0);

end;

// *********************************************************************
// PROCEDIMIENTO DE ESCRITURA DE ARCHIVO HEX
// *********************************************************************

// Escribir un archivo HEX con formato Intel INHX8M (8-bit combinados)
// desde los datos en memoria del PIC.

// Se asume que la región de memoria con todos los bits de mascara
// encendidos está desprogramada, así que no grabamos en el archivo HEX.
// Deberá borrar el PIC antes para duplicar exactamente
// el dispositivo original.

procedure NewRecord;
begin
     FileRead.Add(':');
     sum := 0;
end;

procedure WriteByte(b: integer);
begin
     Inc(sum,b);
     FileRead[FileRead.Count-1] := FileRead[FileRead.Count-1]
                                   + Format('%.2X', [b]);
end;

// Escribir palabra big-endian
procedure WriteBgWord(w: integer);
begin
     WriteByte((w shr 8) and $ff);
     WriteByte(w and $ff);
end;

// Escribir palabra little-endian
procedure WriteWord(w: integer);
begin
     WriteByte(w and $ff);
     WriteByte((w shr 8) and $ff);
end;

procedure EndRecord;
begin
     WriteByte( (-sum) and $ff);
end;

procedure SaveHexRegion( array1: array of word;	// memoria a grabar
                         base: word;		// dirección base
                         used: word;		// número de palabras válidas en array
	                 mask: word);		// bits de palabras validos
var
   i,j: word;
begin
     i := 0;
     //j := 0;
     while (i < used) do begin
           if array1[i]=mask then
              Inc(i)
           else begin
                j := i;
                while (i < used) do begin
                      Inc(i);
                      if ((i and 7)=0) or (array1[i]=mask) then
                         break;
                end;
                NewRecord;
                WriteByte(2 * ((i+base) - (j+base)));
                WriteBgWord(2 * (j+base));
                WriteByte(0);
                while (j < i) do begin
                      WriteWord(array1[j]);
                      Inc(j);
                end;
                EndRecord;
           end;
     end;
end;

// Grabar los array de memoria al archivo HEX
function SaveHexFile(FileName: String): boolean;
begin
     FileRead := TStringList.Create;
     try
        try
           SaveHexRegion(PMEM,PBASE,PUSED,PMASK);
           SaveHexRegion(IMEM,IBASE,IUSED,IMASK);
           SaveHexRegion(CMEM,CBASE,CUSED,CMASK);
           SaveHexRegion(DMEM,DBASE,DUSED,DMASK);
           NewRecord;
           WriteByte(0);
           WriteWord(0);
           WriteByte(1);
           EndRecord;
           // Grabar
           FileRead.SaveToFile( FileName );
           Result := True;
        except
              Result := False;
        end;
     finally
            FileRead.Free;
     end;
end;

// *********************************************************************
// INTERFACE DE USUARIO
// *********************************************************************

procedure HardwareDetect;
var
   Texto: String;
begin
     Texto := 'Aplique energía al programador ahora.'
           + S_LINEA + 'Si su programador tiene Vcc ajustable,'
           + S_LINEA + 'coloque este en 5.0 volts y presione OK';
     MessageDlg(Texto, mtInformation, [mbOK], 0);
     if not DetectHardware then begin
        Texto := '¡ Precaución: Hardware del programador no detectado !'
              + S_LINEA
              + S_LINEA + 'Con algunas versiones del circuito y algunos'
              + S_LINEA + 'puertos paralelos esto puede ser normal.';

     end else begin
        Texto := '¡ Hardware del programador Detectado !'
     end;
     // MessageDlg(Texto, mtInformation, [mbOK], 0);
     Puts(Texto, True);
end;

procedure TroubleShoot;
var
   Texto: String;
begin
     // TEST A
     Texto := 'Verifique que el programador está encendido ahora,'
           + S_LINEA + 'con Vcc a 5.0 V (si es ajustable)'
           + S_LINEA + 'y sin el PIC en el zócalo.';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     AllPinSlow;

     Texto := 'TEST A'
           + S_LINEA + 'Conecte el negativo del voltímetro en el pin 5'
           + S_LINEA + 'del zócalo del PIC (Socket) y verifique los siguientes voltajes:'
           + S_LINEA + '  Socket pin 4       < 0.8 V'
           + S_LINEA + '  Socket pin 12      < 0.8 V'
           + S_LINEA + '  Socket pin 13      < 0.8 V'
           + S_LINEA + '  Socket pin 14      4.75 to 5.25 V'
           + S_LINEA + '  Intersección de'
           + S_LINEA + '   D1, D2, y R1      < 0.8 V';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     VppOn;
     ClockUp;
     DataUp;

     // TEST B
     Texto := 'TEST B'
           + S_LINEA + 'Con el negativo del voltímetro aún'
           + S_LINEA + 'conectado al pin 5 del zócalo del PIC (Socket)'
           + S_LINEA + 'verifique los siguientes voltajes:'
           + S_LINEA + '  Socket pin 4       12.0 - 14.0 V'
           + S_LINEA + '  Socket pin 12      > 4.0 V'
           + S_LINEA + '  Socket pin 13      > 4.0 V'
           + S_LINEA + '  Intersección de'
           + S_LINEA + '   D1, D2, y R1    < 0.8 V';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     VppOff;
     ClockDown;
     DataReadable;  // AUTOFD, SLCTIN high

     // TEST 3 *** No implementado
     {
     Texto :=  'TEST 3'
           + S_LINEA + 'Con el negativo del voltímetro aún'
           + S_LINEA + 'conectado al pin 5 del zócalo del PIC (Socket)'
           + S_LINEA + 'verifique que el pin 13 > 4.0 V.'
           + S_LINEA + 'Luego, inserte una resistencia de 470-ohm en el socket'
           + S_LINEA + 'conectando el pin 13 con el pin 5 y verifique que'
           + S_LINEA + 'el pin 13 vaya a < 2.0 V con la resistencia en el lugar.'
           + S_LINEA + 'Entonces remueva la resistencia.'
     MessageDlg(Texto, mtInformation, [mbOK], 0);
     }

     AllPinSlow;
     DataWritable;  // SLCTIN bajo
     DataUp;        // AUTOFD alto

     // TEST C
     Texto := 'TEST C'
           + S_LINEA + 'Con el negativo del voltímetro aún'
           + S_LINEA + 'conectado al pin 5 del zócalo del PIC (Socket)'
           + S_LINEA + 'verifique que la intersección de D1, D2, y R1'
           + S_LINEA + 'es < 0.8 V.';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     AllPinSlow;
     DataReadable;  // SLCTIN alto
     DataUp;        // AUTOFD alto

     // TEST D
     Texto := 'TEST D'
           + S_LINEA + 'Con el negativo del voltímetro aún'
           + S_LINEA + 'conectado al pin 5 del zócalo del PIC (Socket)'
           + S_LINEA + 'verifique que la intersección de D1, D2, y R1'
           + S_LINEA + 'es ahora > 4 V.';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     Texto := 'Esto completa el test de secuencias de voltajes.'
           + S_LINEA + 'Ud. deberá verificar el cable de la PC al programador.'
           + S_LINEA + 'Este deberá ser relativamente corto (menos de 30 cms) y tener'
           + S_LINEA + 'todos los pines necesarios conectados.';
     MessageDlg(Texto, mtInformation, [mbOK], 0);

     AllPinSlow();
end;

procedure SelectDevice(CHOICE: Integer);
begin
     case CHOICE of
          0:
            begin
                 DEVICE := PIC16C84;
                 PSIZE  := 1024;
                 DSIZE  := 64;
                 CMASK  := $001F;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $001B;
            end;
          1:
            begin
                 DEVICE := PIC16F84;
                 PSIZE  := 1024;
                 DSIZE  := 64;
                 CMASK  := $3FFF;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $3FF3; // $3FFF;
            end;
          2:
            begin
                 DEVICE := PIC16F83;
                 PSIZE  := 512;
                 DSIZE  := 64;
                 CMASK  := $3FFF;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $3FF3;
            end;
          3:
            begin
                 DEVICE := PIC16F874;
                 PSIZE  := 4096;
                 DSIZE  := 128;
                 CMASK  := $3FFF;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $3F31;
            end;
          4:
            begin
                 DEVICE := PIC16F877;
                 PSIZE  := 8192;
                 DSIZE  := 256;
                 CMASK  := $3FFF;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $3F31;
            end;
          5:
            begin
                 DEVICE := PIC16C74;
                 PSIZE  := 4096;
                 DSIZE  := 0;
                 CMASK  := $3FFF;
                 IMASK  := $007F;
                 DEFAULTCONFIG := $3F7F;
            end;
          6:
            begin
                 DEVICE := PIC16F628;
                 PSIZE  := 2048;
                 DSIZE  := 128;
                 CMASK  := $3FFF;
                 IMASK  := $3FFF;
                 DEFAULTCONFIG := $3F30;
            end;
     else
         begin // Valores por defecto
              DEVICE := 0;
              PSIZE := PSIZEMAX;
              DSIZE := DSIZEMAX;
              CMASK := $001F;
              IMASK := $3FFF;
              DEFAULTCONFIG := $1B;
         end;
     end;
end;

procedure ErasePic;
var
   i: integer;
begin
     VppReset;
     Puts('Indicando al PIC para borrar ID, configuration, ', True);
     SendCmd(LOADCONFIG);
     SendData($3FFF);
     for i:=7 downto 1 do SendCmd(INCREMENTADDRESS);
     SendCmd(1);
     SendCmd(7);
     SendCmd(BEGINPROGRAMMING);
     DelayM(20);
     Sendcmd(1);
     Sendcmd(7);
     Puts('programa, ');
     ProgCycle(ERASEPROGRAM,$3FFF);
     Puts('datos...');
     ProgCycle(ERASEDATA,$3FFF);
     AllPinSlow();
     Puts('Listo');
end;

procedure ProgramPic(mode: integer);
var
   i: integer;
   Texto: String;
   used: word;
label finish;
begin
     Texto := '';
     if mode <> PIC_READ then
        if PUSED+IUSED+CUSED+DUSED=0 then begin
           // MessageDlg('¡ Debe leer archivo HEX primero !', mtError, [mbOK], 0);
           Puts('Error: Debe leer archivo HEX primero', True);
           goto finish;
        end;

     VppReset();

     Puts('Memoria de Programa: ', True);

     used := ProgramAll(mode,PMASK,LOADPROGRAM,READPROGRAM,PMEM,PBASE, IIF(mode=PIC_READ, PSIZE, PUSED));
     if mode=PIC_READ then PUSED := used;
     if PUSED <> used then goto finish;

     SendCmd(LOADCONFIG);      // desde aquí estamos en memoria Config/ID
     SendData(DEFAULTCONFIG);  // loadconfig requiere un argumento, este es.

     Puts('Memoria ID: ');

     used := ProgramAll(mode,IMASK,LOADPROGRAM,READPROGRAM,IMEM,IBASE,IIF(mode=PIC_READ, ISIZE, IUSED));
     if mode=PIC_READ then IUSED := used;
     if IUSED <> used then goto finish;

     for i:=0 to (CBASE-IBASE-IUSED)-1 do SendCmd(INCREMENTADDRESS); // recuperar la configuración de memoria

     Puts('Memoria de Configuración: ');

     used := ProgramAll(mode,CMASK,LOADPROGRAM,READPROGRAM,CMEM,CBASE,IIF(mode=PIC_READ, CSIZE, CUSED));
     if mode=PIC_READ then CUSED := used;
     if CUSED <> used then goto finish;

     VppReset;   // Resetear el contador de direcciones del PIC a 0

     Puts('Memoria de Datos: ');
     used := ProgramAll(mode,DMASK,LOADDATA,READDATA,DMEM,DBASE,IIF(mode=PIC_READ, DSIZE, DUSED));
     if mode=PIC_READ then DUSED := used;
     if DUSED <> used then goto finish;

     case mode of
          PIC_PROGRAM: Texto := 'Programación PIC completa.' + S_LINEA;
          PIC_VERIFY:  Texto := 'Verificación PIC completa.' + S_LINEA;
          PIC_READ:    Texto := 'Lectura PIC completa.' + S_LINEA;
     end;

     Puts('Listo');

     Texto := Texto
           + S_LINEA + 'Para trabajos de producción, deberá verificar'
           + S_LINEA + 'el PIC con los valores máximos y mínimos de Vcc.';
     Puts( Texto );
finish:
     AllPinSlow;

     // Mostrar mensaje
     // if Texto<>'' then MessageDlg(Texto, mtInformation, [mbOK], 0);
end;

// Obtiene el modelo del PIC conectado.
procedure GetModelPIC;
var
   cc: integer;
   w: word;
begin
     VppReset();
     SendCmd(LOADCONFIG);
     SendData($3FFF);
     cc := 6;
     while cc>0 do begin
           Dec(cc);
           SendCmd(INCREMENTADDRESS);
     end;
     SendCmd(READPROGRAM);
     w := RecvData;
     // MessageDlg( Format('Modelo de PIC: %.4X', [w and $3FE0]), mtInformation, [mbOK], 0 );
     Puts( Format('Modelo de PIC: %.4X', [w and $3FE0]), True );
end;

procedure LoadFile(FileName: String);
begin
end;

end.
