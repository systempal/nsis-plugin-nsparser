# nsParser NSIS Plugin

Plugin NSIS nativo in C per estrarre velocemente valori da file di grandi dimensioni, bypassando i limiti di NSIS_MAX_STRLEN (1KB).

## Problema Risolto

NSIS ha un limite di **1024 byte** per le stringhe (`NSIS_MAX_STRLEN`). File HTML/JSON con linee molto lunghe (>1KB) non possono essere processati con `FileRead` o operazioni su stringhe native NSIS.

**Esempio**: Il file HTML di Remote Desktop Manager contiene una linea di 39.830 caratteri (135KB totali) che causa il troncamento di `FileRead` a 1KB, impedendo l'estrazione della versione.

**Soluzioni fallite**:
- `FileRead` → Tronca a 1KB
- Concatenazione stringhe → Limite 1023 byte totali
- `NScurl /MEMORY` → Limite ~8KB
- Lettura byte-by-byte → Troppo lenta (10-30 secondi per 135KB)

**Soluzione nsParser**: Plugin nativo in C che legge file in chunk di 8KB con buffer sliding window di 16KB, parsing in <1 secondo.

## Compilazione

### Requisiti
- Visual Studio 2022 (MSBuild 17.x, PlatformToolset v143)
- Python 3.x (per build automation)

### Build Automatica

```cmd
cd nsParser
python build_plugin.py
```

Compila tutte le configurazioni e copia i DLL finali in `../plugins/`:
- `x86-ansi` → 85-87 KB
- `x86-unicode` → 85-87 KB
- `x64-ansi` → 104 KB
- `amd64-unicode` → 104 KB

File intermedi (`.lib`, `.exp`, `.obj`) rimangono in `nsParser/Plugins/{platform}/` per debugging.

### Opzioni build

```powershell
python build_plugin.py --config x86-unicode      # Solo un'architettura (x86-ansi|x86-unicode|amd64-unicode|all)
python build_plugin.py --toolset 2026            # Toolset specifico (2022|2026|auto)
python build_plugin.py --jobs 4                  # Numero di job MSBuild paralleli (default: CPU count)
python build_plugin.py --clean                   # Pulizia dist/ prima della build
python build_plugin.py --install-dir "C:\NSIS\Plugins"  # Copia in directory NSIS aggiuntiva
python build_plugin.py --verbose                 # Output MSBuild esteso
python build_plugin.py --version                 # Stampa versione ed esce
```

### Build Manuale

```cmd
cd nsParser
build.cmd
```

O con MSBuild direttamente:
```cmd
msbuild nsParser.vcxproj /p:Configuration="Release" /p:Platform="Win32"
msbuild nsParser.vcxproj /p:Configuration="Release Unicode" /p:Platform="Win32"
msbuild nsParser.vcxproj /p:Configuration="Release" /p:Platform="x64"
msbuild nsParser.vcxproj /p:Configuration="Release Unicode" /p:Platform="x64"
```

## Utilizzo in NSIS

```nsis
!addplugindir "plugins\x86-unicode"

Section
  ; Download HTML file
  NScurl::http GET "https://devolutions.net/..." "$PLUGINSDIR\rdm.html" /END
  Pop $0
  
  ; Extract version from HTML
  nsParser::Extract "$PLUGINSDIR\rdm.html" "RDM7zX64.Version"
  Pop $0  ; Status: "OK" or "ERROR"
  Pop $1  ; Version string (es: "2025.3.21.0")
  
  ${If} $0 == "OK"
    DetailPrint "Version found: $1"
  ${Else}
    DetailPrint "Version not found"
  ${EndIf}
SectionEnd
```

### Esempio Reale: RDM_Functions.nsh

```nsis
!macro _GetLatestVersion
  NScurl::http GET "https://devolutions.net/..." "$R8" /END
  Pop $0
  
  ${If} $0 == "OK"
    nsParser::Extract "$R8" "RDM7zX64.Version"
    Pop $0  ; Status
    Pop $1  ; Version: "2025.3.21.0"
    
    ${If} $0 == "OK"
      StrCpy $Latest_Version "$1"
      StrCpy $DOWNLOAD_LINK "https://cdn.devolutions.net/download/Devolutions.RemoteDesktopManager.win-x64.$Latest_Version.7z"
    ${EndIf}
  ${EndIf}
!macroend
```

## API

### nsParser::Extract

```nsis
nsParser::Extract <filepath> <pattern>
```

**Parametri**:
- `<filepath>`: Percorso assoluto del file da analizzare
- `<pattern>`: Pattern da cercare (es: "RDM7zX64.Version")

**Stack Output**:
1. Status: `"OK"` o `"ERROR"`
2. Value: Stringa estratta (o vuota se errore)

**Logica di estrazione**:
1. Cerca `<pattern>` nel file
2. Trova il primo `:` dopo il pattern
3. Trova il primo `"` dopo i due punti
4. Estrae tutto fino al `"` di chiusura
5. Restituisce il valore trovato

**Esempio**: Nel file con contenuto `{"RDM7zX64.Version":"2025.3.21.0"}`, il pattern `"RDM7zX64.Version"` estrae `"2025.3.21.0"`.

## Vantaggi

- **Veloce**: ~1000x più veloce del byte-reading NSIS (<1s vs 10-30s per 135KB)
- **No Limiti**: Bypassa NSIS_MAX_STRLEN, gestisce file di qualsiasi dimensione
- **Efficiente**: Lettura in chunk di 8KB con sliding window buffer di 16KB
- **Pattern Spanning**: Buffer sliding window preserva pattern tra chunk (ultimi 2KB)
- **Multi-Arch**: 4 configurazioni (x86/x64, ANSI/Unicode)
- **Semplice**: Singola funzione `Extract` parametrica
- **Generico**: Non specifico per RDM, usabile per qualsiasi estrazione pattern

## Implementazione Tecnica

### Algoritmo

```c
1. CreateFile() → Apre file in lettura
2. Loop:
   a. ReadFile() → Legge 8KB chunk
   b. Append a search buffer (16KB max)
   c. strstr() → Cerca pattern
   d. Se trovato:
      - Trova ':' dopo pattern
      - Trova '"' dopo ':'
      - Estrae fino a '"' chiusura
      - Return value
   e. Se buffer pieno:
      - Copia ultimi 2KB all'inizio (sliding window)
      - Azzera resto buffer
      - Continue reading
3. CloseHandle()
```

### Caratteristiche

- **Buffer Size**: 16KB totale (8KB chunk + 8KB overlap)
- **Sliding Window**: Preserva ultimi 2KB per pattern spanning
- **String Search**: Native `strstr()` su dati ANSI
- **Unicode Support**: `MultiByteToWideChar()` per output Unicode
- **Windows API**: `CreateFile`, `ReadFile`, `CloseHandle`
- **No CRT**: Runtime library statica (MultiThreaded)

### Configurazioni Visual Studio

| Configuration | Platform | CharacterSet | Output Size | Plugin Dir |
|---------------|----------|--------------|-------------|------------|
| Release | Win32 | MultiByte | 85-87 KB | x86-ansi |
| Release Unicode | Win32 | Unicode | 85-87 KB | x86-unicode |
| Release | x64 | MultiByte | 104 KB | x64-ansi |
| Release Unicode | x64 | Unicode | 104 KB | amd64-unicode |

### Struttura File

```
nsParser/
├── nsParser.c              # Implementazione plugin (140 righe)
├── nsParser.h              # Header NSISFUNC macro
├── nsParser.def            # Export definitions
├── nsParser.vcxproj        # Visual Studio project (4 configs)
├── build_plugin.py         # Build automation + DLL copy
├── build.cmd               # Batch wrapper
├── .gitignore              # Ignora Plugins/*, .user, __pycache__
├── README.md               # Questa documentazione
└── Plugins/                # Build intermedi (gitignored)
    ├── x86-ansi/          # DLL + .lib + .exp + .obj
    ├── x86-unicode/
    ├── x64-ansi/
    └── amd64-unicode/

../plugins/                 # Output finale (copiato da Python)
├── x86-ansi/nsParser.dll
├── x86-unicode/nsParser.dll
├── x64-ansi/nsParser.dll
└── amd64-unicode/nsParser.dll
```

## Note Tecniche

### NSIS_MAX_STRLEN Limit

Il limite di 1KB è **assoluto** in NSIS Unicode e non può essere aumentato senza ricompilare NSIS stesso. Questo plugin è l'unica soluzione pratica per processare file con linee >1KB.

### VersionCompare Bug

**ATTENZIONE**: `${VersionCompare}` ha un bug noto con versioni a 4 parti. Esempio:

```nsis
${VersionCompare} "2024.3.18.0" "2025.3.21.0" $R0
; $R0 = "2" (SBAGLIATO! Dovrebbe essere "1")
```

**Workaround** (usato in `RDM_Installer.nsi`):

```nsis
${VersionCompare} "$Current_Version" "$Latest_Version" $R0

${If} $R0 == "2"
  ; Estrai anno e confronta numericamente
  ${WordFind} "$Current_Version" "." "+1{" $R1  ; Anno corrente
  ${WordFind} "$Latest_Version" "." "+1{" $R2   ; Anno remoto
  
  ${If} $R1 < $R2
    ; Anno vecchio → forzare selezione
    !insertmacro SelectSection 0
  ${Else}
    !insertmacro UnselectSection 0
  ${EndIf}
${EndIf}
```

**Nota**: In `RDM.nsi` (launcher) il workaround non serve perché si verifica solo uguaglianza (`$R0 == "0"`), non maggiore/minore.

## Performance

### Benchmark: File HTML 135KB (linea 39.830 caratteri)

| Metodo | Tempo | Note |
|--------|-------|------|
| NSIS FileRead | ❌ Fallisce | Tronca a 1KB |
| NSIS Byte-reading | 10-30 secondi | Troppo lento |
| NScurl /MEMORY | ❌ Fallisce | Limite ~8KB |
| **nsParser plugin** | **<1 secondo** | ✅ Soluzione ottimale |

### Perché è così veloce?

1. **Native C**: Compiled code vs NSIS interpreted
2. **Bulk Reading**: 8KB chunks vs 1-byte iterations
3. **Efficient Search**: `strstr()` CPU-optimized vs NSIS string ops
4. **No String Limits**: Direct memory access vs NSIS_MAX_STRLEN

## Casi d'Uso

- ✅ Estrazione versioni da HTML/JSON con linee lunghe
- ✅ Parsing file di configurazione con valori embedded
- ✅ Lettura metadata da file generati (build info, manifests)
- ✅ Download + parsing di risorse remote in un unico passaggio
- ✅ Qualsiasi pattern `"key":"value"` o `key: "value"`

## Licenza

Sviluppato per uso interno nel workspace Launchers.

## Changelog

### v1.0 (2025-11-10)
- ✅ Rinominato da RDMVersion a nsParser (generico)
- ✅ Supporto multi-architettura (4 configurazioni)
- ✅ Build automation con Python
- ✅ Struttura directory pulita (Plugins/ + ../plugins/)
- ✅ Fixed amd64-unicode configuration bug
- ✅ Integrato in RDM_Installer.nsi e RDM_Functions.nsh
- ✅ Performance validated: <1s per 135KB file

### v0.1 (Initial)
- Plugin iniziale RDMVersion specifico per Remote Desktop Manager
