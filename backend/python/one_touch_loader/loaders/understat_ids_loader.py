"""Capology와 같은 외부 ID 테이블에 확인한 연결만 저장해요."""

from __future__ import annotations

from collections import defaultdict
from html import unescape

from ..core.db import transaction
from ..core.identity import normalize_identity_text, reciprocal_identity_matches, validate_external_id_uniqueness
from ..core.understat import UnderstatClient
from .understat_common import (
    load_external_ids, load_mapping_fixtures, load_player_observations,
    load_understat_scope, select_understat_matches, write_understat_report,
)


# 2025-03-30 경기 19135574의 DB 명단과 Understat 27270, 구단 공식 명단을 대조했어요.
# 약칭을 일반화하지 않고 확인된 공급자 ID만 연결해요.
# https://www.gironafc.cat/es/partidos/temporada-2024-2025-laliga-ea-sports-29-fc-barcelona-vs-girona-fc
# https://www.fcbarcelona.com/en/football/first-team/squad/68906/alejandro-balde
# https://www.gironafc.cat/es/noticias/arthur-melo-nou-jugador-del-girona
VERIFIED_UNDERSTAT_PLAYER_ID_OVERRIDES = {
    "9805": 37316480,  # Álex Balde → Alejandro Balde Martínez
    "6942": 219920,  # Arthur → Arthur Henrique Ramos de Oliveira Melo

    # 2026-09-09: 26/27의 표기 차이 110명을 같은 경기·팀의 DB 명단 290행과 대조했어요.
    # 약칭·철자·이름 순서를 일반화하지 않아요. 근거와 경기 ID는 UNDERSTAT_PLAYER_ID_REVIEW.md에 있어요.
    "8094": 21072805,  # Mathis Cherki → Rayan Cherki
    "7277": 14338473,  # Ryan John Giles → Ryan Giles
    "7432": 163108,  # Reinildo → Reinildo Mandava
    "8864": 6524,  # Matthew Cash → Matty Cash
    "9024": 24468970,  # Yeremi Pino → Yéremy Pino
    "11735": 37527169,  # Sávio → Savinho
    "11763": 37623459,  # Abduqodir Khusanov → Abdukodir Khusanov
    "11772": 37509395,  # Yehor Yarmolyuk → Yegor Yarmolyuk
    "12203": 37669492,  # Treymaurice Nyoni → Trey Nyoni
    "12911": 37560897,  # Abdul Fatawu → Abdul Fatawu Issahaku
    "13066": 25738,  # Ferdi Kadioglu → Ferdi Kadıoğlu
    "13222": 37407204,  # Thiago → Igor Thiago
    "13779": 37627298,  # Jair → Jair Cunha
    "14446": 37747533,  # Alysson Edward → Alysson
    "14773": 37601923,  # Sindre Egeli → Sindre Walle Egeli
    "6626": 3861542,  # Joshua Vagnoman → Josha Vagnoman
    "6708": 2483333,  # Bote Baku → Ridle Baku
    "9201": 37266184,  # Eren Sami Dinkci → Eren Dinkçi
    "14008": 37342993,  # Ezequiél Fernández → Equi Fernández
    "9546": 37369430,  # Nahuel Nicolas Noll → Nahuel Noll
    "10497": 27066902,  # Yannick Engelhardt → Yannik Engelhardt
    "10986": 322964,  # Kim Min-Jae → Min-jae Kim
    "12485": 37656833,  # Kouakou Gadou → Joane Gadou
    "15011": 37420363,  # Seol Young-Woo → Young-woo Seol
    "8287": 62600,  # Mbwana Samatta → Ally Samatta
    "11142": 37633394,  # Pierre Ganiou → Ismaëlo Ganiou
    "11757": 32777470,  # Hákon Haraldsson → Hákon Arnar Haraldsson
    "14817": 37713829,  # Adil Bourabaa → Adil Ali Mohamed Bourabaa
    "14869": 37356232,  # Flávio Nazinho → Nazinho
    "2447": 186735,  # Fabián → Fabián Ruiz
    "7612": 16496676,  # Nathan N'Goumou Minpol → Nathan Ngoumou
    "9563": 29336632,  # Mamadou Mbow → Moustapha Mbow
    "10810": 29809271,  # Alexsandro Ribeiro → Alexsandro
    "11061": 37630678,  # Michel Diaz → Junior Diaz
    "11355": 37554457,  # Noah Mbamba-Muanda → Noah Mbamba
    "11782": 474354,  # Mousa Al Tamari → Mousa Tamari
    "11910": 12393419,  # William Pacho → Willian Pacho
    "12258": 37699791,  # Luc Zogbe → Luck Zogbé
    "12346": 37562940,  # Beraldo → Lucas Beraldo
    "13062": 37430769,  # Mohammed Amoura → Mohamed Amoura
    "13159": 37738999,  # Marius Louãr → Marius Louër
    "13283": 37789987,  # Raphaël Le Guen → R. Le Guen
    "13385": 37912348,  # Zabi Gueu → Eloge Patrick Zabi Gueu
    "13745": 435539,  # Lionel Mpasi → Lionel Mpasi-Nzau
    "13795": 37576587,  # Dermane Karim → Karim Dermane
    "14083": 37715167,  # Enzo Koffi → Enzo Koffi Vinette
    "14358": 37595218,  # Pape Diop → Pape Demba Diop
    "14608": 38214383,  # Mezian Soares → Mezian Mesloub
    "14834": 37913694,  # Noah Donkor → Noah Donkor Znamensky
    "12030": 3188026,  # Tasos Douvikas → Anastasios Douvikas
    "7074": 215532,  # Nicolás González → Nico González
    "2521": 8062,  # Alfonso → Alfonso Pedraza
    "5136": 187969,  # Estupiñán → Pervis Estupiñán
    "6434": 96804,  # Franck Zambo → Frank Anguissa
    "6706": 15779395,  # Ndary Adopo → Michel Adopo
    "8554": 37459022,  # Rafael Obrador → Rafa Obrador
    "8636": 16827175,  # Jonathan Christian David → Jonathan David
    "8768": 37263769,  # Kevin Omoruyi → Kevin Carlos
    "10013": 37582883,  # Redouane Halal → Redouane Halhal
    "10957": 16144551,  # Mikael Ellertsson → Mikael Egill Ellertsson
    "10985": 37616125,  # Sulemana → Ibrahim Sulemana
    "11246": 37603838,  # Amar Ahmed Fatah → Amar Fatah
    "12168": 37584705,  # Alejandro Jiménez → Álex Jiménez
    "12885": 37551656,  # Kialonda Gaspar → Gaspar
    "13543": 37765134,  # Valde → Víctor Valdepeñas
    "14426": 37680350,  # Alex Amorim → Amorim
    "14846": 37761121,  # Ethan Meichtry → Franz-Ethan Meichtry
    "15038": 3169778,  # Pote → Pedro Gonçalves
    "5110": 186936,  # Mariano → Mariano Díaz
    "8271": 37297042,  # Fernando Niño → Fer Niño
    "8765": 21427714,  # Roberto Navarro → Robert Navarro
    "7313": 9967153,  # Lee Kang-In → Kang-in Lee
    "8696": 433169,  # Pape Alassane Gueye → Pape Gueye
    "10319": 4545454,  # Adrián De la Fuente → Adrián Dela
    "12742": 27440264,  # Peque → Peque Fernández
    "13823": 37716641,  # Miguel Sierra → Miguel Ángel Sierra Ortega
    "14700": 37544761,  # Cala → Álex Calatrava
    "2229": 8204,  # Yuri → Yuri Berchiche
    "2278": 186514,  # Giménez → José María Giménez
    "2280": 186426,  # Jonny → Jonny Otto
    "2385": 62317,  # Mat Ryan → Mathew Ryan
    "2555": 187110,  # Remiro → Álex Remiro
    "5199": 187935,  # Raba → Dani Raba
    "6151": 63020,  # Djené Dakonam → Dakonam Djené
    "6400": 10692,  # Antonio Martínez → Toni Martínez
    "6954": 240195,  # Juan Camilo Hernández → Cucho Hernández
    "7070": 189585,  # Santiago Comesaña → Santi Comesaña
    "7605": 23269641,  # Manuel Sánchez → Manu Sánchez
    "8108": 437094,  # Daniel Cárdenas → Dani Cárdenas
    "8861": 30446852,  # Urko Gonzalez → Urko González de Zárate
    "9241": 447491,  # Alfon → Alfon González
    "10322": 37571011,  # Javier Guerra → Javi Guerra
    "10352": 37603817,  # Johaneko Louis Jean → J. Louis-Jean
    "10576": 37537864,  # Álvaro Fernández → Álvaro Carreras
    "10930": 37646866,  # Etta Eyong → Karl Etta Eyong
    "11825": 26523850,  # Abderrahmane Rebbach → Abde Rebbach
    "11826": 261130,  # Carlos Benavídez → Carlos Protesoni
    "11834": 33213465,  # Adrià Alti → Adrià Altimira
    "11866": 160208,  # Álex Grimaldo → Alejandro Grimaldo
    "12180": 37652784,  # Javier Rodríguez → Javi Rodríguez
    "12643": 37316505,  # Javier Rueda → Javi Rueda
    "12903": 37716722,  # Rafael Bauza → Rafel Bauzà
    "13035": 37662761,  # Daniel Requena → Dani Requena
    "13278": 37624126,  # Youssef Lekhedim → Youssef Enríquez
    "13696": 37772769,  # Jean Valou → Jean Ives Valou
    "14233": 37656197,  # Dani Martinez → Daniel Martínez
    "14555": 37747012,  # Javier Morcillo → Javi Morcillo
    "14691": 37543638,  # Facu González → Facundo González
    "14717": 37737693,  # Umaru → Umaru Konare Tounkara
    "14728": 37718104,  # Rafita → Rafita Garrido

    # 2026-09-09: 21/22~25/26의 표기 차이 255명과 동명 선수 2명을 실제 경기·팀 명단과 대조했어요.
    # Benicio는 동명 DB ID가 둘이라 실제 Brighton 명단의 37402363만 연결해요.
    # 전체 근거와 경기 ID는 UNDERSTAT_PLAYER_ID_REVIEW.md에 남겼어요.
    "453": 4313,  # Son Heung-Min → Heung-min Son
    "493": 1441,  # Gabriel → Gabriel Paulista
    "565": 1281,  # Nyom → Allan Nyom
    "696": 1318,  # Falcao → R. Falcao
    "965": 809,  # Santiago Cazorla → Santi Cazorla
    "987": 1453,  # Joseph Gomez → Joe Gomez
    "1142": 129790,  # Samir → Samir Caetano
    "1190": 128857,  # Joel Obi → Joel Chukwuma Obi
    "1210": 129453,  # Keita → Keita Baldé
    "1246": 107444,  # Kostas Manolas → Konstantinos Manolas
    "1374": 38,  # José Reina → Pepe Reina
    "1382": 129500,  # José Callejón → Juanmi Callejón
    "1421": 129837,  # Cristian Tello → Cristian Tello Herrera
    "1491": 128943,  # Alejandro Gomez → Papu Gómez
    "1542": 128524,  # Stefan Radu → Ştefan Daniel Radu
    "1716": 4777,  # Bernardo → Bernardo Espinosa
    "1817": 1382,  # Mario Balotelli → M. Balotelli
    "1920": 129071,  # Gabriel Silva → Gabriel Silva
    "1927": 132671,  # Berat Gjimshiti → Berat Djimsiti
    "1946": 129689,  # Pepín → Pepín Machín
    "2065": 185870,  # Vicente Iborra → Vicente Iborra de la Fuente
    "2066": 187977,  # Curro → Curro Sánchez
    "2089": 186523,  # Robert Ibáñez → Rober Ibáñez
    "2092": 3779,  # Gerard Piqué → Gerard Piqué Bernabéu
    "2093": 185530,  # Jordi Alba → Jordi Alba Ramos
    "2100": 186455,  # Rafinha → Rafinha Alcântara
    "2106": 186463,  # Munir → Munir El Haddadi
    "2110": 186663,  # Rubén Duarte → Rubén Duarte Sánchez
    "2186": 186536,  # Morales → José Luis Morales
    "2193": 4493,  # Cala → Juan Cala
    "2226": 186400,  # Zaldúa → Joseba Zaldúa
    "2241": 186145,  # Oier → Oier Olazábal
    "2247": 186353,  # Nacho → Nacho Fernández
    "2282": 186450,  # Sergi Gómez → Sergi Gómez Solà
    "2296": 185677,  # Mario → Mario Gaspar
    "2311": 1295,  # Roberto Soldado → Roberto Soldado Rillo
    "2326": 187090,  # Rober → Róber Pier
    "2346": 186882,  # Aarón → Aarón Escandell
    "2368": 185868,  # Montoro → Ángel Montoro
    "2378": 1988,  # Daniel Parejo → Dani Parejo
    "2387": 64274,  # Danilo → Danilo Barbosa
    "2396": 185544,  # Balenziaga → Mikel Balenziaga Oruesagasti
    "2452": 185272,  # De Marcos → Óscar de Marcos
    "2475": 186619,  # Jaume → Jaume Doménech
    "2519": 187248,  # Tejero → Álvaro Tejero
    "2532": 187680,  # Amath Diedhiou → Amath Ndiaye
    "2566": 185975,  # Roger → Roger Martí
    "2574": 187072,  # Miguelón → Miguel Llambrich
    "2584": 186662,  # Raíllo → Antonio Raíllo
    "2592": 187060,  # Lazo → José Carlos Lazo
    "3244": 96063,  # Nicolas de Preville → N. de Préville
    "3682": 96571,  # Jordan Siebatcheu → Jordan
    "3785": 96801,  # Kelvin Adou → Kelvin Amian
    "3872": 130192,  # George Puscas → G. Pușcaș
    "3978": 2832,  # Marco Faraoni → Davide Faraoni
    "4070": 186530,  # Borja → Borja García
    "4136": 185205,  # Ángel → Ángel Rodríguez
    "4142": 186119,  # Álvaro → Álvaro Giménez
    "4202": 187254,  # Kevin → Kevin Vázquez
    "4468": 1439,  # Dedryck Boyata → Anga Dedryck Boyata
    "5056": 187116,  # Marlon Santos → Marlon
    "5061": 186606,  # Kepa → Kepa Arrizabalaga
    "5113": 186899,  # Santos Borré → Rafael Santos Borré
    "5124": 381034,  # Alberto Rodríguez → Tachi
    "5126": 128850,  # José Ángel → Cote
    "5138": 189349,  # Alejandro Pozo → Álex Pozo
    "5178": 187270,  # Antonio Moya → Toni Moya
    "5191": 187068,  # Álvaro Fernández → Álvaro Ferllo
    "5686": 97606,  # Digbo Maiga → Habib Maïga
    "5708": 96850,  # Fernando Marçal → Marçal
    "5773": 97494,  # Zaydou Youssef → Zaydou Youssouf
    "5803": 97078,  # Fode Toure → Fodé Ballo-Touré
    "5977": 99039,  # Joia Nuno Da Costa → Nuno da Costa
    "5978": 99520,  # Dmitri Lienard → Dimitri Liénard
    "6120": 186591,  # Bono → Yassine Bounou
    "6307": 24342,  # Suk Hyun-Jun → Hyun-jun Suk
    "6381": 529419,  # Oriol Busquets → Uri Busquets
    "6407": 162518,  # Vágner → Vágner Dias
    "6443": 9636624,  # Ben Kone → Ben Lhassine Kone
    "6470": 189385,  # José Arnáiz → José Manuel Arnáiz
    "6533": 188340,  # Anthony Lozano → Choco Lozano
    "6557": 3861826,  # Louis Beyer → Jordan Beyer
    "6592": 448342,  # Manuel Morlanes → Manu Morlanes
    "6595": 42102,  # Paul Jäckel → Paul Jaeckel
    "6643": 8043762,  # Francisco Vieites → Fran Vieites
    "6740": 16476247,  # Miguel Ángel Rubio → Miguel Rubio
    "6918": 189956,  # Anuar Mohamed → Anuar
    "6955": 213486,  # Ezequiel Ávila → Chimy Ávila
    "7024": 189040,  # Kasim Nuhu → Kasim Adams
    "7251": 3510293,  # Robert → Rober González
    "7265": 4545404,  # Kephren Thuram → Khéphren Thuram
    "7316": 9302861,  # Charles Nathan Abi → Charles Abi
    "7387": 109355,  # Dimitris Nikolaou → Dimitrios Nikolaou
    "7413": 467567,  # Ibañez → Roger Ibañez
    "7430": 221615,  # Emerson → Emerson Royal
    "7470": 151562,  # Mathias Normann → M. Normann
    "7523": 539915,  # Javier Díaz → Javi Díaz
    "7722": 62879,  # Trézéguet → Mahmoud Trezeguet
    "7724": 62865,  # Wesley → Wesley Moraes
    "7743": 99117,  # Pereira Lage → Mathias Pereira Lage
    "7746": 320795,  # Hwang Ui-Jo → Ui-jo Hwang
    "7843": 186191,  # Lago Junior → Junior Wakalible Lago
    "7845": 155976,  # Aleksander Sedlar → Aleksandar Sedlar
    "7921": 160121,  # Felipe → Felipe Augusto de Almeida Monteiro
    "7981": 23269646,  # Nianzou Kouassi → Tanguy Nianzou
    "8140": 52792,  # Munas Dabbur → Moanes Dabour
    "8328": 21803033,  # Azz-Eddine Ounahi → Azzedine Ounahi
    "8410": 35281052,  # Rodrigo Sánchez → Rodri Sánchez
    "8413": 24468965,  # Javier López → Javi López
    "8433": 21413994,  # José Manuel Fontán → José Fontán
    "8461": 25568439,  # Nicolás Melamed → Nico Melamed
    "8499": 25568440,  # Daniel Villahermosa → Dani Villahermosa
    "8686": 12384553,  # Cheick Tidiane Sabaly → Cheikh Sabaly
    "8690": 432800,  # Jean-Phillipe Krasso → Jean-Philippe Krasso
    "8713": 37293367,  # Gabriel Veiga → Gabri Veiga
    "8731": 189238,  # Isaac Carcelén → Iza Carcelén
    "8735": 189262,  # Salvi Sánchez → Salvi
    "8795": 84191,  # Jacob Laursen → Jacob Barrett Laursen
    "8807": 14350739,  # Silas Wamangituka → Silas
    "8933": 447554,  # Marcos de Sousa → Marcos André
    "8934": 163190,  # Trincão → Francisco Trincão
    "8969": 163210,  # Florentino Luís → Florentino
    "9021": 37342694,  # Pape Sarr → Pape Matar Sarr
    "9170": 37549065,  # John Finn → John Patrick
    "9214": 37262613,  # Carlo Adriano García → Carlo Adriano García Prades
    "9226": 6013442,  # Mihai Valentin Mihaila → Valentin Mihăilă
    "9268": 37543845,  # Koffi → Amankwaa Akurugu Koffi
    "9317": 37541437,  # Oussama Targhaline → Oussama Targhalline
    "9345": 37541438,  # Ahmadou Bamba Dieng → Bamba Dieng
    "9409": 28912779,  # Kaine Hayden → Kaine Kesler-Hayden
    "9424": 37543908,  # Pablo Cuñat → Pablo Campos
    "9448": 37565513,  # Dion Moise Sahi → Moïse Sahi Dion
    "9496": 27796839,  # Alejandro Cantero → Álex Cantero
    "9669": 3872664,  # Thuler → Matheus Thuler
    "9697": 1846735,  # José Macías → J. Macías
    "9704": 107871,  # Vasilios Lampropoulos → Konstantinos-Vassilios Lambropoulos
    "9748": 84680,  # Jacob Sørensen → Jacob Lungi Sørensen
    "9759": 35281050,  # José Manuel Calderón → José Calderón
    "9769": 1477637,  # Barbero → Iván Barbero
    "9772": 37543903,  # Gori → Gori Gracia
    "9778": 218989,  # Henrique → Henrique Silva
    "9825": 37526514,  # Nicolás Serrano → Nico Serrano
    "9889": 15789914,  # Bjarki Steinn Bjarkason → Bjarki Bjarkason
    "9906": 134513,  # Antonio Vacca → Antonio Junior Vacca
    "9938": 447283,  # Jaume Grau → Jaume Grau Ciscar
    "10005": 24838234,  # Joshua Wilson-Esbrand → Josh Wilson-Esbrand
    "10104": 22158911,  # Adrián Butzke → Adrián Butzke Benavides
    "10151": 101108,  # Aboubacar Sidibe → Aboubakar Sidibe
    "10181": 23688806,  # Alex Tirlea → Alexandru Țîrlea
    "10188": 37316517,  # Peter → Peter Federico
    "10263": 37544887,  # Alaa Bellarouch → Alaa Bellaarouch
    "10327": 37404802,  # Chiquinho → Francisco Jorge Tavares Oliveira
    "10335": 37317013,  # Alasanne Sidibe → Alassane Sidibe
    "10343": 37541464,  # Antonio Iervolino → Antonio Pio Iervolino
    "10380": 37341868,  # Zito → Zito Luvumbo
    "10392": 206052,  # Vladyslav Supryaha → Vladyslav Supryaga
    "10393": 19625217,  # Emil Ceïde → Emil Konradsen Ceide
    "10399": 25548783,  # Juan Latasa → Juanmi Latasa
    "10590": 36872493,  # Marc Urena → Marc Tenas
    "10601": 37595890,  # Alejandro Primo → Álex Primo
    "10750": 84528,  # Rasmus Kristensen → Rasmus Nissen Kristensen
    "10766": 9826,  # Joe Ayodele-Aribo → Joe Aribo
    "10771": 37601342,  # Ben Seghir → Eliesse Ben Seghir
    "10797": 37560186,  # Kévin Biakolo → Kévin Keben
    "10830": 37612045,  # Jean Négoce → Jean-Mattéo Bahoya
    "10837": 19606965,  # Juan Perea → Juan José Perea
    "10844": 35271244,  # Darline Yongwa → Darlin Yongwa
    "10872": 32031212,  # Vinicius Souza → Vinicius de Souza Costa
    "10873": 4545390,  # Nabili Zoubdi Touaizi → Nabil Touaizi
    "10876": 37609566,  # Simo → Simo Keddari
    "10906": 531967,  # Thórir Helgason → Thórir Jóhann Helgason
    "10948": 524055,  # Valentín Castellanos → Taty Castellanos
    "10981": 37545267,  # Malcom Adu → Adu Ares
    "10982": 2823394,  # Copete → José Copete
    "10988": 37592616,  # Moi Parra → Moises Parra
    "11135": 37533201,  # Cheick Keita → Check Keita
    "11204": 37544113,  # Jon Magunacelaya → Jon Magunazelaia
    "11223": 37608473,  # Félix Garreta → Félix Martí
    "11232": 33991824,  # Thomas Cannon → Tom Cannon
    "11247": 29303727,  # Ruan → Ruan Potó
    "11249": 30875515,  # Ousmane Camara → Ousmane Camara
    "11292": 37592234,  # Lebas da Silva → Paolo Lebas
    "11320": 37573017,  # Mamadou Mbacke → Mamadou Fall
    "11387": 37681831,  # Cheick Konate → Cheick Oumar Konaté
    "11415": 37543482,  # Manuel Pozo → Manu Pozo
    "11482": 37690742,  # Alberto Basso → Alberto Basso Ricci
    "11537": 37325813,  # Santiago García → Santiago García González
    "11552": 37618899,  # Ben Touré → Ben Hamed Touré
    "11611": 37656778,  # Francisco González → Fran González
    "11617": 37316864,  # Yago Alonso → Yago Santiago
    "11629": 37656202,  # Abdellah Raihani → Abde Raihani
    "11634": 37632004,  # Daniel Rodríguez → Dani Rodríguez
    "11702": 62279,  # Benson Manuel → Manuel Benson
    "11715": 85277,  # Mads Andersen → Mads Juel Andersen
    "11737": 37676504,  # Silvi Clua → Selvi Clua
    "11761": 37249155,  # Javier Martón → Javi Martón
    "11796": 32819181,  # Étienne Youté → Étienne Youté Kinkoué
    "11817": 37400423,  # Emanuel Emegha → Emmanuel Emegha
    "11831": 37622274,  # Samu Omorodion → Samu Aghehowa
    "11901": 37653371,  # Tomasso Martinelli → Tommaso Martinelli
    "12040": 37539577,  # Thomas Thiesson Kristensen → Thomas Kristensen
    "12136": 37627277,  # Kim Ji-Soo → Ji-soo Kim
    "12197": 37602902,  # Rachad Dhimi → Rachad Fettal
    "12204": 37402363,  # Benicio Baker-Boaitey → Benicio Baker
    "12552": 37664729,  # Christ Mbondi → Christ Letono
    "12584": 37695654,  # Maat Caprini → Maat Daniel Caprini
    "12619": 37598782,  # Matteo Vinlöf → Matteo Pérez Vinlöf
    "12636": 37677266,  # Vignon Ouotro → Patrick Ouotro
    "12774": 378629,  # Andy Irving → Andrew Irving
    "12817": 37585293,  # Rodrigo Abajas → Ro Abajas
    "12962": 37729869,  # Ibrahim Kanté → Ibrahim Yayiya Kanté
    "13016": 14338068,  # Hong Hyun-Seok → Hyun-seok Hong
    "13043": 37715434,  # Mohamed Bamba → Mohamed Aboubakar Bamba
    "13126": 37736724,  # Niama Sissoko → Pape Sissoko
    "13152": 37671513,  # Kim Min-Su → Min-su Kim
    "13197": 37556995,  # Israel Domínguez → Isra Dominguez
    "13200": 37663391,  # Fernando López → Fer López
    "13201": 37596373,  # Raúl → Raúl Asencio
    "13210": 37729871,  # Mohamed Meïté → Kader Meïté
    "13241": 160068,  # Maurides → Maurides Roque Junior
    "13276": 37774860,  # Álvaro Pascual → García Pascual
    "13312": 37784340,  # Hafiz Ibrahim → Hafiz Umar Ibrahim
    "13328": 37616142,  # Bob Omoregbe → Bob Murphy Omoregbe
    "13368": 159380,  # Koka → Ahmed Hassan
    "13423": 164280,  # Al Musrati → Moatasem Al-Musrati
    "13466": 37723663,  # Chido Obi-Martin → Chido Obi
    "13525": 37733303,  # Wilfried Ndollo Bille → Wilfried Ndollo
    "13530": 37693996,  # Ange Tia → Ange Martial Tia
    "13558": 37687947,  # Daniel Díaz → Dani Díaz
    "13591": 37681302,  # Alejandro Rodríguez → Alejandro Gomes Rodríguez
    "13644": 37947786,  # Arturo Rodríguez → Arturo Rodríguez Cosano
    "13645": 37947785,  # José Carlos González → José Carlo González Sánchez
    "13787": 37296339,  # Manuel Fernández → Manu Fernández
    "13790": 37591342,  # Joselu Pérez → José Luis Pérez
    "13826": 37295947,  # Kwon Hyeok-Kyu → Hyeok-kyu Kwon
    "13874": 37769563,  # Owen Kouassi → Christ-Owen Kouassi
    "13905": 37627467,  # Mathys Silistre → Mathys Silistrie
    "13970": 38201810,  # Cheveyo Mul → Cheveyo Balentien
    "13997": 37618926,  # Hugo Lopez → Hugo Lopez
    "14013": 37717843,  # Adam El Mokhtari → Adam Boayar
    "14089": 37716393,  # Lancinet Kourouma → Lass Kourouma
    "14130": 37687230,  # David Santos → David Santos Daiber
    "14165": 37694941,  # Brad-Hamilton Mantsounga → Brad Hamilton Mantsounga Makouangou
    "14201": 38206798,  # Elias Legendre → Elías Legendre Quiñónez
    "14205": 37779255,  # Tomás Marqués → Tommy Marqués
    "14246": 37726288,  # Jorge Cestero → Jorge Cestero Sancho
    "14296": 37721978,  # Everton Pereira da Silva → Everton
    "14322": 37719239,  # Ibai Aguirre → Ibai Aguirre Basurco
    "14505": 38207306,  # Maycon Douglas Cardozo → Maycon Cardozo
    "14563": 38210682,  # Wedtoin Ouedraogo → Latif Ouedraogo
    "14576": 37784435,  # Ugo El Kadmiri → Ugo Lamare El Kadmiri
    "14578": 37657123,  # Hilan Slimani → Hilan Hamzaoui Slimani
    "14586": 38205195,  # Cubo → Miguel Cubo
    "14613": 38214394,  # Luis Orejuela → Luis Orejuela de la Rosa
    "14630": 37595820,  # Manuel Serrano → Manuel Serrano Salazar
    "473": 3282,  # Leicester의 Danny Ward는 같은 이름의 공격수 320이 아닌 골키퍼예요.
    "10888": 37554531,  # Valladolid의 David Torres Ortiz는 동명 후보 37631444와 구분해요.
    # 2026-09-09: 17/18~20/21의 표기 차이·동명 후보 179명을 같은 경기·팀의 명단 3,999건으로 대조했어요.
    # 전체 이름·별칭의 근거와 선수별 대조 경기는 UNDERSTAT_PLAYER_ID_REVIEW.md에 남겼어요.
    "24": 31039,  # Per Skjelbred → Per Ciljan Skjelbred
    "26": 72,  # Salomon Kalou → Salomon Armand Magloire Kalou
    "191": 736,  # Chicharito → Javier Hernández Balcázar
    "221": 29830,  # Rafinha → Márcio Rafael Ferreira de Souza
    "526": 316,  # Lee Chung-yong → Chung-Yong Lee
    "582": 1262,  # Jurado → José Manuel Jurado Marín
    "629": 579,  # Wayne Rooney → Wayne Mark Rooney
    "723": 813,  # Ki Sung-yueng → Sung-Yeung Ki
    "752": 921,  # Daniel Drinkwater → Danny Drinkwater
    "871": 1137,  # Bojan → Bojan Krkíc Pérez
    "1150": 128574,  # Emmanuel Badu → Emmanuel Agyemang-Badu
    "1339": 127841,  # Mariano Izco → Mariano Julio Izco
    "1399": 130031,  # Bruno Alves → Bruno Eduardo Regufe Alves
    "1438": 106963,  # Vasilis Torosidis → Vassilis Torosidis
    "1442": 1391,  # Saphir Taïder → Saphir Sliti Taïder
    "1685": 628,  # Ahmed Elmohamady → Ahmed Eissa El Mohamady Abdel Fattah
    "1884": 129060,  # Facundo Roncaglia → Facundo Sebastián Roncaglia
    "2003": 129865,  # Antonio La Gumina → Antonino La Gumina
    "2062": 169517,  # Nico Pareja → Nicolás Martín Pareja
    "2085": 186051,  # Lombán → David Rodríguez Lombán
    "2112": 185563,  # Papakouly Diop → Papa Kouly Diop
    "2132": 2817,  # Jota → José Ignacio Peleteiro Ramallo
    "2133": 185393,  # Adrián → Adrián González Morales
    "2147": 186892,  # Charly Musonda → Charly Musonda Junior
    "2157": 186345,  # Yoel → Yoel Rodríguez Oterino
    "2161": 186422,  # Nacho → José Ignacio Martínez García
    "2165": 6624,  # Jozabed → Jozabed Sánchez Ruiz
    "2188": 62906,  # Rubén Martínez → Rubén Iván Martínez Andrade
    "2191": 186430,  # Vigaray → Carlos Martín Vigaray
    "2218": 186715,  # Guerrero → Miguel Ángel Guerrero Martín
    "2230": 185656,  # David Zurutuza → David Zurutuza Veillet
    "2237": 186754,  # Héctor → Héctor Hernández Ortega
    "2240": 4111,  # Esteban Granero → Esteban Félix Granero Molina
    "2283": 186425,  # Planas → Carles Planas Antolínez
    "2294": 186731,  # Señé → Josep Señé Escudero
    "2300": 170673,  # Samu García → Samuel García Sánchez
    "2309": 186741,  # Nahuel → Matías Nahuel Leiva Esquivel
    "2318": 161314,  # Fede Cartabia → Federico Nicolás Cartabia
    "2339": 186657,  # Charles → Charles Días Barbosa de Oliveira
    "2350": 187975,  # Cifuentes → Miguel Ángel Garrido Cifuentes
    "2392": 185283,  # Gorka Iraizoz → Gorka Iraizoz Moreno
    "2393": 186213,  # Eneko Bóveda → Eneko Bóveda Altube
    "2394": 185892,  # Etxeita → Xabier Etxeita Gorritxategi
    "2395": 185498,  # San José → Mikel San José Domínguez
    "2404": 185671,  # Elustondo → Gorka Elustondo Urkola
    "2405": 185269,  # Markel Susaeta → Markel Susaeta Laskurain
    "2409": 186701,  # Eraso → Javier Eraso Goñi
    "2410": 184788,  # Aduriz → Aritz Aduriz Zubeldia
    "2419": 185976,  # Cabral → Gustavo Daniel Cabral Cáceres
    "2421": 96463,  # Doria → Matheus Dória Macedo
    "2444": 186732,  # Bruno → Bruno González Cabrera
    "2461": 185631,  # Aythami → Aythami Artiles Oliva
    "2465": 185984,  # Lillo → Manuel Castellano Castro
    "2491": 185855,  # Ibai Gómez → Ibai Gómez Pérez
    "2499": 186702,  # Sabin → Sabin Merino Zuloaga
    "2500": 159020,  # Luisinho → Luis Carlos Correia Pinto
    "2528": 186460,  # Ivi → Iván López Álvarez
    "2564": 186749,  # Uche → Uche Henry Agbo
    "2567": 186324,  # Luismi → Luis Miguel Sánchez Benítez
    "2572": 184918,  # Alexis → Alexis Ruano Delgado
    "2600": 185482,  # Fontàs → Andreu Fontàs Prat
    "2613": 186704,  # Aketxe → Ager Aketxe Barrutia
    "2925": 24011,  # Fedor Smolov → Fyodor Smolov
    "3228": 31574,  # Giovanni Sio → Giovanni-Guy Yann Sio
    "3262": 96633,  # Malcom → Malcom Filipe Silva de Oliveira
    "3337": 94274,  # Hilton → Vitorino Hilton da Silva
    "3397": 62419,  # Rolando → Rolando Jorge Pires da Fonseca
    "3469": 96173,  # Jonathan Pereira → Jonathan Martins-Pereira
    "3557": 571,  # Lass Diarra → Lassana Diarra
    "3712": 62896,  # Isaac Thelin → Isaac Kiese Thelin
    "3732": 96810,  # Denis Poha → Denis Will Poha
    "3747": 62733,  # Boschilia → Gabriel Boschilia
    "4119": 5217,  # Alberto Bueno → Alberto Bueno Calvo
    "4132": 185053,  # Borja → Borja Fernández Fernández
    "4208": 185452,  # Míchel → Miguel Alfonso Herrero Javaloyas
    "4219": 165598,  # Juan Carlos → Juan Carlos Real Ruiz
    "4374": 32264,  # Matti Steinmann → Matti Ville Steinmann
    "4441": 2237,  # Matthew James → Matty James
    "4799": 62819,  # Abdoulaye Diaby → Abdoulay Diaby
    "4904": 133990,  # Adrián Cubas → Adrián Andrés Cubas
    "5048": 186942,  # Daniel Torres → Daniel Alejandro Torres Rojas
    "5063": 186310,  # Saborit → Enric Saborit Teixidor
    "5071": 158926,  # Nicolás Gaitán → Osvaldo Nicolás Fabián Gaitán
    "5112": 77833,  # Toño Ramírez → Antonio Miguel Ramírez Martínez
    "5114": 185501,  # Raúl García → Raúl García Carnero
    "5120": 187030,  # Nano → Alexander Mesa Travieso
    "5148": 187252,  # Imanol Sarriegui → Imanol Sarriegi Isasa
    "5174": 186919,  # Caro → José Antonio Caro Díaz
    "5181": 185202,  # Omar Ramos → Julián Omar Ramos Suárez
    "5195": 188017,  # Nicolás Schiappacase → Nicolás Javier Schiappacasse Oliva
    "5203": 186950,  # Jon Serantes → Jon Ander Serantes Simon
    "5206": 455494,  # Alejandro Mula → Alejandro Miguel Mula Sanchez
    "5209": 64243,  # Naranjo → José Manuel García Naranjo
    "5317": 33930,  # Pal Dardai → Palko Dárdai
    "5625": 97746,  # Kwon Chang-Hoon → Chang-Hoon Kwon
    "5658": 96925,  # Mehdi Tahrat → Mehdi Jean Tahrat
    "5688": 68804,  # Rais M&#039;bolhi → Raïs M'Bolhi Ouhab
    "5760": 97935,  # Sami Benamar → Sami Ben Amar
    "5960": 6209,  # Prince → Prince-Désir Gouano
    "5964": 98481,  # Harrison Manzala → Harrisson Manzala
    "6004": 186765,  # Brandon → Brandon Thomas Llamas
    "6046": 2922,  # Bruno → Bruno Saltor Grau
    "6115": 188714,  # Aday Benítez → Francesc Aday Benítez Caraballo
    "6166": 449379,  # Francis → Francisco Javier Guerrero Martín
    "6201": 132129,  # Andrej Galabinov → Andrey Galabinov
    "6285": 537051,  # Lee Seung-Woo → Seung-Woo Lee
    "6295": 23159,  # Samuel Armenteros는 전체 이름·생년월일·경기 명단으로 확인했어요. DB 표시 이름 Dariusz Mrozek은 별도 정정 대상이에요.
    "6305": 432796,  # Ismail Aaneb → Ismael Aaneba
    "6343": 3156870,  # Barri → Diego Hernández Barriuso
    "6355": 4515,  # Kostas Mitroglou → Konstantinos Mitroglou
    "6371": 538509,  # Alejandro Robles → Alejandro Robles García
    "6395": 432698,  # Santy Ngom → Santy N' Gom
    "6404": 437088,  # Hacen → Moctar Sidi El Hacen El Ide
    "6426": 3684,  # Daniel Pacheco → Daniel Pacheco Lobato
    "6473": 462000,  # Merveille Ndockyt → Merveille Valthy Streeker Ndockyt
    "6487": 219286,  # John Mendoza → John Stiven Mendoza Valencia
    "6510": 43265,  # Chima Sean Okoroji → Chima Okoroji
    "6516": 164153,  # Everton Luiz → Everton Luiz Guimaraes Bilher
    "6537": 128893,  # Matías Aguirregaray → Matías Aguirregaray Guruceaga
    "6553": 525089,  # Yannis Ammour → Yanis Ammour
    "6657": 1494201,  # Lasse Sorenson → Lasse Sørensen
    "6669": 418401,  # Dennis Eckert → Dennis Yerai Eckert Ayensa
    "6673": 447181,  # Francesc Regis → Francesc Regis Crespí
    "6711": 3526253,  # Adrian Sahibeddine → Adrián Luciano Santos Sahibeddine
    "6716": 188746,  # Daniel Molina → Daniel Molina Orta
    "6760": 537196,  # José Lara → José Alonso Lara
    "6845": 432783,  # Percy Ruiz → Percy Prado Ruiz
    "6879": 6006245,  # Mohamed Lamine Diaby → Mohamed Lamine Diaby Fadiga
    "6897": 237377,  # Juan Ferney Otero → Juan Ferney Otero Tovar
    "6922": 188881,  # Antoñito → Antonio Jesús Regal Angulo
    "6925": 190428,  # Samuel Pérez → Samuel Pérez Fariña
    "6934": 448296,  # Álex López → Alejandro López Moreno
    "6939": 446926,  # Luca Sangalli → Luca Sangalli Fuentes
    "6952": 211989,  # Damián Musto → Damián Marcelo Musto
    "7022": 189729,  # Daniel Ojeda → Daniel Ojeda Saranova
    "7099": 448422,  # Paik Seung-Ho → Seung-Ho Paik
    "7126": 219262,  # Júnior Tavares → Carlos Eugenio Junior Tavares dos Santos
    "7132": 537201,  # Francisco Montero → Francisco Javier Montero Rubio
    "7145": 5417,  # Rui Fonte → Rui Pedro da Rocha Fonte
    "7165": 190567,  # Rodrigo Tarín → Rodrigo Tarín Higón
    "7173": 5682,  # Cristian → Cristian López Santamaría
    "7182": 186861,  # Moisés Delgado → Moisés Delgado López
    "7292": 432857,  # Thody Elie Youan → Elie Youan
    "7465": 66845,  # Elhadji Diaw → El Hadji Pape Djibril Diaw
    "7492": 188931,  # Xavier Quintillá → Xavier Quintillà Guasch
    "7557": 3533990,  # Yassin Benrahou → Yassine Benrahou
    "7697": 34706,  # Onel Hernández → Onel Lázaro Hernández Mayea
    "7784": 54164,  # Joao Victor → João Victor Santos Sa
    "7983": 581122,  # Daniel N&#039;Lundulu → Dan Nlundulu
    "8071": 160048,  # Jhonder Cádiz → Jhonder Leonel Cádiz Fernández
    "8098": 784362,  # Wesley Moustache → Wesley Moustache Mayeko
    "8111": 21054908,  # Lucas → Lucas Felippe Nascimento
    "8155": 31616426,  # Ahmad Toure Ngouyamsa Nounchili → Ahmad Toure Ngouyamsa Nounchil
    "8184": 189379,  # Eliseo → Eliseo Falcón Falcón
    "8209": 447514,  # Miguel Ángel Atienza → Miguel Ángel Atienza Villa
    "8266": 537125,  # Óscar Clemente → Óscar Clemente Mues
    "8276": 320190,  # Yun Il-Lok → Il-Lok Yun
    "8306": 113965,  # Sofian Chakla → Soufiane Chakla Mrioued
    "8414": 26689549,  # Mahmoud Abdallahi → Abdallahi Mahmoud
    "8479": 37526059,  # Andrea Ghezzi는 실제 Brescia 출전 5건의 ID예요. 명단에 없는 동명 ID 30105891은 쓰지 않아요.
    "8507": 33176415,  # Manuel Garrido → Manuel Garrido Alvarez
    "8531": 537631,  # Adrià Guerrero → Adrià Guerrero Aguilar
    "8658": 162868,  # Heriberto Tavares → Heriberto Moreno Borges Tavares
    "8708": 37308488,  # Unai Arietaleanizbeaskoa → Unai Arietaleanizbeaskoa Bergara
    "8723": 2823510,  # Ian Poveda-Ocampo → Ian Carlo Poveda-Ocampo
    "8739": 155712,  # Alberto Cifuentes → Alberto Cifuentes Martínez
    "8757": 3306,  # Romaine Sawyers → Romaine Theodore Sawyers
    "8815": 48532,  # Klauss → João Klauss De Mello
    "8901": 37380713,  # Jony Álamo → Jonatan Carmona Alamo
    "9009": 37306819,  # Luis Rojas → Luis Rojas Zamora
    "9032": 23278642,  # Tomás Tavares → Tomas Franco Tavares
    "9115": 22515418,  # Daniel Plomer → Daniel Plomer Gordillo
    "9144": 449596,  # Manuel Nieto → Manuel Nieto Sánchez
    "9161": 7346268,  # Jan-Luca Schuler → Luca Schuler
    "9200": 37551418,  # Philip Yeboah Ankrah → P. Ankhrah
    "9311": 539997,  # Thakgalo Leshabela → Thakgalo Khanya Leshabela
    "9443": 24817163,  # Vasilis Pavlidis → Vasíleios Pavlídis
    "9457": 446901,  # José Boacho → José Antonio Miranda Boacho
    "9568": 37325741,  # Charles Costes → Charles Elyan Costes
}


def _name_keys(observation: dict) -> set[str]:
    return {normalize_identity_text(observation[k]) for k in ("display_name", "full_name") if observation[k]}


def load_mapping_source(client: UnderstatClient, source: dict) -> tuple[dict, list[dict]]:
    matches, unavailable = select_understat_matches(source)
    players, player_teams = {}, defaultdict(set)
    # PSG–Rennes 오류가 시즌 선수 합계에도 섞여 있어요. 정상 경기 명단에서 ID·팀을 확인해요.
    # 선수 자체를 제외하지 않아, 다른 정상 경기 출전이나 이후 이적은 그대로 연결할 수 있어요.
    for match in matches:
        details = client.get_match(str(match["id"]))
        for side, roster in details["rosters"].items():
            title = source["teams"][str(match[side]["id"])]["title"]
            for player in roster.values():
                sid = str(player["player_id"])
                players[sid] = {"id": sid, "player_name": player["player"]}
                player_teams[sid].add(title)
    for sid, player in players.items():
        player["team_title"] = ",".join(sorted(player_teams[sid]))
    return {"teams": source["teams"], "dates": matches, "players": list(players.values())}, unavailable


def plan_team_ids(source: dict, observations: list[dict], existing: dict) -> tuple[dict, list]:
    db_names = defaultdict(set)
    for item in observations:
        db_names[item["team_id"]].update(_name_keys(item))
    source_ids = {unescape(team["title"]): str(tid) for tid, team in source["teams"].items()}
    source_names = {tid: set() for tid in source_ids.values()}
    for player in source["players"]:
        # 여러 경기에서 확인한 이적 선수의 팀은 '팀1,팀2'로 모여 있어요.
        for title in unescape(player["team_title"]).split(","):
            source_names[source_ids[title]].add(normalize_identity_text(unescape(player["player_name"])))
    # Capology와 같은 최소 3명·양방향 유일 최다 일치 규칙이에요.
    matches = reciprocal_identity_matches(db_names, source_names, 3)
    additions = {sid: did for did, (sid, _) in matches.items() if sid not in existing}
    evidence = [{"external_team_id": sid, "team_id": did, "exact_player_name_overlap": n}
                for did, (sid, n) in matches.items()]
    return additions, evidence


def plan_fixture_ids(source: dict, fixtures: list[dict], team_ids: dict, existing: dict) -> tuple[dict, list]:
    pairs = defaultdict(list)
    for fixture in fixtures:
        pairs[(fixture["home_team_id"], fixture["away_team_id"])].append(fixture)
    additions, pending = {}, []
    for match in source["dates"]:
        if not match["isResult"] or str(match["id"]) in existing:
            continue
        sid = str(match["id"])
        home = team_ids.get(str(match["h"]["id"]))
        away = team_ids.get(str(match["a"]["id"]))
        candidates = pairs[(home, away)]
        # 22/23 Serie A의 Spezia–Verona는 리그와 잔류 결정전이 모두 있어요.
        # 단일 맞대결은 변경된 일정에 영향받지 않고, 중복인 경우 날짜로 구분해요.
        if len(candidates) > 1:
            candidates = [f for f in candidates if str(f["starting_at"])[:10] == match["datetime"][:10]]
        if len(candidates) == 1:
            additions[sid] = candidates[0]["fixture_id"]
        else:
            pending.append({"external_fixture_id": sid, "home_team_id": home, "away_team_id": away,
                            "date": match["datetime"], "candidate_fixture_ids": [f["fixture_id"] for f in candidates]})
    return additions, pending


def plan_player_ids(source: dict, observations: list[dict], team_ids: dict, existing: dict) -> tuple[dict, list]:
    names = defaultdict(set)
    team_players = defaultdict(set)
    for item in observations:
        team_players[item["team_id"]].add(item["player_id"])
        for name in _name_keys(item):
            names[(item["team_id"], name)].add(item["player_id"])
    source_teams = {unescape(team["title"]): str(tid) for tid, team in source["teams"].items()}
    additions, pending = {}, []
    for player in source["players"]:
        sid = str(player["id"])
        if sid in existing:
            continue
        name = normalize_identity_text(unescape(player["player_name"]))
        candidates = set()
        verified_id = VERIFIED_UNDERSTAT_PLAYER_ID_OVERRIDES.get(sid)
        for title in unescape(player["team_title"]).split(","):
            team_id = team_ids.get(source_teams[title])
            if verified_id is not None:
                if verified_id in team_players[team_id]:
                    candidates.add(verified_id)
            else:
                candidates.update(names[(team_id, name)])
        # 확인된 ID 예외 외에는 같은 시즌·팀에서 이름이 유일하게 일치해야 해요.
        # Understat에는 생년월일이 없어요. 약칭·이름 유사도는 추정하지 않아요.
        if len(candidates) == 1:
            additions[sid] = candidates.pop()
        else:
            pending.append({"external_player_id": sid, "name": unescape(player["player_name"]),
                            "teams": unescape(player["team_title"]), "candidate_player_ids": sorted(candidates)})
    return additions, pending


# 두 원본 ID가 같은 선수임을 각각 같은 경기·팀의 DB 명단에서 확인했어요.
# 6명의 출전 53건을 대조했어요. 새로운 다중 ID는 별도로 확인해야 해요.
VERIFIED_UNDERSTAT_PLAYER_ALIASES = {
    37459033: {"11328", "11471"},  # Ángel Alarcón
    37590278: {"14378", "14432"},  # Ali Youssef / Ali Youssif
    37774860: {"13276", "13294"},  # Álvaro Pascual / García Pascual
    37721978: {"13265", "14296"},  # Everton / Everton Pereira da Silva
    # Marten Winkler: 20/21 경기 15432와 21/22 경기 17765의 Hertha 명단에서 같은 ID를 확인했어요.
    37266141: {"9528", "10511"},
    # Henning Matriciani: 20/21의 15433과 22/23 출전 22건이 모두 같은 Schalke 선수예요.
    25188222: {"9529", "9543"},
}


def _validate_mapping_uniqueness(entity: str, existing: dict, additions: dict) -> None:
    # 원본 ID를 하나로 바꾸지 않고 보존해요. 팀·경기는 기존 일대일 관계를 유지해요.
    validate_external_id_uniqueness(f"Understat {entity}", {**existing, **additions},
                                   VERIFIED_UNDERSTAT_PLAYER_ALIASES if entity == "player" else None)


def collect_understat_ids(season_name: str | None = None, competition_ids: list[int] | None = None,
                         *, check: bool = False) -> dict:
    scope = load_understat_scope(season_name, competition_ids)
    known = {kind: load_external_ids(kind) for kind in ("team", "fixture", "player")}
    client = UnderstatClient()
    reports = []
    try:
        for season in scope:
            source, unavailable = load_mapping_source(
                client, client.get_season(season["competition_id"], season["name"]),
            )
            observations = load_player_observations(season["season_id"])
            teams, evidence = plan_team_ids(source, observations, known["team"])
            team_map = {**known["team"], **teams}
            fixtures, pending_fixtures = plan_fixture_ids(
                source, load_mapping_fixtures(season["season_id"]), team_map, known["fixture"],
            )
            players, pending_players = plan_player_ids(source, observations, team_map, known["player"])
            planned = {"team": teams, "fixture": fixtures, "player": players}
            for entity, additions in planned.items():
                _validate_mapping_uniqueness(entity, known[entity], additions)
            pending_teams = [str(tid) for tid in source["teams"] if str(tid) not in team_map]
            report = {**season, "check": check, "new_mappings": planned,
                      "team_evidence": evidence, "pending_teams": pending_teams,
                      "pending_fixtures": pending_fixtures, "pending_players": pending_players,
                      "unavailable_fixtures": unavailable}
            # 미매핑 원본 ID도 남겨 공급자 전체를 기준으로 확인할 수 있게 해요.
            reports.append(report)
            path = write_understat_report("ids", report)
            if not check:
                with transaction() as connection:
                    with connection.cursor() as cursor:
                        for entity, additions in planned.items():
                            if additions:
                                cursor.executemany(f"""
                                    INSERT INTO {entity}_external_ids
                                    ({entity}_id, provider, external_{entity}_id) VALUES (%s,'understat',%s)
                                """, [(internal, external) for external, internal in additions.items()])
            for entity, additions in planned.items():
                known[entity].update(additions)
            print(f"[understat-ids] {season['name']} competition_id={season['competition_id']} "
                  f"teams={len(teams)} fixtures={len(fixtures)} players={len(players)} "
                  f"pending={len(pending_teams) + len(pending_fixtures) + len(pending_players)} "
                  f"unavailable={len(unavailable)} "
                  f"check={check} report={path}", flush=True)
    finally:
        client.close()
    # 앞 시즌의 미매핑 선수가 뒤 시즌에서 확인될 수 있어요. 최종 미해결 ID만 세요.
    remaining = {"teams": sorted({tid for r in reports for tid in r["pending_teams"]} - known["team"].keys())}
    for entity in ("fixture", "player"):
        remaining[entity + "s"] = list({
            row[f"external_{entity}_id"]: row for report in reports for row in report[f"pending_{entity}s"]
            if row[f"external_{entity}_id"] not in known[entity]
        }.values())
    result = {"seasons": len(reports), "pending": sum(map(len, remaining.values())),
              "unavailable": sum(len(r["unavailable_fixtures"]) for r in reports)}
    path = write_understat_report("ids_summary", {**result, "check": check, **remaining})
    print(f"[understat-ids] final_pending={result['pending']} report={path}", flush=True)
    return result
