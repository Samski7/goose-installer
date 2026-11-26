# Goose-installer

Installeert [Goose Desktop](https://github.com/block/goose) op Windows. Goose is een AI-assistent die zelf taken uitvoert op je pc:
- bestanden en mappen beheren;
- commando's uitvoeren;
- desktop-apps bedienen;
- in Chrome zoeken;
- taken inplannen.

Werkt met Claude Sonnet via een Anthropic API-sleutel.

## Installeren

**Manier 1: dubbelklikken**
1. Klik hierboven op de groene knop **Code** en dan op **Download ZIP**.
2. Pak de zip uit.
3. Dubbelklik op **Installeer.cmd**. Krijg je een blauw venster "Windows heeft uw pc beschermd"? Klik dan op *Meer informatie* en daarna op *Toch uitvoeren*.
4. Plak de API-sleutel die je kreeg. Je ziet niets verschijnen terwijl je plakt, dat is normaal. Druk daarna op Enter.

**Manier 2: één commando.** Open PowerShell en plak:

```powershell
irm https://raw.githubusercontent.com/Samski7/goose-installer/main/get.ps1 | iex
```

De installatie duurt een paar minuten. Ontbrekende onderdelen (Goose, Node.js, Python) worden automatisch geïnstalleerd via winget. Start daarna **Goose** via het Startmenu.

## Wat er gebeurt
- **Goose Desktop** wordt geïnstalleerd. Het is open source (Apache-2.0) en gemaakt door Block en de Agentic AI Foundation.
- **Extensies** worden geïnstalleerd:
  - Windows-MCP, om desktop-apps te bedienen;
  - Playwright MCP, om in een browser te werken (standaard uit; Goose zet die aan wanneer nodig).
- **Veiligheidsregels:** Goose vraagt toestemming voor riskante acties en sluit geen apps geforceerd af.
- **Je bestaande instellingen** worden eerst bewaard en bij het verwijderen teruggezet.
- **De API-sleutel** komt alleen op je eigen pc te staan, als Windows-gebruikersvariabele `ANTHROPIC_API_KEY`. Ze staat **niet** in deze repository.

## Bijwerken en verwijderen
- **Bijwerken:** dubbelklik op `Updaten.cmd`. Dat haalt de nieuwste versie van deze pagina.
- **Verwijderen:** dubbelklik op `Verwijderen.cmd`. Daarmee verdwijnen de extensies, de instellingen van het pakket en de sleutel. Goose zelf verwijder je via *Instellingen > Apps*.

Deze bestanden staan na de installatie ook in `%LOCALAPPDATA%\GooseInstaller\pakket`.
