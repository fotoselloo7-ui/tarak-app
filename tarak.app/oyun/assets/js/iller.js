/* Türkiye'nin 81 ili ve 973 ilçesi (oyunun rota haritası). DOM'suz; testlerde Node ile de çalışır.
 * [plaka, il, bölge, [ilçeler]] — bölge: M Marmara, E Ege, A Akdeniz, I İç Anadolu, K Karadeniz, D Doğu Anadolu, G Güneydoğu Anadolu */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.TarakIller = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  var ILLER = [
    [1, 'Adana', 'A', ['Seyhan', 'Aladağ', 'Ceyhan', 'Çukurova', 'Feke', 'İmamoğlu', 'Karaisalı', 'Karataş', 'Kozan', 'Pozantı', 'Saimbeyli', 'Sarıçam', 'Tufanbeyli', 'Yumurtalık', 'Yüreğir']],
    [2, 'Adıyaman', 'G', ['Merkez', 'Besni', 'Çelikhan', 'Gerger', 'Gölbaşı', 'Kahta', 'Samsat', 'Sincik', 'Tut']],
    [3, 'Afyonkarahisar', 'E', ['Merkez', 'Başmakçı', 'Bayat', 'Bolvadin', 'Çay', 'Çobanlar', 'Dazkırı', 'Dinar', 'Emirdağ', 'Evciler', 'Hocalar', 'İhsaniye', 'İscehisar', 'Kızılören', 'Sandıklı', 'Sinanpaşa', 'Sultandağı', 'Şuhut']],
    [4, 'Ağrı', 'D', ['Merkez', 'Diyadin', 'Doğubayazıt', 'Eleşkirt', 'Hamur', 'Patnos', 'Taşlıçay', 'Tutak']],
    [5, 'Amasya', 'K', ['Merkez', 'Göynücek', 'Gümüşhacıköy', 'Hamamözü', 'Merzifon', 'Suluova', 'Taşova']],
    [6, 'Ankara', 'I', ['Çankaya', 'Akyurt', 'Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana', 'Kahramankazan', 'Kalecik', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan', 'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle']],
    [7, 'Antalya', 'A', ['Muratpaşa', 'Akseki', 'Aksu', 'Alanya', 'Demre', 'Döşemealtı', 'Elmalı', 'Finike', 'Gazipaşa', 'Gündoğmuş', 'İbradı', 'Kaş', 'Kemer', 'Kepez', 'Konyaaltı', 'Korkuteli', 'Kumluca', 'Manavgat', 'Serik']],
    [8, 'Artvin', 'K', ['Merkez', 'Ardanuç', 'Arhavi', 'Borçka', 'Hopa', 'Kemalpaşa', 'Murgul', 'Şavşat', 'Yusufeli']],
    [9, 'Aydın', 'E', ['Efeler', 'Bozdoğan', 'Buharkent', 'Çine', 'Didim', 'Germencik', 'İncirliova', 'Karacasu', 'Karpuzlu', 'Koçarlı', 'Köşk', 'Kuşadası', 'Kuyucak', 'Nazilli', 'Söke', 'Sultanhisar', 'Yenipazar']],
    [10, 'Balıkesir', 'M', ['Karesi', 'Altıeylül', 'Ayvalık', 'Balya', 'Bandırma', 'Bigadiç', 'Burhaniye', 'Dursunbey', 'Edremit', 'Erdek', 'Gömeç', 'Gönen', 'Havran', 'İvrindi', 'Kepsut', 'Manyas', 'Marmara', 'Savaştepe', 'Sındırgı', 'Susurluk']],
    [11, 'Bilecik', 'M', ['Merkez', 'Bozüyük', 'Gölpazarı', 'İnhisar', 'Osmaneli', 'Pazaryeri', 'Söğüt', 'Yenipazar']],
    [12, 'Bingöl', 'D', ['Merkez', 'Adaklı', 'Genç', 'Karlıova', 'Kiğı', 'Solhan', 'Yayladere', 'Yedisu']],
    [13, 'Bitlis', 'D', ['Merkez', 'Adilcevaz', 'Ahlat', 'Güroymak', 'Hizan', 'Mutki', 'Tatvan']],
    [14, 'Bolu', 'K', ['Merkez', 'Dörtdivan', 'Gerede', 'Göynük', 'Kıbrıscık', 'Mengen', 'Mudurnu', 'Seben', 'Yeniçağa']],
    [15, 'Burdur', 'A', ['Merkez', 'Ağlasun', 'Altınyayla', 'Bucak', 'Çavdır', 'Çeltikçi', 'Gölhisar', 'Karamanlı', 'Kemer', 'Tefenni', 'Yeşilova']],
    [16, 'Bursa', 'M', ['Osmangazi', 'Büyükorhan', 'Gemlik', 'Gürsu', 'Harmancık', 'İnegöl', 'İznik', 'Karacabey', 'Keles', 'Kestel', 'Mudanya', 'Mustafakemalpaşa', 'Nilüfer', 'Orhaneli', 'Orhangazi', 'Yenişehir', 'Yıldırım']],
    [17, 'Çanakkale', 'M', ['Merkez', 'Ayvacık', 'Bayramiç', 'Biga', 'Bozcaada', 'Çan', 'Eceabat', 'Ezine', 'Gelibolu', 'Gökçeada', 'Lapseki', 'Yenice']],
    [18, 'Çankırı', 'I', ['Merkez', 'Atkaracalar', 'Bayramören', 'Çerkeş', 'Eldivan', 'Ilgaz', 'Kızılırmak', 'Korgun', 'Kurşunlu', 'Orta', 'Şabanözü', 'Yapraklı']],
    [19, 'Çorum', 'K', ['Merkez', 'Alaca', 'Bayat', 'Boğazkale', 'Dodurga', 'İskilip', 'Kargı', 'Laçin', 'Mecitözü', 'Oğuzlar', 'Ortaköy', 'Osmancık', 'Sungurlu', 'Uğurludağ']],
    [20, 'Denizli', 'E', ['Pamukkale', 'Acıpayam', 'Babadağ', 'Baklan', 'Bekilli', 'Beyağaç', 'Bozkurt', 'Buldan', 'Çal', 'Çameli', 'Çardak', 'Çivril', 'Güney', 'Honaz', 'Kale', 'Merkezefendi', 'Sarayköy', 'Serinhisar', 'Tavas']],
    [21, 'Diyarbakır', 'G', ['Sur', 'Bağlar', 'Bismil', 'Çermik', 'Çınar', 'Çüngüş', 'Dicle', 'Eğil', 'Ergani', 'Hani', 'Hazro', 'Kayapınar', 'Kocaköy', 'Kulp', 'Lice', 'Silvan', 'Yenişehir']],
    [22, 'Edirne', 'M', ['Merkez', 'Enez', 'Havsa', 'İpsala', 'Keşan', 'Lalapaşa', 'Meriç', 'Süloğlu', 'Uzunköprü']],
    [23, 'Elazığ', 'D', ['Merkez', 'Ağın', 'Alacakaya', 'Arıcak', 'Baskil', 'Karakoçan', 'Keban', 'Kovancılar', 'Maden', 'Palu', 'Sivrice']],
    [24, 'Erzincan', 'D', ['Merkez', 'Çayırlı', 'İliç', 'Kemah', 'Kemaliye', 'Otlukbeli', 'Refahiye', 'Tercan', 'Üzümlü']],
    [25, 'Erzurum', 'D', ['Yakutiye', 'Aşkale', 'Aziziye', 'Çat', 'Hınıs', 'Horasan', 'İspir', 'Karaçoban', 'Karayazı', 'Köprüköy', 'Narman', 'Oltu', 'Olur', 'Palandöken', 'Pasinler', 'Pazaryolu', 'Şenkaya', 'Tekman', 'Tortum', 'Uzundere']],
    [26, 'Eskişehir', 'I', ['Odunpazarı', 'Alpu', 'Beylikova', 'Çifteler', 'Günyüzü', 'Han', 'İnönü', 'Mahmudiye', 'Mihalgazi', 'Mihalıççık', 'Sarıcakaya', 'Seyitgazi', 'Sivrihisar', 'Tepebaşı']],
    [27, 'Gaziantep', 'G', ['Şahinbey', 'Araban', 'İslahiye', 'Karkamış', 'Nizip', 'Nurdağı', 'Oğuzeli', 'Şehitkamil', 'Yavuzeli']],
    [28, 'Giresun', 'K', ['Merkez', 'Alucra', 'Bulancak', 'Çamoluk', 'Çanakçı', 'Dereli', 'Doğankent', 'Espiye', 'Eynesil', 'Görele', 'Güce', 'Keşap', 'Piraziz', 'Şebinkarahisar', 'Tirebolu', 'Yağlıdere']],
    [29, 'Gümüşhane', 'K', ['Merkez', 'Kelkit', 'Köse', 'Kürtün', 'Şiran', 'Torul']],
    [30, 'Hakkari', 'D', ['Merkez', 'Çukurca', 'Derecik', 'Şemdinli', 'Yüksekova']],
    [31, 'Hatay', 'A', ['Antakya', 'Altınözü', 'Arsuz', 'Belen', 'Defne', 'Dörtyol', 'Erzin', 'Hassa', 'İskenderun', 'Kırıkhan', 'Kumlu', 'Payas', 'Reyhanlı', 'Samandağ', 'Yayladağı']],
    [32, 'Isparta', 'A', ['Merkez', 'Aksu', 'Atabey', 'Eğirdir', 'Gelendost', 'Gönen', 'Keçiborlu', 'Senirkent', 'Sütçüler', 'Şarkikaraağaç', 'Uluborlu', 'Yalvaç', 'Yenişarbademli']],
    [33, 'Mersin', 'A', ['Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Çamlıyayla', 'Erdemli', 'Gülnar', 'Mezitli', 'Mut', 'Silifke', 'Tarsus', 'Toroslar', 'Yenişehir']],
    [34, 'İstanbul', 'M', ['Beyoğlu', 'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer', 'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla', 'Ümraniye', 'Üsküdar', 'Zeytinburnu']],
    [35, 'İzmir', 'E', ['Konak', 'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova', 'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe', 'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar', 'Selçuk', 'Tire', 'Torbalı', 'Urla']],
    [36, 'Kars', 'D', ['Merkez', 'Akyaka', 'Arpaçay', 'Digor', 'Kağızman', 'Sarıkamış', 'Selim', 'Susuz']],
    [37, 'Kastamonu', 'K', ['Merkez', 'Abana', 'Ağlı', 'Araç', 'Azdavay', 'Bozkurt', 'Cide', 'Çatalzeytin', 'Daday', 'Devrekani', 'Doğanyurt', 'Hanönü', 'İhsangazi', 'İnebolu', 'Küre', 'Pınarbaşı', 'Seydiler', 'Şenpazar', 'Taşköprü', 'Tosya']],
    [38, 'Kayseri', 'I', ['Melikgazi', 'Akkışla', 'Bünyan', 'Develi', 'Felahiye', 'Hacılar', 'İncesu', 'Kocasinan', 'Özvatan', 'Pınarbaşı', 'Sarıoğlan', 'Sarız', 'Talas', 'Tomarza', 'Yahyalı', 'Yeşilhisar']],
    [39, 'Kırklareli', 'M', ['Merkez', 'Babaeski', 'Demirköy', 'Kofçaz', 'Lüleburgaz', 'Pehlivanköy', 'Pınarhisar', 'Vize']],
    [40, 'Kırşehir', 'I', ['Merkez', 'Akçakent', 'Akpınar', 'Boztepe', 'Çiçekdağı', 'Kaman', 'Mucur']],
    [41, 'Kocaeli', 'M', ['İzmit', 'Başiskele', 'Çayırova', 'Darıca', 'Derince', 'Dilovası', 'Gebze', 'Gölcük', 'Kandıra', 'Karamürsel', 'Kartepe', 'Körfez']],
    [42, 'Konya', 'I', ['Karatay', 'Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır', 'Cihanbeyli', 'Çeltik', 'Çumra', 'Derbent', 'Derebucak', 'Doğanhisar', 'Emirgazi', 'Ereğli', 'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük', 'Ilgın', 'Kadınhanı', 'Karapınar', 'Kulu', 'Meram', 'Sarayönü', 'Selçuklu', 'Seydişehir', 'Taşkent', 'Tuzlukçu', 'Yalıhüyük', 'Yunak']],
    [43, 'Kütahya', 'E', ['Merkez', 'Altıntaş', 'Aslanapa', 'Çavdarhisar', 'Domaniç', 'Dumlupınar', 'Emet', 'Gediz', 'Hisarcık', 'Pazarlar', 'Simav', 'Şaphane', 'Tavşanlı']],
    [44, 'Malatya', 'D', ['Battalgazi', 'Akçadağ', 'Arapgir', 'Arguvan', 'Darende', 'Doğanşehir', 'Doğanyol', 'Hekimhan', 'Kale', 'Kuluncak', 'Pütürge', 'Yazıhan', 'Yeşilyurt']],
    [45, 'Manisa', 'E', ['Şehzadeler', 'Ahmetli', 'Akhisar', 'Alaşehir', 'Demirci', 'Gölmarmara', 'Gördes', 'Kırkağaç', 'Köprübaşı', 'Kula', 'Salihli', 'Sarıgöl', 'Saruhanlı', 'Selendi', 'Soma', 'Turgutlu', 'Yunusemre']],
    [46, 'Kahramanmaraş', 'A', ['Onikişubat', 'Afşin', 'Andırın', 'Çağlayancerit', 'Dulkadiroğlu', 'Ekinözü', 'Elbistan', 'Göksun', 'Nurhak', 'Pazarcık', 'Türkoğlu']],
    [47, 'Mardin', 'G', ['Artuklu', 'Dargeçit', 'Derik', 'Kızıltepe', 'Mazıdağı', 'Midyat', 'Nusaybin', 'Ömerli', 'Savur', 'Yeşilli']],
    [48, 'Muğla', 'E', ['Menteşe', 'Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Kavaklıdere', 'Köyceğiz', 'Marmaris', 'Milas', 'Ortaca', 'Seydikemer', 'Ula', 'Yatağan']],
    [49, 'Muş', 'D', ['Merkez', 'Bulanık', 'Hasköy', 'Korkut', 'Malazgirt', 'Varto']],
    [50, 'Nevşehir', 'I', ['Merkez', 'Acıgöl', 'Avanos', 'Derinkuyu', 'Gülşehir', 'Hacıbektaş', 'Kozaklı', 'Ürgüp']],
    [51, 'Niğde', 'I', ['Merkez', 'Altunhisar', 'Bor', 'Çamardı', 'Çiftlik', 'Ulukışla']],
    [52, 'Ordu', 'K', ['Altınordu', 'Akkuş', 'Aybastı', 'Çamaş', 'Çatalpınar', 'Çaybaşı', 'Fatsa', 'Gölköy', 'Gülyalı', 'Gürgentepe', 'İkizce', 'Kabadüz', 'Kabataş', 'Korgan', 'Kumru', 'Mesudiye', 'Perşembe', 'Ulubey', 'Ünye']],
    [53, 'Rize', 'K', ['Merkez', 'Ardeşen', 'Çamlıhemşin', 'Çayeli', 'Derepazarı', 'Fındıklı', 'Güneysu', 'Hemşin', 'İkizdere', 'İyidere', 'Kalkandere', 'Pazar']],
    [54, 'Sakarya', 'M', ['Adapazarı', 'Akyazı', 'Arifiye', 'Erenler', 'Ferizli', 'Geyve', 'Hendek', 'Karapürçek', 'Karasu', 'Kaynarca', 'Kocaali', 'Pamukova', 'Sapanca', 'Serdivan', 'Söğütlü', 'Taraklı']],
    [55, 'Samsun', 'K', ['İlkadım', 'Alaçam', 'Asarcık', 'Atakum', 'Ayvacık', 'Bafra', 'Canik', 'Çarşamba', 'Havza', 'Kavak', 'Ladik', 'Ondokuzmayıs', 'Salıpazarı', 'Tekkeköy', 'Terme', 'Vezirköprü', 'Yakakent']],
    [56, 'Siirt', 'G', ['Merkez', 'Baykan', 'Eruh', 'Kurtalan', 'Pervari', 'Şirvan', 'Tillo']],
    [57, 'Sinop', 'K', ['Merkez', 'Ayancık', 'Boyabat', 'Dikmen', 'Durağan', 'Erfelek', 'Gerze', 'Saraydüzü', 'Türkeli']],
    [58, 'Sivas', 'I', ['Merkez', 'Akıncılar', 'Altınyayla', 'Divriği', 'Doğanşar', 'Gemerek', 'Gölova', 'Gürün', 'Hafik', 'İmranlı', 'Kangal', 'Koyulhisar', 'Suşehri', 'Şarkışla', 'Ulaş', 'Yıldızeli', 'Zara']],
    [59, 'Tekirdağ', 'M', ['Süleymanpaşa', 'Çerkezköy', 'Çorlu', 'Ergene', 'Hayrabolu', 'Kapaklı', 'Malkara', 'Marmaraereğlisi', 'Muratlı', 'Saray', 'Şarköy']],
    [60, 'Tokat', 'K', ['Merkez', 'Almus', 'Artova', 'Başçiftlik', 'Erbaa', 'Niksar', 'Pazar', 'Reşadiye', 'Sulusaray', 'Turhal', 'Yeşilyurt', 'Zile']],
    [61, 'Trabzon', 'K', ['Ortahisar', 'Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Çaykara', 'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Of', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir', 'Yomra']],
    [62, 'Tunceli', 'D', ['Merkez', 'Çemişgezek', 'Hozat', 'Mazgirt', 'Nazımiye', 'Ovacık', 'Pertek', 'Pülümür']],
    [63, 'Şanlıurfa', 'G', ['Eyyübiye', 'Akçakale', 'Birecik', 'Bozova', 'Ceylanpınar', 'Halfeti', 'Haliliye', 'Harran', 'Hilvan', 'Karaköprü', 'Siverek', 'Suruç', 'Viranşehir']],
    [64, 'Uşak', 'E', ['Merkez', 'Banaz', 'Eşme', 'Karahallı', 'Sivaslı', 'Ulubey']],
    [65, 'Van', 'D', ['İpekyolu', 'Bahçesaray', 'Başkale', 'Çaldıran', 'Çatak', 'Edremit', 'Erciş', 'Gevaş', 'Gürpınar', 'Muradiye', 'Özalp', 'Saray', 'Tuşba']],
    [66, 'Yozgat', 'I', ['Merkez', 'Akdağmadeni', 'Aydıncık', 'Boğazlıyan', 'Çandır', 'Çayıralan', 'Çekerek', 'Kadışehri', 'Saraykent', 'Sarıkaya', 'Sorgun', 'Şefaatli', 'Yenifakılı', 'Yerköy']],
    [67, 'Zonguldak', 'K', ['Merkez', 'Alaplı', 'Çaycuma', 'Devrek', 'Ereğli', 'Gökçebey', 'Kilimli', 'Kozlu']],
    [68, 'Aksaray', 'I', ['Merkez', 'Ağaçören', 'Eskil', 'Gülağaç', 'Güzelyurt', 'Ortaköy', 'Sarıyahşi', 'Sultanhanı']],
    [69, 'Bayburt', 'K', ['Merkez', 'Aydıntepe', 'Demirözü']],
    [70, 'Karaman', 'I', ['Merkez', 'Ayrancı', 'Başyayla', 'Ermenek', 'Kazımkarabekir', 'Sarıveliler']],
    [71, 'Kırıkkale', 'I', ['Merkez', 'Bahşılı', 'Balışeyh', 'Çelebi', 'Delice', 'Karakeçili', 'Keskin', 'Sulakyurt', 'Yahşihan']],
    [72, 'Batman', 'G', ['Merkez', 'Beşiri', 'Gercüş', 'Hasankeyf', 'Kozluk', 'Sason']],
    [73, 'Şırnak', 'G', ['Merkez', 'Beytüşşebap', 'Cizre', 'Güçlükonak', 'İdil', 'Silopi', 'Uludere']],
    [74, 'Bartın', 'K', ['Merkez', 'Amasra', 'Kurucaşile', 'Ulus']],
    [75, 'Ardahan', 'D', ['Merkez', 'Çıldır', 'Damal', 'Göle', 'Hanak', 'Posof']],
    [76, 'Iğdır', 'D', ['Merkez', 'Aralık', 'Karakoyunlu', 'Tuzluca']],
    [77, 'Yalova', 'M', ['Merkez', 'Altınova', 'Armutlu', 'Çınarcık', 'Çiftlikköy', 'Termal']],
    [78, 'Karabük', 'K', ['Merkez', 'Eflani', 'Eskipazar', 'Ovacık', 'Safranbolu', 'Yenice']],
    [79, 'Kilis', 'G', ['Merkez', 'Elbeyli', 'Musabeyli', 'Polateli']],
    [80, 'Osmaniye', 'A', ['Merkez', 'Bahçe', 'Düziçi', 'Hasanbeyli', 'Kadirli', 'Sumbas', 'Toprakkale']],
    [81, 'Düzce', 'K', ['Merkez', 'Akçakoca', 'Cumayeri', 'Çilimli', 'Gölyaka', 'Gümüşova', 'Kaynaşlı', 'Yığılca']]
  ];

  // Denize kıyısı olan ilçeler
  var KIYI = {
    1: ['Karataş', 'Yumurtalık'],
    7: ['Muratpaşa', 'Aksu', 'Alanya', 'Demre', 'Finike', 'Gazipaşa', 'Kaş', 'Kemer', 'Konyaaltı', 'Kumluca', 'Manavgat', 'Serik'],
    8: ['Arhavi', 'Hopa', 'Kemalpaşa'],
    9: ['Didim', 'Kuşadası', 'Söke'],
    10: ['Ayvalık', 'Bandırma', 'Burhaniye', 'Edremit', 'Erdek', 'Gömeç', 'Marmara'],
    16: ['Gemlik', 'Mudanya', 'Karacabey'],
    17: ['Merkez', 'Ayvacık', 'Biga', 'Bozcaada', 'Eceabat', 'Ezine', 'Gelibolu', 'Gökçeada', 'Lapseki'],
    22: ['Enez'],
    28: ['Merkez', 'Bulancak', 'Espiye', 'Eynesil', 'Görele', 'Keşap', 'Piraziz', 'Tirebolu'],
    31: ['Arsuz', 'Dörtyol', 'İskenderun', 'Payas', 'Samandağ'],
    33: ['Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Erdemli', 'Gülnar', 'Mezitli', 'Silifke', 'Tarsus', 'Yenişehir'],
    34: ['Beyoğlu', 'Adalar', 'Avcılar', 'Bakırköy', 'Beşiktaş', 'Beykoz', 'Beylikdüzü', 'Büyükçekmece', 'Fatih', 'Kadıköy', 'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sarıyer', 'Silivri', 'Şile', 'Tuzla', 'Üsküdar', 'Zeytinburnu'],
    35: ['Konak', 'Aliağa', 'Balçova', 'Bayraklı', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Güzelbahçe', 'Karaburun', 'Karşıyaka', 'Menderes', 'Menemen', 'Narlıdere', 'Seferihisar', 'Selçuk', 'Urla'],
    37: ['Abana', 'Bozkurt', 'Cide', 'Çatalzeytin', 'Doğanyurt', 'İnebolu'],
    39: ['Demirköy', 'Vize'],
    41: ['İzmit', 'Başiskele', 'Darıca', 'Derince', 'Dilovası', 'Gebze', 'Gölcük', 'Kandıra', 'Karamürsel', 'Körfez'],
    48: ['Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Marmaris', 'Milas', 'Ortaca', 'Seydikemer', 'Ula'],
    52: ['Altınordu', 'Fatsa', 'Gülyalı', 'Perşembe', 'Ünye'],
    53: ['Merkez', 'Ardeşen', 'Çayeli', 'Derepazarı', 'Fındıklı', 'İyidere', 'Pazar'],
    54: ['Karasu', 'Kocaali'],
    55: ['İlkadım', 'Alaçam', 'Atakum', 'Bafra', 'Canik', 'Çarşamba', 'Ondokuzmayıs', 'Tekkeköy', 'Terme', 'Yakakent'],
    57: ['Merkez', 'Ayancık', 'Gerze', 'Türkeli'],
    59: ['Süleymanpaşa', 'Marmaraereğlisi', 'Şarköy'],
    61: ['Ortahisar', 'Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Of', 'Sürmene', 'Vakfıkebir', 'Yomra'],
    67: ['Merkez', 'Alaplı', 'Ereğli', 'Kilimli', 'Kozlu'],
    74: ['Merkez', 'Amasra', 'Kurucaşile'],
    77: ['Merkez', 'Altınova', 'Armutlu', 'Çınarcık', 'Çiftlikköy'],
    81: ['Akçakoca']
  };
  // Göl kenarındaki ilçeler
  var GOL = { 65: ['İpekyolu', 'Edremit', 'Gevaş', 'Tuşba', 'Erciş'], 13: ['Ahlat', 'Tatvan', 'Adilcevaz'], 32: ['Eğirdir'], 15: ['Merkez'], 42: ['Beyşehir'],
    14: ['Merkez'], 54: ['Sapanca'], 41: ['Kartepe'], 16: ['İznik', 'Orhangazi'], 23: ['Sivrice'], 61: ['Çaykara'], 48: ['Köyceğiz'] };
  // Tramvayı olan ilçeler (nostaljik: İstiklal, Moda)
  var TRAMVAY = { 34: ['Beyoğlu', 'Kadıköy', 'Fatih', 'Zeytinburnu'], 35: ['Karşıyaka', 'Konak', 'Çiğli'], 26: ['Odunpazarı', 'Tepebaşı'], 7: ['Muratpaşa'],
    38: ['Melikgazi', 'Kocasinan', 'Talas'], 42: ['Selçuklu', 'Meram', 'Karatay'], 55: ['İlkadım', 'Atakum'], 27: ['Şahinbey', 'Şehitkamil'], 16: ['Osmangazi'], 41: ['İzmit'] };
  var NOSTALJIK = { 34: ['Beyoğlu', 'Kadıköy'] };
  // Ufuktaki simge: il geneli ya da ilçeye özel
  var SIMGE_IL = { 6: 'atakule', 35: 'saatkulesi', 16: 'ulucami', 42: 'mevlana', 7: 'yivliminare', 25: 'ciftminare', 63: 'balikligol', 47: 'mardin',
    50: 'balon', 27: 'kale', 36: 'kale', 17: 'kale', 22: 'cami', 26: 'cami', 61: 'cami', 21: 'kale', 65: 'kale', 44: 'cami', 38: 'cami' };
  var SIMGE_ILCE = { 'İstanbul/Beyoğlu': 'galata', 'İstanbul/Fatih': 'cami', 'İstanbul/Üsküdar': 'kizkulesi', 'İstanbul/Kadıköy': 'boga', 'İstanbul/Beşiktaş': 'kopru',
    'İstanbul/Sarıyer': 'kopru', 'İstanbul/Eyüpsultan': 'cami', 'İzmir/Çiğli': '', 'Trabzon/Çaykara': 'uzungol', 'Muğla/Bodrum': 'kale', 'İzmir/Çeşme': 'kale',
    'Antalya/Alanya': 'kale', 'Ankara/Altındağ': 'kale', 'Çanakkale/Gelibolu': 'kale', 'Edirne/Merkez': 'cami', 'Gaziantep/Şehitkamil': '' };
  var STIL_ILCE = { 'Eskişehir/Odunpazarı': 'cumbali', 'Karabük/Safranbolu': 'cumbali', 'Ankara/Beypazarı': 'cumbali', 'Muğla/Bodrum': 'beyaz', 'Muğla/Datça': 'beyaz',
    'İzmir/Çeşme': 'beyaz', 'İzmir/Urla': 'beyaz', 'Çanakkale/Bozcaada': 'beyaz', 'Muğla/Marmaris': 'beyaz' };
  // Tanınmış ilçelerde tabelada gerçek cadde adı
  var CADDE = { 'İstanbul/Beyoğlu': 'İSTİKLAL CADDESİ', 'İstanbul/Kadıköy': 'BAHARİYE CADDESİ', 'İstanbul/Şişli': 'ABDİ İPEKÇİ CADDESİ', 'İstanbul/Beşiktaş': 'BARBAROS BULVARI',
    'İstanbul/Fatih': 'DİVANYOLU CADDESİ', 'İstanbul/Üsküdar': 'PAŞALİMANI CADDESİ', 'İstanbul/Maltepe': 'BAĞDAT CADDESİ', 'İstanbul/Bakırköy': 'İSTANBUL CADDESİ',
    'Ankara/Çankaya': 'TUNALI HİLMİ CADDESİ', 'Ankara/Altındağ': 'ULUS MEYDANI', 'İzmir/Konak': 'ATATÜRK CADDESİ (KORDON)', 'İzmir/Karşıyaka': 'KEMALPAŞA CADDESİ',
    'Bursa/Osmangazi': 'ATATÜRK CADDESİ', 'Antalya/Muratpaşa': 'IŞIKLAR CADDESİ', 'Konya/Karatay': 'MEVLANA CADDESİ', 'Konya/Selçuklu': 'ALAADDİN BULVARI',
    'Eskişehir/Odunpazarı': 'ATATÜRK BULVARI', 'Şanlıurfa/Eyyübiye': 'BALIKLIGÖL CADDESİ', 'Mardin/Artuklu': 'CUMHURİYET CADDESİ', 'Erzurum/Yakutiye': 'CUMHURİYET CADDESİ',
    'Trabzon/Ortahisar': 'UZUN SOKAK', 'Gaziantep/Şahinbey': 'GAZİ MUHTAR PAŞA BULVARI', 'Kayseri/Melikgazi': 'SİVAS CADDESİ', 'Kocaeli/İzmit': 'HÜRRİYET CADDESİ',
    'Adana/Seyhan': 'ATATÜRK CADDESİ', 'Muğla/Bodrum': 'CUMHURİYET CADDESİ', 'Samsun/İlkadım': 'ÇİFTLİK CADDESİ', 'Diyarbakır/Sur': 'GAZİ CADDESİ', 'Edirne/Merkez': 'SARAÇLAR CADDESİ' };
  // Doğal yaşam parkı olan ilçeler (aslanlar burada)
  var ASLAN = { 'İzmir/Çiğli': true, 'Gaziantep/Şehitkamil': true, 'Ankara/Etimesgut': true, 'Bursa/Nilüfer': true };
  var BUYUK = { 34: 1.5, 6: 1.3, 35: 1.3, 16: 1.15, 7: 1.15, 1: 1.1, 41: 1.15, 42: 1.1, 27: 1.1, 21: 1.05, 55: 1.05, 38: 1.05, 33: 1.05 };

  function hash(s) { var h = 2166136261; for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function sec(h, liste) { return liste[h % liste.length]; }

  var BOLGE_AD = { M: 'Marmara', E: 'Ege', A: 'Akdeniz', I: 'İç Anadolu', K: 'Karadeniz', D: 'Doğu Anadolu', G: 'Güneydoğu Anadolu' };
  var HAVA = {
    M: ['acik', 'acik', 'acik', 'bulutlu', 'bulutlu', 'yagmur', 'sis', 'acik'],
    E: ['acik', 'acik', 'acik', 'acik', 'acik', 'bulutlu', 'yagmur', 'acik'],
    A: ['acik', 'acik', 'acik', 'acik', 'acik', 'acik', 'bulutlu', 'yagmur'],
    I: ['acik', 'acik', 'acik', 'bulutlu', 'kar', 'acik', 'sis', 'acik'],
    K: ['yagmur', 'sis', 'bulutlu', 'acik', 'yagmur', 'acik', 'bulutlu', 'sis'],
    D: ['kar', 'kar', 'acik', 'acik', 'bulutlu', 'kar', 'acik', 'sis'],
    G: ['acik', 'acik', 'acik', 'acik', 'sis', 'acik', 'bulutlu', 'acik']
  };
  var SAAT = ['oglen', 'oglen', 'oglen', 'sabah', 'sabah', 'aksam', 'aksam', 'gece'];
  // Kırsal ilçelerde doğa dünyası (bölgeye göre)
  var DOGA = { M: ['sehir', 'orman'], E: ['sehir', 'orman'], A: ['orman'], I: ['in'], K: ['orman'], D: ['orman'], G: ['in'] };
  var STIL = { M: 'tarihi', E: 'tarihi', A: 'tas', I: 'modern', K: 'tarihi', D: 'tas', G: 'tas' };

  function icerir(tablo, plaka, ilce) { return !!(tablo[plaka] && tablo[plaka].indexOf(ilce) >= 0); }

  /* Bütün ilçeler sırayla birer rota olur (plaka sırası, il merkezi önce). */
  var ROTALAR = [], IL_LISTE = [];
  ILLER.forEach(function (il) {
    var plaka = il[0], ad = il[1], b = il[2], ilk = ROTALAR.length;
    il[3].forEach(function (ilce, i) {
      var anahtar = ad + '/' + ilce, h = hash(anahtar), merkez = i === 0;
      var kiyi = icerir(KIYI, plaka, ilce), gol = icerir(GOL, plaka, ilce);
      var kirsal = !merkez && !kiyi && (h % 10) < (BUYUK[plaka] ? 3 : 5);
      var dunyalar = kirsal ? DOGA[b].slice() : ['sehir'];
      if (!merkez && !kirsal && h % 7 === 3) dunyalar.push('otoyol');
      var simge = SIMGE_ILCE.hasOwnProperty(anahtar) ? SIMGE_ILCE[anahtar] : (SIMGE_IL[plaka] || '');
      if (!simge && dunyalar[0] === 'sehir' && h % 3 === 0) simge = (h >>> 3) % 2 ? 'cami' : 'kale';
      var stil = STIL_ILCE[anahtar] || (kiyi && (b === 'E' || b === 'A') && h % 3 === 0 ? 'beyaz' : STIL[b]);
      if (b === 'I' && !BUYUK[plaka]) stil = 'tas';
      var hava = sec(h >>> 5, HAVA[b]);
      ROTALAR.push({
        ad: ilce === 'Merkez' ? ad + ' Merkez' : ilce, il: ad, ilce: ilce, plaka: plaka, bolge: b, sira: i,
        sehir: ad, semt: ilce, cadde: CADDE[anahtar] || ((ilce === 'Merkez' ? ad : ilce).toLocaleUpperCase('tr-TR') + (dunyalar[0] === 'sehir' ? ' CADDESİ' : ' YOLU')),
        dunyalar: dunyalar, saat: merkez ? 'oglen' : sec(h >>> 9, SAAT), hava: merkez && b !== 'D' && b !== 'K' ? 'acik' : hava,
        trafik: Math.round(((BUYUK[plaka] || 0.9) * (merkez ? 1.2 : 0.8 + (h % 5) * 0.12)) * 100) / 100,
        hiz: Math.round(Math.min(1.16, 0.95 + i * 0.012) * 1000) / 1000,
        simge: simge, stil: stil,
        deniz: kiyi ? ((h >>> 2) % 2 ? 'sol' : 'sag') : gol ? 'sag' : '',
        gol: gol, tramvay: icerir(TRAMVAY, plaka, ilce), nostaljik: icerir(NOSTALJIK, plaka, ilce),
        balon: plaka === 50, peri: plaka === 50, aslan: !!ASLAN[anahtar]
      });
    });
    IL_LISTE.push({ plaka: plaka, ad: ad, bolge: b, bolgeAd: BOLGE_AD[b], ilk: ilk + 1, son: ROTALAR.length, ilceSayisi: il[3].length });
  });

  return { ILLER: IL_LISTE, ROTALAR: ROTALAR, BOLGE_AD: BOLGE_AD, ilBul: function (plaka) { for (var i = 0; i < IL_LISTE.length; i++) if (IL_LISTE[i].plaka === plaka) return IL_LISTE[i]; return null; } };
});
