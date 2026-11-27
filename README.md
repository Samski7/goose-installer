# Goose-installer

Installeert [Goose Desktop](https://github.com/block/goose) op Windows. Goose is een AI-assistent die zelf taken uitvoert op je pc:
- bestanden en mappen beheren;
- commando's uitvoeren;
- desktop-apps bedienen;
- in Chrome zoeken;
- taken inplannen.

Werkt met een Anthropic API-sleutel:
- **Claude Sonnet 5.5** voor het hoofdwerk;
- **Claude Haiku 5.5** voor deeltaken (subagents). Je kunt in Goose ook zelf naar Haiku overschakelen.

Andere modellen zijn geblokkeerd.

**Daglimiet: €1 tokenverbruik per dag.** Een kleine kostenwacht op je pc telt het verbruik. Is de limiet bereikt, dan meldt Goose "Daglimiet bereikt" en kan je de volgende dag weer verder. Je verbruik van vandaag zie je met `Verbruik.cmd`.

## Installeren
1. Klik hierboven op de groene knop **Code** en dan op **Download ZIP**. Een GitHub-account is niet nodig.
2. Pak de zip uit.
3. Dubbelklik op **Installeer.cmd**. Krijg je een blauw venster "Windows heeft uw pc beschermd"? Klik dan op *Meer informatie* en daarna op *Toch uitvoeren*.
4. Plak de API-sleutel die je kreeg. Je ziet niets verschijnen terwijl je plakt, dat is normaal. Druk daarna op Enter.

De installatie duurt een paar minuten. Ontbrekende onderdelen (Goose, Node.js, Python) worden automatisch geïnstalleerd via winget. Start daarna **Goose** via het Startmenu.

## Wat er gebeurt
- **Goose Desktop** wordt geïnstalleerd. Het is open source (Apache-2.0) en gemaakt door Block en de Agentic AI Foundation.
- **Extensies** worden geïnstalleerd:
  - Windows-MCP, om desktop-apps te bedienen;
  - Playwright MCP, om in een browser te werken (standaard uit; Goose zet die aan wanneer nodig).
- **Kostenwacht:** een klein programma dat alleen op je eigen pc luistert (127.0.0.1:47821). Het start automatisch bij het aanmelden in Windows en houdt het dagverbruik bij in `%LOCALAPPDATA%\GooseInstaller\kostenwacht`. Het bewaart geen gesprekken.
- **Veiligheidsregels:** Goose vraagt toestemming voor riskante acties en sluit geen apps geforceerd af.
- **Je bestaande instellingen** worden eerst bewaard en bij het verwijderen teruggezet.
- **De API-sleutel** komt alleen op je eigen pc te staan, als Windows-gebruikersvariabele `ANTHROPIC_API_KEY`. Ze staat **niet** in deze repository.

## Bijwerken en verwijderen
- **Bijwerken:** download de nieuwe zip, pak ze uit en dubbelklik daarin op `Updaten.cmd`. Je API-sleutel blijft behouden.
- **Verwijderen:** dubbelklik op `Verwijderen.cmd`. Daarmee verdwijnen de extensies, de instellingen van het pakket en de sleutel. Goose zelf verwijder je via *Instellingen > Apps*.

`Verwijderen.cmd` staat na de installatie ook in `%LOCALAPPDATA%\GooseInstaller\pakket`.
