# Provkörning på Android/Termux

Mål: verifiera den aktuella utvecklingskopian på en verklig enhet. Detta är
inte en ny certifierad stabil release. Kör alla kommandon nedan i Termux,
utanför Ubuntu, om inget annat anges. Använd en testenhet eller en Termux-miljö
där ändringar i installerade paket och befintligt Ubuntu är acceptabla.
Installationen uppgraderar Termux-paket och installerar även säkerhets- och
utvecklingsverktyg i Ubuntu. Toolkit-backup täcker inte hela den miljön.

## 1. Appar och förberedelser

- Android 8 eller senare krävs för Termux:X11. Första målarkitekturen är arm64/aarch64.
- Installera/behåll Termux från [officiella installationsanvisningar](https://github.com/termux/termux-app#installation).
  Byt inte appkälla genom att avinstallera en fungerande miljö för detta test.
- Installera den vanliga `termux-x11-universal-debug.apk` från
  [Termux:X11 nightly](https://github.com/termux/termux-x11/releases/tag/nightly).
  Det är den vanliga APK:n, inte sharedUid-varianten.
- Följ [Termux:X11:s officiella anvisningar](https://github.com/termux/termux-x11#setup-instructions).
  Både appen och paketet i nästa block behövs.
- Ha internet, laddning och flera GB ledigt. Exakt utrymmeskrav är ännu inte uppmätt.
  Tillåt Termux att köras i bakgrunden under provet.

I Termux:

```bash
pkg update
pkg upgrade
pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xdpyinfo proot-distro python git curl tar coreutils findutils util-linux pulseaudio
termux-setup-storage
```

Godkänn Androids fråga om filåtkomst. Öppna Termux:X11-appen en gång och gå
sedan tillbaka till Termux. Om något paket inte hittas: spara feltexten och
stanna där; byt inte till slumpmässiga paketkällor.

## 2. För över den uppdaterade koden

Använd **det nya provpaketet**, inte den ursprungliga nedladdningen. På datorn
byggs det med `python tools/package-termux.py`. Kopiera följande två filer från
`dist/` till telefonens mapp Download via USB eller valfri egen filöverföring:

- `NetHunter-Toolkit-Termux-Test.tar.gz`
- `NetHunter-Toolkit-Termux-Test.tar.gz.sha256`

Kontrollera och packa upp i Termux:

```bash
cd "$HOME/storage/downloads"
sha256sum -c NetHunter-Toolkit-Termux-Test.tar.gz.sha256
```

Fortsätt bara om det står **OK**. Kontrollera först att målmappen är ledig:

```bash
test ! -e "$HOME/nht-termux-test" && echo "Målmappen är ledig"
```

Om inget skrivs ut finns mappen redan: välj en ny testmapp eller flytta den
gamla med Androids filhanterare/Termux efter att du sparat det du behöver.
Packa inte över en tidigare provinstallation.

```bash
tar -xzf "$HOME/storage/downloads/NetHunter-Toolkit-Termux-Test.tar.gz" -C "$HOME"
cd "$HOME/nht-termux-test"
sha256sum -c termux-package.manifest
find . -type f -name '*.sh' -exec chmod +x {} +
chmod +x nht
```

Alla manifestposter ska vara **OK**. Kör från Termux HOME, inte direkt från
Androids delade Download-lagring som inte har vanliga Linux-rättigheter.
`termux-package.manifest` verifierar just provpaketet. Det gamla
`release.manifest` behålls som historik och ska inte användas för att godkänna
utvecklingskopian.

## 3. Kontroll före installation

```bash
bash tools/termux-qualify.sh preflight
echo "Kontrollkod: $?"
```

Förväntat: `FAIL=0`. Kod 0 = kontroller godkända, 1 = varningar, 2 = minst ett
fel eller fel miljö. För andra arkitekturer än aarch64 rapporteras en varning.
Ledigt diskutrymme visas för manuell bedömning, det godkänns inte automatiskt
mot ett fast minimiantal GB. Android-appens installation bekräftar du manuellt.

## 4. Kör installationen och spara resultatet

```bash
mkdir -p logs/qualification
set -o pipefail
bash install.sh 2>&1 | tee logs/qualification/install.log
install_rc=${PIPESTATUS[0]}
printf '\nINSTALL_EXIT=%s\n' "$install_rc" | tee -a logs/qualification/install.log
```

Förväntat: `INSTALL_EXIT=0` och installationens slutstatus utan fel.
Vid annan kod: **stanna och skicka loggen**, kör inte repair eller installera om
Ubuntu på chans. Installationens fulla paketlista ingår i testet och eventuella
paketfel ska utredas. Kör inte `install.sh --preflight` eller `--qualify`; de
flaggorna är fortfarande planerade. Kontrollskriptet finns under `tools/`.

## 5. Verifiera Ubuntu och installerade skrivbordspaket

```bash
bash tools/termux-qualify.sh installed
echo "Kontrollkod: $?"
```

Förväntat: Ubuntu-inloggning fungerar och samtliga listade program hittas,
inklusive `startxfce4`, `dbus-run-session` och `xdpyinfo`. `/etc/os-release`
visar den faktiskt installerade Ubuntu-versionen. Historiken hänvisar till
24.04 men aktuell proot-distro kan leverera en annan version; rapportera den
istället för att försöka tvinga en nedgradering. Ett befintligt Ubuntu återanvänds,
så det här är bara ett nyinstallationstest om Ubuntu saknades före starten.

Kontrollera även en interaktiv Ubuntu-inloggning:

```bash
source lib/runtime.sh
runtime_ubuntu_login ubuntu -- bash
```

Inne i Ubuntu, kör:

```bash
cat /etc/os-release
printf 'Ubuntu shell OK\n'
exit
```

Efter `exit` är du tillbaka i Termux.

## 6. Starta X11 och XFCE

I Termux, från projektmappen:

```bash
bash modules/09-toolkit-control.sh start
echo "Startkod: $?"
```

Förväntat: startkod 0. Byt till **Termux:X11-appen**. Du ska se XFCE:s
skrivbord, panel och fönsterhanterare. Projektets startkommando hanterar X11,
PulseAudio och XFCE. Starta inte en extra separat `termux-x11 :0`-session.
Projektet använder som standard display `127.0.0.1:1` med TCP.

Kontrollera manuellt och anteckna resultat:

- Skrivbord och panel syns.
- Ett program kan öppnas via panel/meny och ett fönster kan flyttas/stängas.
- Textinmatning och pekare/tryck fungerar.
- Växling till Termux och tillbaka lämnar skrivbordet fungerande.

Gå tillbaka till Termux och kör:

```bash
bash tools/termux-qualify.sh gui
echo "Kontrollkod: $?"
bash doctor.sh 2>&1 | tee logs/qualification/doctor.log
doctor_rc=${PIPESTATUS[0]}
printf '\nDOCTOR_EXIT=%s\n' "$doctor_rc" | tee -a logs/qualification/doctor.log
```

GUI-kontrollen kräver kontakt med X11 från både Termux och Ubuntu samt alla
fyra XFCE-processerna, D-Bus och ljudanslutningen. Varje Ubuntu-kontroll får
högst 90 sekunder. `FAIL=0` plus manuellt godkänt skrivbord är målet.
Ljudanslutning är ett anslutningstest; det bevisar inte hörbart ljud.
Doctor ger idag kod 1 vid både varningar och fel: bedöm också **Fel** och
**Varningar** i sammanfattningen. Doctor kan skapa PulseAudio-klientkonfiguration.
Enbart doctor-kod 1 bevisar därför inte att GUI-installationen misslyckats.

## 7. Stoppa och starta om

Detta avslutar öppna XFCE-program. Spara allt arbete först.

```bash
bash modules/09-toolkit-control.sh stop
echo "Stoppkod: $?"
bash modules/09-toolkit-control.sh start
echo "Startkod: $?"
bash tools/termux-qualify.sh gui
```

Förväntat: stopp- och startkod 0, skrivbordet återkommer och den nya
GUI-rapporten har `FAIL=0`. Stop-kommandot stoppar XFCE, inte nödvändigtvis
själva X11-servern eller PulseAudio.

## 8. Om det blir fel och vad du skickar tillbaka

Vid svart bild: lämna processerna kvar och spara rapporterna. Prova inte flera
olika displaynummer samtidigt. Dessa loggar motsvarar projektets faktiska start:

```bash
mkdir -p logs/qualification
if [ -f "$PREFIX/tmp/nethunter-toolkit/x11.log" ]; then
    cp "$PREFIX/tmp/nethunter-toolkit/x11.log" logs/qualification/x11.log
fi
if [ -f "$PREFIX/tmp/nht-xfce-control.log" ]; then
    cp "$PREFIX/tmp/nht-xfce-control.log" logs/qualification/xfce-control.log
fi
tar -czf "$HOME/storage/downloads/nht-termux-results.tar.gz" logs/qualification
```

Läs igenom loggarna innan du delar dem; installationsutskrifter kan innehålla
enhetsspecifika sökvägar. Rapportskriptet samlar inte serienummer, konton eller
nätverksinventering. Skicka resultatarkivet samt:

```text
Telefonmodell:
Android-version:
Termux-källa/version:
Termux:X11-version:
Fanns Ubuntu före testet? ja/nej:
Preflight: kod / FAIL / WARN:
Installation: INSTALL_EXIT:
Installed: kod / FAIL:
GUI: kod / FAIL:
Skrivbord, fönster, tangentbord, pekare: OK/fel:
Stoppa/starta igen: OK/fel:
Första steget som misslyckades och synlig feltext:
```

Provningen är godkänd först när installationen och alla tre kontrollstegen
passerar (varningar bedöms separat), de manuella GUI-proven fungerar och
stopp/start fungerar. Verktyget utför ingen automatisk reparation, paketinstallation
eller GUI-start; förutom att skriva rapporter kontrollerar det befintligt tillstånd.
