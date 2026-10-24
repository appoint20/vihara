#!/usr/bin/env python3
"""Regenerates Vihara/Resources/Cities.json — the mock place-search corpus.

Stands in for Google Places autocomplete so the search field can be built, demoed
and tested with no key, no network and no per-request bill. See
Vihara/Data/Stubs/BundledCityCatalogue.swift.

German names are primary because the app is German-first; `aliases` carry the local
and English spellings so "Florence", "Firenze" and "Florenz" all find the same city.

Coordinates are approximate city centres, good enough to sort by distance and to drop
a pin. They are mock data and must not be presented as validated — a `Place` in this
app may only exist once it has passed the validation gate, and nothing here has.

    Scripts/generate-cities.py
"""
import json, pathlib, sys, unicodedata

COUNTRIES = {
    "IT": "Italien", "ES": "Spanien", "DE": "Deutschland", "FR": "Frankreich",
    "AT": "Österreich", "CH": "Schweiz", "GB": "Vereinigtes Königreich",
    "IE": "Irland", "NL": "Niederlande", "BE": "Belgien", "LU": "Luxemburg",
    "DK": "Dänemark", "SE": "Schweden", "NO": "Norwegen", "FI": "Finnland",
    "IS": "Island", "PT": "Portugal", "GR": "Griechenland", "CZ": "Tschechien",
    "PL": "Polen", "HU": "Ungarn", "RO": "Rumänien", "BG": "Bulgarien",
    "RS": "Serbien", "HR": "Kroatien", "SI": "Slowenien", "SK": "Slowakei",
    "LT": "Litauen", "LV": "Lettland", "EE": "Estland", "UA": "Ukraine",
    "AL": "Albanien", "MK": "Nordmazedonien", "BA": "Bosnien und Herzegowina",
    "ME": "Montenegro", "TR": "Türkei", "AE": "Vereinigte Arabische Emirate",
    "QA": "Katar", "IL": "Israel", "JO": "Jordanien", "OM": "Oman",
    "EG": "Ägypten", "MA": "Marokko", "TN": "Tunesien", "ZA": "Südafrika",
    "KE": "Kenia", "TZ": "Tansania", "ET": "Äthiopien", "GH": "Ghana",
    "JP": "Japan", "KR": "Südkorea", "CN": "China", "HK": "Hongkong",
    "TW": "Taiwan", "TH": "Thailand", "SG": "Singapur", "MY": "Malaysia",
    "ID": "Indonesien", "VN": "Vietnam", "PH": "Philippinen", "IN": "Indien",
    "LK": "Sri Lanka", "MV": "Malediven", "NP": "Nepal", "US": "USA",
    "CA": "Kanada", "MX": "Mexiko", "CU": "Kuba", "CR": "Costa Rica",
    "PA": "Panama", "CO": "Kolumbien", "PE": "Peru", "EC": "Ecuador",
    "CL": "Chile", "AR": "Argentinien", "BR": "Brasilien", "UY": "Uruguay",
    "AU": "Australien", "NZ": "Neuseeland", "FJ": "Fidschi",
}

# id | German name | local name | sub-national region (blank = none) | CC | lat | lon | categories | extra aliases
DATA = """
rome|Rom|Roma|Latium|IT|41.9028|12.4964|cities,food|Rome
milan|Mailand|Milano|Lombardei|IT|45.4642|9.1900|cities|Milan
naples|Neapel|Napoli|Kampanien|IT|40.8518|14.2681|cities,food|Naples
turin|Turin|Torino|Piemont|IT|45.0703|7.6869|cities,food|Turin
palermo|Palermo|Palermo|Sizilien|IT|38.1157|13.3615|cities,food,coast|
genoa|Genua|Genova|Ligurien|IT|44.4056|8.9463|cities,coast|Genoa
bologna|Bologna|Bologna|Emilia-Romagna|IT|44.4949|11.3426|cities,food|
florence|Florenz|Firenze|Toskana|IT|43.7696|11.2558|cities,food|Florence
venice|Venedig|Venezia|Veneto|IT|45.4408|12.3155|cities|Venice
verona|Verona|Verona|Veneto|IT|45.4384|10.9916|cities|
bari|Bari|Bari|Apulien|IT|41.1171|16.8719|cities,coast|
catania|Catania|Catania|Sizilien|IT|37.5079|15.0830|cities,coast|
padua|Padua|Padova|Veneto|IT|45.4064|11.8768|cities|Padova
trieste|Triest|Trieste|Friaul-Julisch Venetien|IT|45.6495|13.7768|cities,coast|Trieste
parma|Parma|Parma|Emilia-Romagna|IT|44.8015|10.3279|cities,food|
modena|Modena|Modena|Emilia-Romagna|IT|44.6471|10.9252|cities,food|
ravenna|Ravenna|Ravenna|Emilia-Romagna|IT|44.4184|12.2035|cities|
rimini|Rimini|Rimini|Emilia-Romagna|IT|44.0678|12.5695|coast,cities|
perugia|Perugia|Perugia|Umbrien|IT|43.1107|12.3908|cities|
pisa|Pisa|Pisa|Toskana|IT|43.7228|10.4017|cities|
siena|Siena|Siena|Toskana|IT|43.3188|11.3308|cities,food|
lucca|Lucca|Lucca|Toskana|IT|43.8430|10.5077|cities|
amalfi|Amalfi|Amalfi|Kampanien|IT|40.6340|14.6027|coast,nature|
sorrento|Sorrent|Sorrento|Kampanien|IT|40.6263|14.3757|coast|Sorrento
como|Como|Como|Lombardei|IT|45.8081|9.0852|nature,mountains|
bergamo|Bergamo|Bergamo|Lombardei|IT|45.6983|9.6773|cities,mountains|
cinque-terre|Cinque Terre|Cinque Terre|Ligurien|IT|44.1461|9.6439|coast,nature|
bolzano|Bozen|Bolzano|Südtirol|IT|46.4983|11.3548|mountains|Bolzano
madrid|Madrid|Madrid|Madrid|ES|40.4168|-3.7038|cities,food|
barcelona|Barcelona|Barcelona|Katalonien|ES|41.3874|2.1686|cities,coast,food|
valencia|Valencia|València|Valencia|ES|39.4699|-0.3763|cities,coast,food|
seville|Sevilla|Sevilla|Andalusien|ES|37.3891|-5.9845|cities,food|Seville
zaragoza|Saragossa|Zaragoza|Aragón|ES|41.6488|-0.8891|cities|Zaragoza
malaga|Málaga|Málaga|Andalusien|ES|36.7213|-4.4214|coast,cities|Malaga
murcia|Murcia|Murcia|Murcia|ES|37.9922|-1.1307|cities|
palma|Palma de Mallorca|Palma|Balearen|ES|39.5696|2.6502|coast,cities|Mallorca
bilbao|Bilbao|Bilbao|Baskenland|ES|43.2630|-2.9350|cities,food|
alicante|Alicante|Alacant|Valencia|ES|38.3452|-0.4810|coast|
cordoba|Córdoba|Córdoba|Andalusien|ES|37.8882|-4.7794|cities|Cordoba
granada|Granada|Granada|Andalusien|ES|37.1773|-3.5986|cities,mountains|
san-sebastian|San Sebastián|Donostia|Baskenland|ES|43.3183|-1.9812|food,coast|San Sebastian
santiago|Santiago de Compostela|Santiago|Galicien|ES|42.8782|-8.5448|cities|
toledo|Toledo|Toledo|Kastilien-La Mancha|ES|39.8628|-4.0273|cities|
salamanca|Salamanca|Salamanca|Kastilien und León|ES|40.9701|-5.6635|cities|
ibiza|Ibiza|Eivissa|Balearen|ES|38.9067|1.4206|coast|Eivissa
formentera|Formentera|Formentera|Balearen|ES|38.7000|1.4500|coast,nature|
tenerife|Teneriffa|Tenerife|Kanaren|ES|28.2916|-16.6291|coast,mountains|Tenerife
las-palmas|Las Palmas|Las Palmas|Kanaren|ES|28.1235|-15.4363|coast|
berlin|Berlin|Berlin|Berlin|DE|52.5200|13.4050|cities|
hamburg|Hamburg|Hamburg|Hamburg|DE|53.5511|9.9937|cities,coast|
munich|München|München|Bayern|DE|48.1351|11.5820|cities,mountains|Munich,Muenchen
cologne|Köln|Köln|Nordrhein-Westfalen|DE|50.9375|6.9603|cities|Cologne,Koeln
frankfurt|Frankfurt am Main|Frankfurt|Hessen|DE|50.1109|8.6821|cities|
stuttgart|Stuttgart|Stuttgart|Baden-Württemberg|DE|48.7758|9.1829|cities|
dusseldorf|Düsseldorf|Düsseldorf|Nordrhein-Westfalen|DE|51.2277|6.7735|cities|Dusseldorf
leipzig|Leipzig|Leipzig|Sachsen|DE|51.3397|12.3731|cities|
dresden|Dresden|Dresden|Sachsen|DE|51.0504|13.7373|cities|
bremen|Bremen|Bremen|Bremen|DE|53.0793|8.8017|cities|
hanover|Hannover|Hannover|Niedersachsen|DE|52.3759|9.7320|cities|Hanover
nuremberg|Nürnberg|Nürnberg|Bayern|DE|49.4521|11.0767|cities|Nuremberg,Nuernberg
bonn|Bonn|Bonn|Nordrhein-Westfalen|DE|50.7374|7.0982|cities|
munster|Münster|Münster|Nordrhein-Westfalen|DE|51.9607|7.6261|cities|Munster
heidelberg|Heidelberg|Heidelberg|Baden-Württemberg|DE|49.3988|8.6724|cities|
freiburg|Freiburg im Breisgau|Freiburg|Baden-Württemberg|DE|47.9990|7.8421|cities,mountains|
rostock|Rostock|Rostock|Mecklenburg-Vorpommern|DE|54.0924|12.0991|coast|
potsdam|Potsdam|Potsdam|Brandenburg|DE|52.3906|13.0645|cities|
paris|Paris|Paris|Île-de-France|FR|48.8566|2.3522|cities,food|
marseille|Marseille|Marseille|Provence|FR|43.2965|5.3698|coast,cities|
lyon|Lyon|Lyon|Auvergne-Rhône-Alpes|FR|45.7640|4.8357|cities,food|
toulouse|Toulouse|Toulouse|Okzitanien|FR|43.6047|1.4442|cities|
nice|Nizza|Nice|Côte d'Azur|FR|43.7102|7.2620|coast,cities|Nice
nantes|Nantes|Nantes|Pays de la Loire|FR|47.2184|-1.5536|cities|
montpellier|Montpellier|Montpellier|Okzitanien|FR|43.6108|3.8767|cities,coast|
strasbourg|Straßburg|Strasbourg|Grand Est|FR|48.5734|7.7521|cities|Strasbourg,Strassburg
bordeaux|Bordeaux|Bordeaux|Nouvelle-Aquitaine|FR|44.8378|-0.5792|cities,food|
lille|Lille|Lille|Hauts-de-France|FR|50.6292|3.0573|cities|
rennes|Rennes|Rennes|Bretagne|FR|48.1173|-1.6778|cities|
reims|Reims|Reims|Grand Est|FR|49.2583|4.0317|cities,food|
cannes|Cannes|Cannes|Côte d'Azur|FR|43.5528|7.0174|coast|
avignon|Avignon|Avignon|Provence|FR|43.9493|4.8055|cities|
annecy|Annecy|Annecy|Auvergne-Rhône-Alpes|FR|45.8992|6.1294|mountains,nature|
chamonix|Chamonix|Chamonix|Auvergne-Rhône-Alpes|FR|45.9237|6.8694|mountains|
vienna|Wien|Wien|Wien|AT|48.2082|16.3738|cities,food|Vienna
graz|Graz|Graz|Steiermark|AT|47.0707|15.4395|cities|
linz|Linz|Linz|Oberösterreich|AT|48.3069|14.2858|cities|
salzburg|Salzburg|Salzburg|Salzburg|AT|47.8095|13.0550|cities,mountains|
innsbruck|Innsbruck|Innsbruck|Tirol|AT|47.2692|11.4041|mountains|
hallstatt|Hallstatt|Hallstatt|Oberösterreich|AT|47.5622|13.6493|nature,mountains|
zurich|Zürich|Zürich|Zürich|CH|47.3769|8.5417|cities|Zurich
geneva|Genf|Genève|Genf|CH|46.2044|6.1432|cities|Geneva,Geneve
basel|Basel|Basel|Basel|CH|47.5596|7.5886|cities|
bern|Bern|Bern|Bern|CH|46.9480|7.4474|cities|Berne
lausanne|Lausanne|Lausanne|Waadt|CH|46.5197|6.6323|cities|
lucerne|Luzern|Luzern|Luzern|CH|47.0502|8.3093|mountains,nature|Lucerne
lugano|Lugano|Lugano|Tessin|CH|46.0037|8.9511|nature|
interlaken|Interlaken|Interlaken|Bern|CH|46.6863|7.8632|mountains,nature|
zermatt|Zermatt|Zermatt|Wallis|CH|46.0207|7.7491|mountains|
london|London|London||GB|51.5074|-0.1278|cities,food|
manchester|Manchester|Manchester||GB|53.4808|-2.2426|cities|
glasgow|Glasgow|Glasgow|Schottland|GB|55.8642|-4.2518|cities|
liverpool|Liverpool|Liverpool||GB|53.4084|-2.9916|cities|
edinburgh|Edinburgh|Edinburgh|Schottland|GB|55.9533|-3.1883|cities|
bristol|Bristol|Bristol||GB|51.4545|-2.5879|cities|
birmingham|Birmingham|Birmingham||GB|52.4862|-1.8904|cities|
leeds|Leeds|Leeds||GB|53.8008|-1.5491|cities|
oxford|Oxford|Oxford||GB|51.7520|-1.2577|cities|
cambridge|Cambridge|Cambridge||GB|52.2053|0.1218|cities|
brighton|Brighton|Brighton||GB|50.8225|-0.1372|coast|
york|York|York||GB|53.9600|-1.0873|cities|
bath|Bath|Bath||GB|51.3811|-2.3590|cities|
belfast|Belfast|Belfast|Nordirland|GB|54.5973|-5.9301|cities|
dublin|Dublin|Dublin||IE|53.3498|-6.2603|cities|
cork|Cork|Cork||IE|51.8985|-8.4756|cities|
galway|Galway|Galway||IE|53.2707|-9.0568|coast,nature|
amsterdam|Amsterdam|Amsterdam|Nordholland|NL|52.3676|4.9041|cities|
rotterdam|Rotterdam|Rotterdam|Südholland|NL|51.9244|4.4777|cities|
the-hague|Den Haag|Den Haag|Südholland|NL|52.0705|4.3007|cities|The Hague
utrecht|Utrecht|Utrecht|Utrecht|NL|52.0907|5.1214|cities|
eindhoven|Eindhoven|Eindhoven|Nordbrabant|NL|51.4416|5.4697|cities|
maastricht|Maastricht|Maastricht|Limburg|NL|50.8514|5.6910|cities|
brussels|Brüssel|Bruxelles||BE|50.8503|4.3517|cities,food|Brussels,Bruessel
antwerp|Antwerpen|Antwerpen|Flandern|BE|51.2194|4.4025|cities|Antwerp
ghent|Gent|Gent|Flandern|BE|51.0543|3.7174|cities|Ghent
bruges|Brügge|Brugge|Flandern|BE|51.2093|3.2247|cities|Bruges,Bruegge
luxembourg|Luxemburg|Luxembourg||LU|49.6116|6.1319|cities|Luxembourg
copenhagen|Kopenhagen|København|Hovedstaden|DK|55.6761|12.5683|cities,food|Copenhagen
aarhus|Aarhus|Aarhus|Midtjylland|DK|56.1629|10.2039|cities|
stockholm|Stockholm|Stockholm|Stockholm|SE|59.3293|18.0686|cities|
gothenburg|Göteborg|Göteborg|Västra Götaland|SE|57.7089|11.9746|cities,coast|Gothenburg
malmo|Malmö|Malmö|Skåne|SE|55.6050|13.0038|cities|Malmo
kiruna|Kiruna|Kiruna|Lappland|SE|67.8558|20.2253|nature|
oslo|Oslo|Oslo|Oslo|NO|59.9139|10.7522|cities|
bergen|Bergen|Bergen|Vestland|NO|60.3913|5.3221|coast,nature|
trondheim|Trondheim|Trondheim|Trøndelag|NO|63.4305|10.3951|cities|
tromso|Tromsø|Tromsø|Troms|NO|69.6492|18.9553|nature|Tromso
lofoten|Lofoten|Lofoten|Nordland|NO|68.2000|13.6000|nature,coast|
helsinki|Helsinki|Helsinki|Uusimaa|FI|60.1699|24.9384|cities|
turku|Turku|Turku|Varsinais-Suomi|FI|60.4518|22.2666|cities|
rovaniemi|Rovaniemi|Rovaniemi|Lappland|FI|66.5039|25.7294|nature|
reykjavik|Reykjavík|Reykjavík||IS|64.1466|-21.9426|cities,nature|Reykjavik
lisbon|Lissabon|Lisboa|Lissabon|PT|38.7223|-9.1393|cities,food,coast|Lisbon,Lisboa
porto|Porto|Porto|Porto|PT|41.1579|-8.6291|cities,food|Oporto
faro|Faro|Faro|Algarve|PT|37.0194|-7.9304|coast|
funchal|Funchal|Funchal|Madeira|PT|32.6669|-16.9241|coast,nature|Madeira
coimbra|Coimbra|Coimbra|Centro|PT|40.2033|-8.4103|cities|
braga|Braga|Braga|Norte|PT|41.5454|-8.4265|cities|
lagos|Lagos|Lagos|Algarve|PT|37.1028|-8.6742|coast|
athens|Athen|Αθήνα|Attika|GR|37.9838|23.7275|cities|Athens,Athina
thessaloniki|Thessaloniki|Θεσσαλονίκη|Zentralmakedonien|GR|40.6401|22.9444|cities,food|
heraklion|Heraklion|Ηράκλειο|Kreta|GR|35.3387|25.1442|coast,cities|Iraklion
chania|Chania|Χανιά|Kreta|GR|35.5138|24.0180|coast|
rhodes|Rhodos|Ρόδος|Südliche Ägäis|GR|36.4341|28.2176|coast|Rhodes
santorini|Santorini|Σαντορίνη|Südliche Ägäis|GR|36.3932|25.4615|coast,nature|Thira
mykonos|Mykonos|Μύκονος|Südliche Ägäis|GR|37.4467|25.3289|coast|
corfu|Korfu|Κέρκυρα|Ionische Inseln|GR|39.6243|19.9217|coast|Corfu,Kerkyra
prague|Prag|Praha||CZ|50.0755|14.4378|cities,food|Prague,Praha
brno|Brno|Brno|Mähren|CZ|49.1951|16.6068|cities|Bruenn
warsaw|Warschau|Warszawa|Masowien|PL|52.2297|21.0122|cities|Warsaw,Warszawa
krakow|Krakau|Kraków|Kleinpolen|PL|50.0647|19.9450|cities|Krakow,Cracow
gdansk|Danzig|Gdańsk|Pommern|PL|54.3520|18.6466|coast,cities|Gdansk
wroclaw|Breslau|Wrocław|Niederschlesien|PL|51.1079|17.0385|cities|Wroclaw
poznan|Posen|Poznań|Großpolen|PL|52.4064|16.9252|cities|Poznan
budapest|Budapest|Budapest||HU|47.4979|19.0402|cities,food|
bucharest|Bukarest|București||RO|44.4268|26.1025|cities|Bucharest,Bucuresti
cluj|Cluj-Napoca|Cluj-Napoca|Siebenbürgen|RO|46.7712|23.6236|cities|Klausenburg
brasov|Brașov|Brașov|Siebenbürgen|RO|45.6427|25.5887|mountains|Brasov,Kronstadt
sofia|Sofia|София||BG|42.6977|23.3219|cities|
plovdiv|Plowdiw|Пловдив||BG|42.1354|24.7453|cities|Plovdiv
belgrade|Belgrad|Beograd||RS|44.7866|20.4489|cities|Belgrade,Beograd
zagreb|Zagreb|Zagreb||HR|45.8150|15.9819|cities|
split|Split|Split|Dalmatien|HR|43.5081|16.4402|coast|
dubrovnik|Dubrovnik|Dubrovnik|Dalmatien|HR|42.6507|18.0944|coast,cities|
ljubljana|Ljubljana|Ljubljana||SI|46.0569|14.5058|cities|Laibach
bled|Bled|Bled||SI|46.3683|14.1146|nature,mountains|
bratislava|Bratislava|Bratislava||SK|48.1486|17.1077|cities|Pressburg
vilnius|Vilnius|Vilnius||LT|54.6872|25.2797|cities|Wilna
riga|Riga|Rīga||LV|56.9496|24.1052|cities|
tallinn|Tallinn|Tallinn||EE|59.4370|24.7536|cities|Reval
kyiv|Kiew|Київ||UA|50.4501|30.5234|cities|Kyiv,Kiev
lviv|Lemberg|Львів||UA|49.8397|24.0297|cities|Lviv
tirana|Tirana|Tiranë||AL|41.3275|19.8187|cities|
skopje|Skopje|Скопје||MK|41.9973|21.4280|cities|
sarajevo|Sarajevo|Sarajevo||BA|43.8563|18.4131|cities|
kotor|Kotor|Kotor||ME|42.4247|18.7712|coast,nature|
istanbul|Istanbul|İstanbul||TR|41.0082|28.9784|cities,food|Constantinople
ankara|Ankara|Ankara||TR|39.9334|32.8597|cities|
izmir|Izmir|İzmir||TR|38.4237|27.1428|coast,cities|Smyrna
antalya|Antalya|Antalya||TR|36.8969|30.7133|coast|
cappadocia|Kappadokien|Kapadokya||TR|38.6431|34.8289|nature|Cappadocia
dubai|Dubai|دبي||AE|25.2048|55.2708|cities|
abu-dhabi|Abu Dhabi|أبو ظبي||AE|24.4539|54.3773|cities|
doha|Doha|الدوحة||QA|25.2854|51.5310|cities|
tel-aviv|Tel Aviv|תל אביב||IL|32.0853|34.7818|cities,coast,food|
jerusalem|Jerusalem|ירושלים||IL|31.7683|35.2137|cities|
amman|Amman|عمّان||JO|31.9454|35.9284|cities|
petra|Petra|البتراء||JO|30.3285|35.4444|nature|
muscat|Maskat|مسقط||OM|23.5880|58.3829|cities,coast|Muscat
cairo|Kairo|القاهرة||EG|30.0444|31.2357|cities|Cairo
luxor|Luxor|الأقصر||EG|25.6872|32.6396|cities|
hurghada|Hurghada|الغردقة||EG|27.2579|33.8116|coast|
marrakesh|Marrakesch|مراكش||MA|31.6295|-7.9811|cities|Marrakesh,Marrakech
casablanca|Casablanca|الدار البيضاء||MA|33.5731|-7.5898|cities,coast|
fes|Fès|فاس||MA|34.0181|-5.0078|cities|Fez,Fes
tangier|Tanger|طنجة||MA|35.7595|-5.8340|coast,cities|Tangier
tunis|Tunis|تونس||TN|36.8065|10.1815|cities|
cape-town|Kapstadt|Cape Town|Westkap|ZA|-33.9249|18.4241|coast,cities,nature|Cape Town
johannesburg|Johannesburg|Johannesburg|Gauteng|ZA|-26.2041|28.0473|cities|
nairobi|Nairobi|Nairobi||KE|-1.2921|36.8219|cities,nature|
zanzibar|Sansibar|Zanzibar||TZ|-6.1659|39.2026|coast|Zanzibar
addis-ababa|Addis Abeba|አዲስ አበባ||ET|9.0320|38.7469|cities|Addis Ababa
accra|Accra|Accra||GH|5.6037|-0.1870|cities,coast|
tokyo|Tokio|東京||JP|35.6762|139.6503|cities,food|Tokyo
osaka|Osaka|大阪||JP|34.6937|135.5023|cities,food|
kyoto|Kyoto|京都||JP|35.0116|135.7681|cities|Kioto
sapporo|Sapporo|札幌||JP|43.0618|141.3545|cities,mountains|
hiroshima|Hiroshima|広島||JP|34.3853|132.4553|cities|
seoul|Seoul|서울||KR|37.5665|126.9780|cities,food|
busan|Busan|부산||KR|35.1796|129.0756|coast,cities|Pusan
beijing|Peking|北京||CN|39.9042|116.4074|cities|Beijing
shanghai|Shanghai|上海||CN|31.2304|121.4737|cities|
hong-kong|Hongkong|香港||HK|22.3193|114.1694|cities,food|Hong Kong
taipei|Taipeh|臺北||TW|25.0330|121.5654|cities,food|Taipei
bangkok|Bangkok|กรุงเทพ||TH|13.7563|100.5018|cities,food|
chiang-mai|Chiang Mai|เชียงใหม่||TH|18.7883|98.9853|mountains,nature|
phuket|Phuket|ภูเก็ต||TH|7.8804|98.3923|coast|
singapore|Singapur|Singapore||SG|1.3521|103.8198|cities,food|Singapore
kuala-lumpur|Kuala Lumpur|Kuala Lumpur||MY|3.1390|101.6869|cities,food|
jakarta|Jakarta|Jakarta||ID|-6.2088|106.8456|cities|
bali|Bali|Bali||ID|-8.4095|115.1889|coast,nature|Denpasar
hanoi|Hanoi|Hà Nội||VN|21.0285|105.8542|cities,food|
ho-chi-minh|Ho-Chi-Minh-Stadt|Thành phố Hồ Chí Minh||VN|10.8231|106.6297|cities,food|Saigon,Ho Chi Minh City
manila|Manila|Manila||PH|14.5995|120.9842|cities|
delhi|Delhi|दिल्ली||IN|28.6139|77.2090|cities,food|New Delhi
mumbai|Mumbai|मुंबई||IN|19.0760|72.8777|cities,food|Bombay
jaipur|Jaipur|जयपुर|Rajasthan|IN|26.9124|75.7873|cities|
goa|Goa|Goa||IN|15.2993|74.1240|coast|
kochi|Kochi|കൊച്ചി|Kerala|IN|9.9312|76.2673|coast|Cochin
colombo|Colombo|කොළඹ||LK|6.9271|79.8612|cities,coast|
male|Malé|މާލެ||MV|4.1755|73.5093|coast|Male,Maldives
kathmandu|Kathmandu|काठमाडौँ||NP|27.7172|85.3240|cities,mountains|
pokhara|Pokhara|पोखरा||NP|28.2096|83.9856|mountains,nature|
new-york|New York|New York|New York|US|40.7128|-74.0060|cities,food|NYC,New York City
los-angeles|Los Angeles|Los Angeles|Kalifornien|US|34.0522|-118.2437|cities,coast|LA
san-francisco|San Francisco|San Francisco|Kalifornien|US|37.7749|-122.4194|cities,food|SF
chicago|Chicago|Chicago|Illinois|US|41.8781|-87.6298|cities,food|
miami|Miami|Miami|Florida|US|25.7617|-80.1918|coast,cities|
boston|Boston|Boston|Massachusetts|US|42.3601|-71.0589|cities|
washington|Washington|Washington|District of Columbia|US|38.9072|-77.0369|cities|Washington DC
seattle|Seattle|Seattle|Washington|US|47.6062|-122.3321|cities,nature|
las-vegas|Las Vegas|Las Vegas|Nevada|US|36.1699|-115.1398|cities|
new-orleans|New Orleans|New Orleans|Louisiana|US|29.9511|-90.0715|cities,food|
austin|Austin|Austin|Texas|US|30.2672|-97.7431|cities,food|
denver|Denver|Denver|Colorado|US|39.7392|-104.9903|mountains,cities|
honolulu|Honolulu|Honolulu|Hawaii|US|21.3069|-157.8583|coast|
toronto|Toronto|Toronto|Ontario|CA|43.6532|-79.3832|cities|
vancouver|Vancouver|Vancouver|British Columbia|CA|49.2827|-123.1207|cities,nature|
montreal|Montreal|Montréal|Québec|CA|45.5017|-73.5673|cities,food|Montréal
quebec-city|Québec|Québec|Québec|CA|46.8139|-71.2080|cities|Quebec City
banff|Banff|Banff|Alberta|CA|51.1784|-115.5708|mountains,nature|
mexico-city|Mexiko-Stadt|Ciudad de México||MX|19.4326|-99.1332|cities,food|Mexico City,CDMX
cancun|Cancún|Cancún|Quintana Roo|MX|21.1619|-86.8515|coast|Cancun
oaxaca|Oaxaca|Oaxaca|Oaxaca|MX|17.0732|-96.7266|cities,food|
havana|Havanna|La Habana||CU|23.1136|-82.3666|cities|Havana,La Habana
san-jose-cr|San José|San José||CR|9.9281|-84.0907|cities,nature|San Jose
panama-city|Panama-Stadt|Ciudad de Panamá||PA|8.9824|-79.5199|cities|Panama City
bogota|Bogotá|Bogotá||CO|4.7110|-74.0721|cities|Bogota
cartagena|Cartagena|Cartagena||CO|10.3910|-75.4794|coast,cities|
lima|Lima|Lima||PE|-12.0464|-77.0428|cities,food|
cusco|Cusco|Cusco||PE|-13.5319|-71.9675|mountains,cities|Cuzco
quito|Quito|Quito||EC|-0.1807|-78.4678|cities,mountains|
santiago-cl|Santiago de Chile|Santiago||CL|-33.4489|-70.6693|cities,mountains|Santiago
buenos-aires|Buenos Aires|Buenos Aires||AR|-34.6037|-58.3816|cities,food|
rio-de-janeiro|Rio de Janeiro|Rio de Janeiro|Rio de Janeiro|BR|-22.9068|-43.1729|coast,cities|Rio
sao-paulo|São Paulo|São Paulo|São Paulo|BR|-23.5505|-46.6333|cities,food|Sao Paulo
salvador|Salvador|Salvador|Bahia|BR|-12.9777|-38.5016|coast,cities|
montevideo|Montevideo|Montevideo||UY|-34.9011|-56.1645|cities,coast|
sydney|Sydney|Sydney|New South Wales|AU|-33.8688|151.2093|cities,coast|
melbourne|Melbourne|Melbourne|Victoria|AU|-37.8136|144.9631|cities,food|
brisbane|Brisbane|Brisbane|Queensland|AU|-27.4698|153.0251|cities,coast|
perth|Perth|Perth|Western Australia|AU|-31.9505|115.8605|coast,cities|
cairns|Cairns|Cairns|Queensland|AU|-16.9186|145.7781|coast,nature|
auckland|Auckland|Auckland||NZ|-36.8485|174.7633|cities,coast|
wellington|Wellington|Wellington||NZ|-41.2866|174.7756|cities|
queenstown|Queenstown|Queenstown|Otago|NZ|-45.0312|168.6626|mountains,nature|
nadi|Nadi|Nadi||FJ|-17.7765|177.4356|coast|
"""

def fold(s):
    """Diacritic- and case-insensitive search key, matching Swift's `fold`."""
    d = unicodedata.normalize("NFD", s)
    return "".join(c for c in d if unicodedata.category(c) != "Mn").lower()

cities, seen = [], set()
for line in DATA.strip().splitlines():
    parts = line.split("|")
    if len(parts) != 9:
        sys.exit(f"malformed row ({len(parts)} fields): {line}")
    cid, name, local, subregion, cc, lat, lon, cats, extra = (p.strip() for p in parts)
    if cid in seen:
        sys.exit(f"duplicate id: {cid}")
    seen.add(cid)
    if cc not in COUNTRIES:
        sys.exit(f"unknown country code {cc} on {cid}")
    country = COUNTRIES[cc]
    region = f"{subregion}, {country}" if subregion else country

    # Aliases are what the search matches on beyond the display name: the local
    # spelling, the English one, and any historical name worth finding.
    aliases = {local, name} | {a.strip() for a in extra.split(",") if a.strip()}
    aliases = sorted({a for a in aliases if a and fold(a) != fold(name)})

    cities.append({
        "id": cid,
        "name": name,
        "localName": local,
        "country": country,
        "countryCode": cc,
        "region": region,
        "latitude": float(lat),
        "longitude": float(lon),
        "categories": sorted(c.strip() for c in cats.split(",") if c.strip()),
        "aliases": aliases,
    })

VALID = {"food", "coast", "mountains", "cities", "nature"}
for c in cities:
    bad = set(c["categories"]) - VALID
    if bad:
        sys.exit(f"{c['id']}: unknown categories {bad}")
    if not -90 <= c["latitude"] <= 90 or not -180 <= c["longitude"] <= 180:
        sys.exit(f"{c['id']}: coordinate out of range")

cities.sort(key=lambda c: fold(c["name"]))
out = pathlib.Path(__file__).resolve().parent.parent / "Vihara/Resources/Cities.json"
payload = {
    "version": 1,
    "note": "Mock search corpus. Approximate city-centre coordinates; nothing here is validated.",
    "cities": cities,
}
out.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"wrote {out.relative_to(out.parent.parent.parent)} — {len(cities)} cities, "
      f"{len(COUNTRIES)} countries known, {sum(len(c['aliases']) for c in cities)} aliases")
