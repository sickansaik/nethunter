# Releasegranskning – 25 oktober 2026, uppdaterad 26 oktober

Arbetskopian saknar `.git`; commit 845d752 kan inte verifieras här.
Stable v0.4.4 finns inte i arbetskopian och har inte ändrats eller kvalificerats.
Den befintliga releaseförankringen avser historisk v0.5.0 Stable.
Denna granskning kvalificerar inte en ny stabil release.

## Verifierad rättning

`tools/test_packaging.py` reproducerade att två byggen av identisk källkod
gav olika gzip-bytes. Paketeraren använder nu en tom gzip-filnamnsheader och
tidsstämpeln 0. Testet körs i en temporär källkodskopia och kontrollerar exakt
arkivinnehåll mot paketmanifestet, SHA-256, exekveringsbit för nht, bevarat
historiskt manifest och uteslutning av runtime/network. Validatorn kör testet.
Inget befintligt distributionsarkiv har byggts om.

Första paketeringsrättningen verifierades med syntax för 48 skript,
ShellCheck, 15 arkiv-/underhållstester och paketeringstestet.

## Rättade granskningsfynd

- Backup och säkerhetskopior inför restore/update packas nu upp i en tillfällig
  katalog med samma strikta arkivkontroll som restore. Den uppackade kopian
  kontrolleras för fullständighet innan backup godkänns eller livefiler ersätts.
  Underkända verifieringsarkiv tas bort. Detta kräver Python och temporärt
  diskutrymme för en uppackad Toolkit-backup.
- `nht_require_installation` kräver nu reguljära filer för huvudskript och
  obligatoriska källfiler i config/lib/modules/runtime. Kataloger i stället
  för filer samt länkar och specialfiler i det ägda trädet avvisas.
- Modul 01 avbryter direkt om pkg update, upgrade eller install misslyckas,
  bevarar kommandots felkod och skriver inget framgångsmeddelande efter felet.
  Denna kontroll är explicit; ett misslyckat clear i en terminal utan TERM
  får inte hindra paketkontrollerna.

Tester lades till före produktionsrättningarna. De reproducerade ofullständiga
installationer, fel filtyp, godkänd osäker backup och dolda pkg-fel.
Arkivtesternas injektion använder exporterad Bash-funktion och en separat
markör som bevisar att testarkivet faktiskt används även med Git Bash.
Testerna kontrollerar även att osäker säkerhetskopia blockerar restore/update
före filbyte och att en backup med saknad lib/network/scan.sh avvisas.

Slutverifiering: `tools/test-windows.ps1` avslutades med kod 0. Bash-syntax
för 48 skript, ShellCheck, samtliga 21 arkiv-/underhållstester samt
paketeringstestet passerade utan överhoppade tester. Rollback vid kritiskt
restore-/update-fel och bevarad nätverkshistorik ingår i dessa tester.
En separat temporär kopia med återinfört gammalt arkiv-/pkg-beteende gav
exakt fem förväntade testfel utan testmiljöfel, vilket bekräftar att testerna
upptäcker regressionerna. Produktionskopian ändrades inte av den kontrollen.

## Kvarstående kvalificering

- Termux-testpaketet har ett separat `termux-package.manifest`. Det historiska
  `release.manifest` är inte ett aktuellt uppdateringsmanifest. Paketet ska inte
  användas som uppdateringsrelease; update kräver ett exakt release.manifest.
- Riktig clean-install på Android/Termux, inklusive paketinstallation och
  Ubuntu/X11/XFCE, har inte körts i denna Windows-miljö.
- Git-baserade gates, exempelvis `make check` och `make regression`, kan inte
  kvalificeras i denna nedladdade kopia utan `.git`.

## Bevarade historiska filer (SHA-256)

```text
285aa914085c1cfdb1a01bd68b26483c771a45e06127c24267f806a84515baba  release.manifest
95d5155f40573722bef7e9734d0e9511aa8bde0e399ab0badb8404cf1fd7402b  config/release-anchor.conf
8e8cad0f3c323eae74533fc3d4a573640753b23ff8adca67cb2eb660140372d3  RELEASE_INFO
```

Kontrollsummorna jämfördes före och efter ändringen och var oförändrade.
Befintliga backup-, restore- och update-tester körs i isolerade kopior med
simulerad driftstatus; de bevisar inte driften på en Android-enhet.
