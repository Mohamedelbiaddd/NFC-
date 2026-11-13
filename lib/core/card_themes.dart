// GENERATED from web_profiles/themes.mjs — do not edit by hand.
// Loyalty card designs (same keys as the website and Google Wallet).
import 'package:flutter/material.dart';

class LoyaltyDesign {
  const LoyaltyDesign(this.key, this.names, this.a, this.b, this.gold, this.text, this.muted, this.ink, this.light, this.premium);
  final String key;
  final Map<String, String> names;
  final Color a, b, gold, text, muted, ink;
  final bool light, premium;
  String name(String lang) => names[lang] ?? names['en'] ?? key;
}

const cardThemes = <LoyaltyDesign>[
  LoyaltyDesign('navy', {'ar': 'كحلي وذهبي', 'fr': 'Marine et or', 'en': 'Navy & gold'}, Color(0xFF0F2346), Color(0xFF06112A), Color(0xFFF6C232), Color(0xFFFFFFFF), Color(0xFFA3B3D1), Color(0xFF1B1400), false, false),
  LoyaltyDesign('black', {'ar': 'أسود فاخر', 'fr': 'Noir luxe', 'en': 'Black luxury'}, Color(0xFF181818), Color(0xFF050505), Color(0xFFD4AF37), Color(0xFFF7F3EA), Color(0xFFA8A193), Color(0xFF1A1405), false, false),
  LoyaltyDesign('emerald', {'ar': 'زمردي', 'fr': 'Émeraude', 'en': 'Emerald'}, Color(0xFF0B2E22), Color(0xFF03140E), Color(0xFF34D399), Color(0xFFECFDF5), Color(0xFF9CC9B6), Color(0xFF032016), false, false),
  LoyaltyDesign('royal', {'ar': 'بنفسجي ملكي', 'fr': 'Violet royal', 'en': 'Royal purple'}, Color(0xFF211647), Color(0xFF0D0720), Color(0xFFC4B5FD), Color(0xFFF5F3FF), Color(0xFFB9B0DE), Color(0xFF1B0F3D), false, false),
  LoyaltyDesign('rose', {'ar': 'وردي أنيق', 'fr': 'Rose chic', 'en': 'Chic rose'}, Color(0xFF381226), Color(0xFF1A0711), Color(0xFFF9A8D4), Color(0xFFFFF1F7), Color(0xFFE0A9C2), Color(0xFF3B0A22), false, false),
  LoyaltyDesign('ocean', {'ar': 'أزرق المحيط', 'fr': 'Océan', 'en': 'Ocean'}, Color(0xFF0A2E46), Color(0xFF03131E), Color(0xFF38BDF8), Color(0xFFF0F9FF), Color(0xFF9CC3DC), Color(0xFF032033), false, false),
  LoyaltyDesign('sunset', {'ar': 'برتقالي الغروب', 'fr': 'Coucher de soleil', 'en': 'Sunset'}, Color(0xFF361A08), Color(0xFF170902), Color(0xFFFB923C), Color(0xFFFFF7ED), Color(0xFFE2B48D), Color(0xFF2A1102), false, false),
  LoyaltyDesign('crimson', {'ar': 'أحمر قرمزي', 'fr': 'Pourpre', 'en': 'Crimson'}, Color(0xFF2F0B16), Color(0xFF130409), Color(0xFFF43F5E), Color(0xFFFFF1F2), Color(0xFFE3A4AE), Color(0xFFFFFFFF), false, false),
  LoyaltyDesign('ivory', {'ar': 'عاجي فاتح', 'fr': 'Ivoire', 'en': 'Ivory light'}, Color(0xFFF8F4EC), Color(0xFFF3EEE4), Color(0xFFB8860B), Color(0xFF1F1A12), Color(0xFF71685A), Color(0xFFFFFFFF), true, false),
  LoyaltyDesign('mint', {'ar': 'نعناعي فاتح', 'fr': 'Menthe', 'en': 'Mint light'}, Color(0xFFF1F9F6), Color(0xFFECF6F2), Color(0xFF0F9F6E), Color(0xFF0E2A21), Color(0xFF557268), Color(0xFFFFFFFF), true, false),
  LoyaltyDesign('coffee', {'ar': 'قهوة: بني وذهبي', 'fr': 'Café : brun et or', 'en': 'Coffee: brown & gold'}, Color(0xFF2C1B10), Color(0xFF140C07), Color(0xFFD6A15A), Color(0xFFFBF3E6), Color(0xFFCDB59A), Color(0xFF1E1208), false, false),
  LoyaltyDesign('aqua', {'ar': 'غسيل: سماوي ومعدني', 'fr': 'Lavage : bleu ciel et acier', 'en': 'Wash: sky & steel'}, Color(0xFF1A2D3D), Color(0xFF0A1520), Color(0xFF4CC9F0), Color(0xFFF4F9FC), Color(0xFFA9BCCB), Color(0xFF04202C), false, false),
  LoyaltyDesign('pizza', {'ar': 'مطعم: أحمر وبرتقالي', 'fr': 'Pizzeria : rouge et orange', 'en': 'Pizzeria: red & orange'}, Color(0xFF241510), Color(0xFF0D0807), Color(0xFFFF7A2F), Color(0xFFFFF4EC), Color(0xFFE0B8A3), Color(0xFF2A0D02), false, false),
  LoyaltyDesign('neon', {'ar': 'رياضة: أسود ونيون', 'fr': 'Sport : noir et néon', 'en': 'Gym: black & neon'}, Color(0xFF171A17), Color(0xFF070807), Color(0xFFB6FF3B), Color(0xFFF4FFF0), Color(0xFFA7B8A2), Color(0xFF0D1A00), false, false),
  LoyaltyDesign('onyx', {'ar': 'أونيكس ملكي', 'fr': 'Onyx royal', 'en': 'Royal Onyx', 'it': 'Onice reale'}, Color(0xFF1B1B1C), Color(0xFF101114), Color(0xFFD7B77A), Color(0xFFFFFFFF), Color(0xFFAEAEAF), Color(0xFF111111), false, true),
  LoyaltyDesign('imperial', {'ar': 'ليل إمبراطوري', 'fr': 'Nuit impériale', 'en': 'Imperial Night', 'it': 'Notte imperiale'}, Color(0xFF1F192C), Color(0xFF151020), Color(0xFFF1C77E), Color(0xFFFFF5DC), Color(0xFFAFA79C), Color(0xFF111111), false, true),
  LoyaltyDesign('amber', {'ar': 'صالون كهرماني', 'fr': 'Salon ambre', 'en': 'Amber Lounge', 'it': 'Lounge ambra'}, Color(0xFF2F2215), Color(0xFF25190F), Color(0xFFDBA64D), Color(0xFFFFF3D7), Color(0xFFB5A993), Color(0xFF111111), false, true),
  LoyaltyDesign('espresso', {'ar': 'إسبريسو', 'fr': 'Espresso', 'en': 'Espresso House', 'it': 'Espresso'}, Color(0xFF342924), Color(0xFF2B211D), Color(0xFFD7A578), Color(0xFFFFF4E9), Color(0xFFB7ACA4), Color(0xFF111111), false, true),
  LoyaltyDesign('velvet', {'ar': 'مخملي عنابي', 'fr': 'Velours bordeaux', 'en': 'Velvet Burgundy', 'it': 'Velluto bordeaux'}, Color(0xFF4B182A), Color(0xFF3D1223), Color(0xFFE7B2AA), Color(0xFFFFF4ED), Color(0xFFBDA7A8), Color(0xFF111111), false, true),
  LoyaltyDesign('midnight', {'ar': 'أزرق منتصف الليل', 'fr': 'Bleu minuit', 'en': 'Midnight Blue', 'it': 'Blu notte'}, Color(0xFF132240), Color(0xFF0C1A36), Color(0xFFB9C9FF), Color(0xFFF6F8FF), Color(0xFFA6ADBB), Color(0xFF111111), false, true),
  LoyaltyDesign('drive', {'ar': 'أزرق السيارات', 'fr': 'Ocean Drive', 'en': 'Ocean Drive', 'it': 'Ocean Drive'}, Color(0xFF103A52), Color(0xFF092C45), Color(0xFF35B9E5), Color(0xFFF0FAFF), Color(0xFFA1B4C0), Color(0xFF111111), false, true),
  LoyaltyDesign('pulse', {'ar': 'نبض تقني', 'fr': 'Pulse tech', 'en': 'Future Pulse', 'it': 'Pulse tech'}, Color(0xFF132C31), Color(0xFF0E2026), Color(0xFF25E0BD), Color(0xFFE4FFFA), Color(0xFF9BB3B2), Color(0xFF111111), false, true),
  LoyaltyDesign('district', {'ar': 'نيون ليلي', 'fr': 'Néon urbain', 'en': 'Neon District', 'it': 'Neon urbano'}, Color(0xFF141527), Color(0xFF0B0C1B), Color(0xFFD4FF39), Color(0xFFF8FAFF), Color(0xFFA7A9B1), Color(0xFF111111), false, true),
  LoyaltyDesign('redline', {'ar': 'أحمر رياضي', 'fr': 'Rouge sport', 'en': 'Redline Sport', 'it': 'Rosso sport'}, Color(0xFF212429), Color(0xFF191C20), Color(0xFFF0524D), Color(0xFFFFFFFF), Color(0xFFB1B2B3), Color(0xFFFFFFFF), false, true),
  LoyaltyDesign('sahara', {'ar': 'تراث الصحراء', 'fr': 'Héritage Sahara', 'en': 'Sahara Heritage', 'it': 'Eredità Sahara'}, Color(0xFFF6EBD8), Color(0xFFF3E5CF), Color(0xFFA75B32), Color(0xFF4D3328), Color(0xFF725A4D), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('terra', {'ar': 'مخبزة طينية', 'fr': 'Terre boulangerie', 'en': 'Terra Bakery', 'it': 'Forno terracotta'}, Color(0xFFFCF3E2), Color(0xFFF9EBD5), Color(0xFFAD713F), Color(0xFF4A2F1B), Color(0xFF715844), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('atelier', {'ar': 'وردي أتولييه', 'fr': 'Atelier rose', 'en': 'Rose Atelier', 'it': 'Atelier rosa'}, Color(0xFFFFF6F9), Color(0xFFFFF1F5), Color(0xFFBE5684), Color(0xFF432B37), Color(0xFF6C5761), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('candy', {'ar': 'حلوى وردية', 'fr': 'Bonbon', 'en': 'Candy Pop', 'it': 'Caramella'}, Color(0xFFFFF8FD), Color(0xFFFFF0FA), Color(0xFFE95A9D), Color(0xFF662C51), Color(0xFF885776), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('coral', {'ar': 'نادي المرجان', 'fr': 'Club corail', 'en': 'Coral Club', 'it': 'Club corallo'}, Color(0xFFFFF8F4), Color(0xFFFFF0E7), Color(0xFFE0654E), Color(0xFF62372E), Color(0xFF856057), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('street', {'ar': 'شارع حضري', 'fr': 'Urbain', 'en': 'Urban Street', 'it': 'Urbano'}, Color(0xFFFBFAF5), Color(0xFFF7F3E9), Color(0xFFF04A22), Color(0xFF1C1B1A), Color(0xFF4C4B48), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('jade', {'ar': 'عيادة اليشم', 'fr': 'Jade clinique', 'en': 'Jade Clinic', 'it': 'Giada'}, Color(0xFFF4FAF8), Color(0xFFE7F4F0), Color(0xFF2B9A7B), Color(0xFF1B5347), Color(0xFF48766C), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('nordic', {'ar': 'هدوء شمالي', 'fr': 'Calme nordique', 'en': 'Nordic Calm', 'it': 'Calma nordica'}, Color(0xFFF1F5F1), Color(0xFFE9EEE9), Color(0xFF5D7A64), Color(0xFF34463A), Color(0xFF5C6B61), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('platinum', {'ar': 'بلاتيني', 'fr': 'Platine', 'en': 'Platinum Edge', 'it': 'Platino'}, Color(0xFFF4F6F7), Color(0xFFE7EAED), Color(0xFF5B6677), Color(0xFF26313B), Color(0xFF505A62), Color(0xFFFFFFFF), true, true),
  LoyaltyDesign('mono', {'ar': 'أبيض وأسود', 'fr': 'Monochrome', 'en': 'Monochrome', 'it': 'Monocromo'}, Color(0xFFFBFBFB), Color(0xFFF7F7F7), Color(0xFF111111), Color(0xFF111111), Color(0xFF444444), Color(0xFFFFFFFF), true, true),
];
