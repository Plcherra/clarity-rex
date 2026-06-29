/// Built-in category labels keyed by [normalized_name] from Supabase.
///
/// Canonical English names remain the DB identity; this map supplies UI labels.
const Map<String, Map<String, String>> kBuiltInCategoryDisplayLabels = {
  'coffee quick food': {
    'en': 'Coffee / Quick Food',
    'es': 'Café / Comida rápida',
  },
  'credit card payment': {
    'en': 'Credit Card Payment',
    'es': 'Pago de tarjeta',
  },
  'cash withdrawal': {
    'en': 'Cash Withdrawal',
    'es': 'Retiro de efectivo',
  },
  'food drink': {
    'en': 'Food & Drink',
    'es': 'Comida y bebida',
  },
  'grocery supermarket': {
    'en': 'Grocery / Supermarket',
    'es': 'Supermercado',
  },
  'housing': {
    'en': 'Housing',
    'es': 'Vivienda',
  },
  'income payroll': {
    'en': 'Income / Payroll',
    'es': 'Ingreso / Nómina',
  },
  'income zelle received': {
    'en': 'Income / Zelle Received',
    'es': 'Ingreso / Zelle recibido',
  },
  'pharmacy health': {
    'en': 'Pharmacy / Health',
    'es': 'Farmacia / Salud',
  },
  'shoes clothing': {
    'en': 'Shoes / Clothing',
    'es': 'Zapatos / Ropa',
  },
  'shopping': {
    'en': 'Shopping',
    'es': 'Compras',
  },
  'subscriptions': {
    'en': 'Subscriptions',
    'es': 'Suscripciones',
  },
  'transfer in': {
    'en': 'Transfer In',
    'es': 'Transferencia entrante',
  },
  'transfer out': {
    'en': 'Transfer Out',
    'es': 'Transferencia saliente',
  },
  'transportation': {
    'en': 'Transportation',
    'es': 'Transporte',
  },
  'unknown': {
    'en': 'Unknown',
    'es': 'Desconocido',
  },
  'ignored': {
    'en': 'Ignored',
    'es': 'Ignorado',
  },
  'miscellaneous': {
    'en': 'Miscellaneous',
    'es': 'Varios',
  },
  'software tools': {
    'en': 'Software / Tools',
    'es': 'Software / Herramientas',
  },
};

final class CategoryLabelResolver {
  const CategoryLabelResolver._();

  static String resolve({
    required String normalizedName,
    required String languageCode,
    String? fallbackName,
  }) {
    final key = normalizedName.trim().toLowerCase();
    final labels = kBuiltInCategoryDisplayLabels[key];
    if (labels != null) {
      return labels[languageCode] ?? labels['en'] ?? fallbackName ?? normalizedName;
    }
    return fallbackName ?? normalizedName;
  }

  static String resolveFromCanonicalName({
    required String canonicalName,
    required String languageCode,
  }) {
    final normalized = canonicalName.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ' ',
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return resolve(
      normalizedName: normalized,
      languageCode: languageCode,
      fallbackName: canonicalName,
    );
  }

  static Map<String, String> displayRenamesForLanguage(String languageCode) {
    final renames = <String, String>{};
    for (final entry in kBuiltInCategoryDisplayLabels.entries) {
      final english = entry.value['en'];
      final localized = entry.value[languageCode] ?? english;
      if (english == null || localized == null || english == localized) {
        continue;
      }
      renames[english.toLowerCase()] = localized;
    }
    return renames;
  }
}
