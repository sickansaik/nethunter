# Android: clean-install, backup/restore och rollback

26 oktober 2026. Kör i Termux, utanför Ubuntu. Använd en testmiljö där
paketuppgraderingar och installation av Ubuntu är tillåtna. Toolkit-backup
innehåller Toolkit och nätverkshistorik, inte Termux-paket, Android-appar
eller Ubuntu-filsystemet. Historiska releasefiler ska inte regenereras.

## 1. Förbered och verifiera paketet

Termux och Termux:X11-appen måste finnas enligt förberedelserna i
TERMUX-TEST.md. Kör varje block separat; fortsätt endast om kontrollerna lyckas.

```bash
pkg update && pkg upgrade && pkg install -y x11-repo
pkg install -y termux-x11-nightly xorg-xdpyinfo proot-distro python git curl tar coreutils findutils util-linux pulseaudio
termux-setup-storage
```

Godkänn filåtkomst. Kopiera båda de levererade filerna till Download:
`NetHunter-Toolkit-Termux-Test.tar.gz` och motsvarande `.sha256`.

```bash
cd "$HOME/storage/downloads" &&
sha256sum -c NetHunter-Toolkit-Termux-Test.tar.gz.sha256
```

Förväntat: OK. Packa upp till en ny katalog, aldrig över en tidigare installation:

```bash
if [ -e "$HOME/nht-termux-test" ]; then
    printf 'STOPP: nht-termux-test finns redan. Välj en annan tom testmiljö.\n'
else
    tar -xzf "$HOME/storage/downloads/NetHunter-Toolkit-Termux-Test.tar.gz" -C "$HOME"
fi
```

Fortsätt endast om katalogen nyss skapades av uppackningen:

```bash
cd "$HOME/nht-termux-test" && sha256sum -c termux-package.manifest
```

Alla poster ska ge OK. Paketets historiska `release.manifest` är inte ett
manifest för de aktuella utvecklingsfilerna. Använd `termux-package.manifest`.
Paketets körbara filer har redan körbitar i tar-arkivet.

## 2. Clean-install och driftkontroll

```bash
proot-distro list
bash tools/termux-qualify.sh preflight
printf 'PREFLIGHT_EXIT=%s\n' "$?"
```

Granska listan manuellt. Finns Ubuntu redan är detta en installation mot
befintlig miljö, inte en full clean-install. Använd en separat fräsch
Termux-miljö för ett verkligt clean-install-test; radera inte befintligt Ubuntu.
Preflight ska ha FAIL=0. Kod 1 kräver bedömning av varningarna; kod 2 stoppar testet.

```bash
mkdir -p logs/qualification
set -o pipefail
bash install.sh 2>&1 | tee logs/qualification/install.log
install_rc=${PIPESTATUS[0]}
printf 'INSTALL_EXIT=%s\n' "$install_rc"
```

Fortsätt endast vid INSTALL_EXIT=0 och slutstatus utan fel:

```bash
bash tools/termux-qualify.sh installed
printf 'INSTALLED_EXIT=%s\n' "$?"
bash modules/09-toolkit-control.sh start
printf 'START_EXIT=%s\n' "$?"
```

Start ska ge 0. Öppna Termux:X11 och kontrollera skrivbord, panel, tangentbord
och pekare. Gå tillbaka till Termux:

```bash
bash tools/termux-qualify.sh gui
printf 'GUI_EXIT=%s\n' "$?"
bash doctor.sh
printf 'DOCTOR_EXIT=%s\n' "$?"
```

Kvalificeringsrapporterna ska ha FAIL=0. Doctor kan ge 1 för både varningar
och fel: läs sammanfattningen. Detaljer och logginsamling finns i TERMUX-TEST.md.

## 3. Backup och verklig återställning i testinstallationen

Spara öppet arbete. Stoppa XFCE före underhåll:

```bash
cd "$HOME/nht-termux-test"
bash modules/09-toolkit-control.sh stop
bash backup.sh
printf 'BACKUP_EXIT=%s\n' "$?"
```

Förväntat: 0. Anteckna exakt backupfilnamn från utskriften och kopiera gärna
arkivet till en separat lagringsplats. Tillräckligt diskutrymme krävs även
för en tillfällig uppackad kopia under verifieringen.

För att bevisa att restore faktiskt ersätter filer, ändra bara en kommentar
efter lyckad backup i denna nya testinstallation:

```bash
sha256sum feature.sh > "$HOME/nht-feature-before.sha256"
printf '\n# Android restore test marker\n' >> feature.sh
bash restore.sh
restore_rc=$?
printf 'RESTORE_EXIT=%s\n' "$restore_rc"
```

Välj numret som motsvarar den nyss antecknade backupen och svara `y`.
Välj efter filnamn, inte efter antagandet att nummer 1 alltid är rätt.

Förväntat: 0, eller 3 om kritisk verifiering misslyckades och säkerhetskopian
återställdes. Kod 3 är en lyckad återgång men ett misslyckat restore-test.
Vid 0 ska ursprungsfilen vara tillbaka:

```bash
sha256sum -c "$HOME/nht-feature-before.sha256"
bash modules/09-toolkit-control.sh start
bash tools/termux-qualify.sh gui
```

Förväntat: feature.sh OK, startkod 0 och GUI FAIL=0.
Restore skapar först `backups/pre-restore-*.tar.gz` med tillståndet före
återställningen. Nätverkshistoriken ersätts också med backupens innehåll.

## 4. Verifiera automatisk rollback utan att skada installationen

```bash
cd "$HOME/nht-termux-test"
python tools/test_installation.py MaintenanceTests.test_restore_critical_failure_rolls_back MaintenanceTests.test_update_failure_restores_files_and_state
```

Förväntat: två tester, OK, inga överhoppade. Dessa kör verkliga
restore-/update-skript i temporära kopior och injicerar ett kritiskt
diagnostikfel. De kräver kod 3, återställda filer och bevarad nätverkshistorik.
Diagnostik är simulerad; detta ersätter inte GUI-/driftkontrollen ovan.
Inget av testen installerar paket eller ändrar den aktiva Toolkit-kopian.

## 5. Manuell rollback till en tidigare Toolkit-backup

Spara arbete, stoppa XFCE och välj en betrodd komplett backup:

```bash
cd "$HOME/nht-termux-test"
bash modules/09-toolkit-control.sh stop
bash restore.sh
printf 'ROLLBACK_RESTORE_EXIT=%s\n' "$?"
```

Välj önskad `nethunter-toolkit-*.tar.gz`,
`nethunter-toolkit-pre-update-*.tar.gz` eller `pre-restore-*.tar.gz` i menyn
och svara `y`. Förväntat: 0. Starta och kontrollera sedan GUI enligt steg 3.
Detta återställer Toolkit, inte paketversioner eller hela Ubuntu.
Ofullständiga äldre backuper kan avvisas; kringgå inte kontrollen.
Termux-testpaketet ska inte läggas i updates som en release: ett sådant paket
kräver en nyare versionsbeteckning och ett separat exakt uppdateringsmanifest.

Restore-koder: 0 klar/avböjd bekräftelse, 1 ogiltigt val/inga backuper,
2 blockerat före filbyte, 3 misslyckat med lyckad automatisk återgång,
4 misslyckad återgång. Vid kod 4: stoppa testet och bevara backup, loggar och
arbetskopior. Kör inte cleanup eller ta bort installationslåset på chans.

## 6. Fulla isolerade underhållstester på Android

```bash
cd "$HOME/nht-termux-test"
python tools/test_installation.py
python tools/test_packaging.py
```

Förväntat: 21 respektive 1 godkända tester, inga överhoppade. Pakettestet
bygger i en temporär kopia. Filerna i den aktiva installationen ändras inte.
Spara `logs/qualification/` och resultat från backup/restore/rollback med
telefonmodell, Android-version och om Ubuntu fanns före installationen.
