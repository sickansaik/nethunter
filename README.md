# NetHunter Toolkit – innehåll och färdigställande

[![Lint](https://github.com/sickansaik/nethunter/actions/workflows/lint.yml/badge.svg)](https://github.com/sickansaik/nethunter/actions/workflows/lint.yml)

Det här är en utvecklingskopia baserad på v0.5.0 Evolution. Uppgifterna om
Stable och PASS i äldre releasefiler gäller historisk kvalificering, inte
ändringarna i denna arbetskopia. Ny release är ännu inte kvalificerad.

## Snabbstart (Android/Termux)

Verktyget installeras och körs på en Android-enhet med Termux. Övergripande steg:

```bash
# 1. Installera Termux-appen (F-Droid eller GitHub, inte Google Play)
#    och Termux:X11-appen (universal-APK:n från GitHub-releasen nightly).
#    Termux-paketet termux-x11-nightly installeras av modul 01 nedan.
# 2. Hämta Toolkit till enheten, t.ex. via git eller en överförd kopia:
git clone https://github.com/sickansaik/nethunter.git
cd nethunter

# 3. Kör installationen (Termux-paket, Ubuntu via proot, X11 och XFCE):
bash install.sh

# 4. Använd dispatchern för status, diagnostik och funktioner:
./nht version
./nht status
./nht doctor
./nht features list
```

Efter installationen syns säkerhets- och nätverksverktygen (nmap, sqlmap,
hydra, gobuster, ffuf, netcat, tcpdump, whois, dig) som klickbara ikoner i
XFCE-menyn **Applications** och på skrivbordet. Starta skrivbordet med
`bash toolkit.sh` → 8 (Ubuntu GUI) → 1 (Start); välj 6 först för mobilläge.

Detaljerad provkörning på enhet beskrivs i [TERMUX-TEST.md](TERMUX-TEST.md).
Installationen hämtar paket och kräver internet samt tillräckligt
lagringsutrymme för Ubuntu och backuper. Se nedan för exakta miljökrav.

## Målmiljö

Android med Termux och Bash. Den historiska distributionen är märkt arm64;
andra arkitekturer och lägsta Android-version är ännu inte verifierade.
Ubuntu körs med proot-distro. Grafiskt skrivbord kräver Termux:X11 och XFCE.
Projektet är inte ett Windows-program. Installation hämtar paket och kräver
internet och tillräckligt lagringsutrymme för Ubuntu samt arbetskopior/backuper.

Python 3 krävs för JSON och säker kontroll av återställningsarkiv. Övriga
underhållskommandon använder bland annat GNU tar, coreutils och findutils.
Installationsmodul 01 installerar dessa beroenden. Android-appen Termux:X11
behöver finnas separat. Exakta kompatibla versioner återstår att provköra.

## Implementerat innehåll

| Ingång | Innehåll | Status |
| --- | --- | --- |
| `bash install.sh` | Termux-paket, Ubuntu, X11, XFCE, säkerhetsverktyg och meny-/skrivbordsgenvägar | Implementerat; enhetsprov återstår |
| `./nht version`, `./nht help` | Version och hjälp | Implementerat |
| `./nht status`, `./nht doctor` | Status och diagnostik | Implementerat; kräver målmiljön |
| `./nht runtime` | Visar aktuell driftstatus | Implementerat |
| `./nht features list/info/run` | Funktionsregister och körning | Implementerat |
| `./nht features run system` | Kör doctor | Implementerat |
| `./nht features run runtime` | Visar driftstatus | Implementerat; argument styr inte start/stopp |
| `./nht features run network <åtgärd>` | Nätverksdiagnostik och snapshots | Implementerat; enhetsprov återstår |
| `./nht features run security` | Informationsmeddelande om framtida moduler | Platshållare; inte en färdig säkerhetsfunktion |
| `bash toolkit.sh` | Interaktiv meny för underhåll och grafisk miljö | Implementerat; enhetsprov återstår |
| `bash backup.sh`, `bash restore.sh`, `bash update.sh` | Underhåll av Toolkit-installationen | Reviderat; se nedan |
| `bash cleanup.sh`, `bash repair.sh` | Backuprensning respektive diagnostik | Implementerat; ytterligare granskning återstår |

Nätverksåtgärder: `intelligence` (standard), `scan`, `quick`, `standard`,
`diagnostic`, `tools`, `report`, `json`, `snapshot`, `snapshots`, `latest`,
`validate <fil>`. Använd diagnostiken på nätverk där du har tillåtelse.
Direkt driftstyrning finns i `modules/09-toolkit-control.sh`:
`state`, `check`, `start`, `stop`, `restart`, `recover`, `repair`, `security`, `network`.
Installationsflaggorna `--preflight` och `--qualify` är planerade och accepteras inte.

## Backup, återställning och uppdatering

`lib/installation.sh` är den gemensamma listan över installationsfiler.
Den omfattar config, lib, modules, runtime och alla huvudskript inklusive
`feature.sh` och `doctor.sh`. Befintlig releasemetadata följer med i backup.

- Backup innehåller Toolkit och `runtime/network/**`. Den innehåller inte
  Ubuntu-filsystemet, installerade Termux-paket, Android-appar eller hela HOME.
- Återställning ersätter Toolkit-filer och nätverkshistorik med backupens
  innehåll. Arkivet granskas och packas upp i en separat arbetskopia först.
  Ofullständiga äldre backuper avvisas före ändringar.
- Återställning avvisar länkar, specialfiler och sökvägar utanför fillistan.
  Python krävs. En komplett säkerhetskopia skapas före ersättningen och finns
  också i valmenyn. Vid kopieringsfel eller kritiska verifieringsfel försöker
  skriptet återgå automatiskt till säkerhetskopian.
- Uppdatering läser endast lokala paket i `updates/<version>/`. Paketet måste
  vara nyare, innehålla hela installationen och ha ett exakt SHA-256-manifest.
  Den kopia som används kontrolleras efter mellanlagring. Nätverkshistoriken
  behålls vid uppdatering; vid återgång används säkerhetskopian.
- Backup, uppdatering och återställning delar `.installation-lock` för att
  hindra att dessa underhållsåtgärder körs samtidigt. Efter hårt avbrott:
  kontrollera att ingen åtgärd körs och inspektera backup/arbetskopia innan
  det kvarlämnade låset tas bort. Strömavbrott är inte en automatisk transaktion.
  Övriga kommandon, exempelvis snapshots och cleanup, omfattas inte av låset.
- Ett manifest upptäcker innehållsavvikelser men autentiserar inte utgivaren.
  Använd endast uppdateringar och backuper från en betrodd källa.

Återställning: 0 = klar, 1 = ogiltigt val/inga backuper, 2 = blockerad före
ersättning, 3 = misslyckad men återgång lyckades, 4 = återgång misslyckades.
Driftvarningar från repair (kod 1) tillåts; kritiska fel utlöser återgång.
Avbruten bekräftelse utan ändringar ger kod 0.

## Säkerhet och laglig användning

NetHunter Toolkit sätter upp en pentest-/labbmiljö och innehåller nätverks- och
säkerhetsverktyg. Använd det endast på enheter, system och nätverk som du äger
eller har uttryckligt skriftligt tillstånd att testa. Oauktoriserad skanning
eller intrång kan vara olagligt. Du ansvarar själv för att följa lokala lagar
och avtal. Verktyget tillhandahålls i utbildnings- och forskningssyfte, utan
garanti. `./nht features run security` är i denna version en platshållare och
levererar ingen färdig säkerhetsfunktion.

## Kontinuerlig integration (CI)

Varje push och pull request mot `main` kör arbetsflödet
[`.github/workflows/lint.yml`](.github/workflows/lint.yml):

- Bash-syntaxkontroll (`bash -n`) för alla skript inklusive `nht`.
- ShellCheck på felnivå (finjustering i `.shellcheckrc`).
- Python-kompileringskontroll (`py_compile`) för `tools/*.py`.

Detta är statiska kontroller och ersätter inte provkörning på en riktig
Android/Termux-enhet.

## Återstår före ny färdig release

1. Kör `python tools/test_installation.py`, `make check`, `make syntax`,
   `make lint` och relevanta kvalificeringstester i utvecklingsmiljön.
2. Provkör nyinstallation och samtliga användarflöden på Android/Termux.
3. Provkör backup/restore och uppdatering/återgång med nätverkshistorik,
   korrupta/ofullständiga paket samt simulerade kopierings- och verifieringsfel.
4. Granska snapshots vid samtidig körning och övriga tidigare granskningsfynd.
5. Bestäm om säkerhetsplatshållaren ska döljas eller implementeras.
6. Skapa ett rent releasepaket och ett nytt manifest efter godkända tester.
   Historisk release-anchor och Golden Baseline ska inte skrivas om.

Den här nedladdningen saknar `.git`. Git-baserade utvecklingskontroller behöver
köras från ett riktigt repository. Befintligt `release.manifest` är historiskt
och har redan avvikelser; det regenereras inte som del av dessa rättningar.

## Kör kontrollerna på Windows

Portabel Git for Windows (Bash och GNU-verktyg) och ShellCheck finns i
`.dev-tools/`. Mappen ignoreras av Git och ingår inte i installationens backup.
Ingen global installation eller ändring av systemets PATH behövs.

Kör i PowerShell från projektmappen:

```powershell
# Första gången på en ny dator: hämta och verifiera verktygen, kör sedan tester.
.\tools\test-windows.ps1 -Setup

# Efterföljande körningar fungerar utan nedladdning.
.\tools\test-windows.ps1

# Ange egen Python om den inte hittas automatiskt (Python 3.10 eller senare).
.\tools\test-windows.ps1 -Python 'C:\sökväg\python.exe'
```

Startfilen känner även igen den Python som följer med Codex på denna dator.
Setup använder versionslåsta officiella paket: Git for Windows 2.56.0.windows.3
med SHA-256 `4fc27b779829a36df77911e3f4dea09c66c790dd6c5f7dfa3b6a5479f1fe354f`
och ShellCheck 0.11.0 med SHA-256
`8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e`.
Git packas upp med 7-Zip om det finns, annars med paketets egen uppackare.
Källor: [Git for Windows](https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.3)
och [ShellCheck](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0).
Windows kan behöva tillåta körning av hämtade verktyg och PowerShell-skript.

## Kör kontrollerna i Bash/Linux/Termux

Med Bash, ShellCheck, GNU tar/coreutils/findutils och Python 3.10+ tillgängliga:

```bash
python tools/validate.py                 # alla tre kontrollgrupper
python tools/validate.py --syntax-only   # även nht kontrolleras
python tools/validate.py --lint-only
python tools/test_installation.py        # enbart arkiv- och integrationstester
```

`make verify`, `make syntax`, `make lint` och `make maintenance-test` är
motsvarande genvägar om Make finns. `make check` kräver dessutom ett riktigt
Git-repository; det är en separat utvecklingskontroll som inte passerar i en
nedladdad källkodsmapp utan `.git`. Den nya validatorn kräver inget repository.

Integrationstesterna arbetar i tillfälliga kopior. De provar backupens innehåll,
lyckad återställning, återgång vid kritiskt fel, avvisning av ofullständig
backup, underhållslås, ändrad uppdatering, lyckad uppdatering och återgång efter
misslyckad uppdatering. Installerat Ubuntu, X11 och XFCE startas inte; deras
statuskommandon ersätts med kontrollerade testkommandon i testkopiorna.

## Senaste kontrollresultat

På Windows den 25 oktober 2026:

- Bash-syntax: godkänd för 48 skript, inklusive `nht`.
- ShellCheck 0.11.0: godkänd för samma 48 skript på varningsnivå och högre.
- Arkiv- och integrationstester: 15 godkända, inga överhoppade.

Android/Termux-provning av installation, Ubuntu och grafisk miljö återstår.
Resultaten ovan kvalificerar underhållsflödena i testmiljön, inte hela produkten
för en ny stabil release. Den historiska releaseförankringen är oförändrad.

## Provkörning på Android

Följ [TERMUX-TEST.md](TERMUX-TEST.md) för överföring, installation och tre
separata kontrollsteg. Bygg provpaketet med `python tools/package-termux.py`.
Kontrollerna finns i `tools/termux-qualify.sh` och sparar rapporter under
`logs/qualification/`. De startar inte GUI och ändrar inga installerade paket.
