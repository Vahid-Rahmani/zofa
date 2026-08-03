/// A tiny, always-available starter word list used to suggest words for the
/// Leitner "word pool".
///
/// Kept deliberately small (a handful of common words per level) so the app
/// never depends on a large bundled corpus for suggestions: the words
/// themselves are just prompts — their translations are fetched live through
/// the [TranslationService] and cached.
library;

/// Curated starter words for the word pool, keyed by language code then CEFR
/// level. Languages without a list simply don't offer a pool.
const Map<String, Map<String, List<String>>> kStarterWords = {
  'en': {
    'A1': [
      'hello', 'goodbye', 'please', 'thank', 'water', 'bread', 'apple',
      'house', 'friend', 'family', 'mother', 'father', 'book', 'school',
      'teacher', 'morning', 'night', 'one', 'two', 'three',
    ],
    'A2': [
      'weather', 'travel', 'station', 'ticket', 'hotel', 'restaurant',
      'vegetable', 'kitchen', 'garden', 'street', 'market', 'cheap',
      'expensive', 'early', 'late', 'happy', 'sad', 'busy', 'free', 'tired',
    ],
    'B1': [
      'environment', 'education', 'government', 'health', 'disease',
      'relationship', 'discover', 'improve', 'succeed', 'advise', 'refuse',
      'arrange', 'compare', 'decide', 'depend', 'achieve', 'average',
      'confident', 'curious', 'proud',
    ],
    'B2': [
      'perspective', 'consequence', 'controversy', 'compromise', 'strategy',
      'assumption', 'significant', 'inevitable', 'ambiguous', 'coherent',
      'negotiate', 'contradict', 'acknowledge', 'demonstrate', 'undermine',
      'implement', 'restrict', 'specify', 'underestimate', 'overcome',
    ],
  },
  'de': {
    'A1': [
      'Hallo', 'Danke', 'Bitte', 'Wasser', 'Brot', 'Apfel', 'Haus', 'Freund',
      'Familie', 'Mutter', 'Vater', 'Buch', 'Schule', 'Lehrer', 'Morgen',
      'Nacht', 'eins', 'zwei', 'drei', 'Zeit',
    ],
    'A2': [
      'Wetter', 'Reise', 'Bahnhof', 'Fahrkarte', 'Hotel', 'Restaurant',
      'Gemüse', 'Küche', 'Garten', 'Straße', 'Markt', 'billig', 'teuer',
      'früh', 'spät', 'glücklich', 'traurig', 'beschäftigt', 'frei', 'müde',
    ],
    'B1': [
      'Umwelt', 'Bildung', 'Regierung', 'Gesundheit', 'Krankheit',
      'Beziehung', 'entdecken', 'verbessern', 'gelingen', 'beraten', 'weigern',
      'vereinbaren', 'vergleichen', 'entscheiden', 'abhängen', 'erreichen',
      'durchschnittlich', 'selbstbewusst', 'neugierig', 'stolz',
    ],
    'B2': [
      'Perspektive', 'Konsequenz', 'Kontroverse', 'Kompromiss', 'Strategie',
      'Annahme', 'bedeutend', 'unvermeidlich', 'mehrdeutig', 'kohärent',
      'verhandeln', 'widersprechen', 'anerkennen', 'demonstrieren', 'untergraben',
      'umsetzen', 'einschränken', 'präzisieren', 'unterschätzen', 'überwinden',
    ],
  },
  'es': {
    'A1': [
      'hola', 'adiós', 'por favor', 'gracias', 'agua', 'pan', 'manzana',
      'casa', 'amigo', 'familia', 'madre', 'padre', 'libro', 'escuela',
      'profesor', 'mañana', 'noche', 'uno', 'dos', 'tres',
    ],
    'A2': [
      'tiempo', 'viaje', 'estación', 'billete', 'hotel', 'restaurante',
      'verdura', 'cocina', 'jardín', 'calle', 'mercado', 'barato',
      'caro', 'temprano', 'tarde', 'feliz', 'triste', 'ocupado', 'libre',
      'cansado',
    ],
    'B1': [
      'medio ambiente', 'educación', 'gobierno', 'salud', 'enfermedad',
      'relación', 'descubrir', 'mejorar', 'tener éxito', 'aconsejar',
      'negarse', 'organizar', 'comparar', 'decidir', 'depender', 'lograr',
      'promedio', 'seguro', 'curioso', 'orgulloso',
    ],
    'B2': [
      'perspectiva', 'consecuencia', 'polémica', 'compromiso', 'estrategia',
      'supuesto', 'significativo', 'inevitable', 'ambiguo', 'coherente',
      'negociar', 'contradecir', 'reconocer', 'demostrar', 'socavar',
      'implementar', 'restringir', 'especificar', 'subestimar', 'superar',
    ],
  },
};

/// The CEFR levels that have starter words.
const List<String> kStarterLevels = ['A1', 'A2', 'B1', 'B2'];

/// Starter words for [languageCode] at [level], or an empty list.
List<String> starterWordsFor(String languageCode, String level) =>
    kStarterWords[languageCode]?[level] ?? const [];
