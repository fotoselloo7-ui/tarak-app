/// Homepage copy shared with the web (`components/sections/homeCopy.ts`).
///
/// Site-config text always wins, except the previous stock wording: an
/// un-customised install still serves those strings, so they map to the
/// current copy without a backend or database change.
const Map<String, String> _homeCopyUpdates = {
  'Berber veya kuaför hizmetleri arasından ihtiyacını seç.': 'İhtiyacın olan hizmeti kolayca seç.',
  'Uygun tarih ve saati seç, adresini (güvenli şekilde) paylaş.': 'Sana uygun gün ve saati belirle.',
  'Sana en yakın, doğrulanmış uzman belirtilen saatte kapında olsun.': 'Onaylı hizmet veren adresine gelsin.',
  'Rahatına bak, profesyonel hizmetin keyfini çıkar. Sonrasında değerlendir.': 'Süreci takip et, hizmetini tamamla ve değerlendir.',
  'Resmi belgeler kontrol edilir.': 'Resmî mesleki belgeler kontrol edilir.',
  'Nüfus ve kimlik bilgileri teyit edilir.': 'Kimlik bilgileri güvenli şekilde doğrulanır.',
  'Başvuru, uzman ekibimiz tarafından manuel olarak incelenir.': 'Başvurular ekibimiz tarafından manuel olarak değerlendirilir.',
  'Sadece yetkin, belgeli ve deneyimli profesyoneller platformumuzda yer alır. Tüm hizmet verenlerimiz, ekibimiz tarafından titizlikle incelenir ve doğrulanır.':
      'Sadece yetkin, belgeli ve denetimli profesyoneller platformumuzda yer alır.',
  'Her Zaman Yanında': 'Tarak Mobil',
  'Dilediğin yerde, dilediğin zaman. iOS ve Android uygulamalarımızla hizmetlere daha hızlı ulaş.':
      'Hizmetleri keşfet, randevularını yönet, bildirimlerini takip et ve hizmet vereninle iletişimde kal.',
};

/// Site-config value (with the stock-copy refresh) or [fallback] when empty.
String homeCopy(Object? value, String fallback) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return _homeCopyUpdates[text] ?? text;
}

/// Turkish-aware upper case for short section labels (i -> İ, ı -> I).
String homeLabel(String value) => value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Benefits listed under "Tarak Cebinde!" on web and mobile.
const List<String> homeAppBenefits = [
  'Randevularını yönet',
  'Bildirimleri takip et',
  'Uzmanlarınla mesajlaş',
];
