import 'package:flutter/material.dart';

import '../../core/theme/zova_colors.dart';
import '../../data/services/english_grammar.dart';

/// A learnable group of words inside one CEFR level.
///
/// A category is either a *theme* (a curated set of keywords such as Food &
/// Drinks or Travel) or a part-of-speech *fallback bucket* (Verbs, Nouns,
/// Adjectives, Adverbs, Other words) that catches every word no theme matches,
/// so the whole level is always partitioned.
class VocabularyCategory {
  const VocabularyCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.keywords = const {},
    this.fallback,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;

  /// Lowercase headwords that belong to this theme.
  final Set<String> keywords;

  /// When set, this category is the fallback bucket for that part-of-speech
  /// section (themes have a null fallback).
  final EnglishSection? fallback;

  /// Whether this category is a curated theme (as opposed to a POS bucket).
  bool get isTheme => fallback == null;

  /// Whether [word] (already lowercased) belongs to this theme.
  bool matches(String word) => keywords.contains(word);
}

/// Categories in priority order. A word is assigned to the first theme that
/// matches it, so each word belongs to exactly one category; the trailing
/// fallback buckets absorb everything else.
const List<VocabularyCategory> kVocabularyCategories = [
  _food,
  _travel,
  _family,
  _work,
  _school,
  _health,
  _nature,
  _home,
  _time,
  _feelings,
  VocabularyCategory(
    id: 'verbs',
    title: 'Verbs',
    icon: Icons.bolt,
    color: ZovaColors.primary,
    fallback: EnglishSection.verb,
  ),
  VocabularyCategory(
    id: 'nouns',
    title: 'Nouns',
    icon: Icons.category,
    color: Color(0xFF8D6E63),
    fallback: EnglishSection.noun,
  ),
  VocabularyCategory(
    id: 'adjectives',
    title: 'Adjectives',
    icon: Icons.palette,
    color: Color(0xFFAB47BC),
    fallback: EnglishSection.adjective,
  ),
  VocabularyCategory(
    id: 'adverbs',
    title: 'Adverbs',
    icon: Icons.speed,
    color: Color(0xFF00ACC1),
    fallback: EnglishSection.adverb,
  ),
  VocabularyCategory(
    id: 'other',
    title: 'Other words',
    icon: Icons.menu_book,
    color: ZovaColors.textSecondary,
    fallback: EnglishSection.other,
  ),
];

/// The category a word belongs to: the first theme whose keyword set matches
/// [word], otherwise the part-of-speech fallback bucket for [section].
VocabularyCategory categoryFor(String word, EnglishSection section) {
  final w = word.toLowerCase().trim();
  for (final category in kVocabularyCategories) {
    if (category.matches(w)) return category;
  }
  return kVocabularyCategories.firstWhere(
    (category) => category.fallback == section,
    orElse: () => kVocabularyCategories.last,
  );
}

const VocabularyCategory _food = VocabularyCategory(
  id: 'food',
  title: 'Food & Drinks',
  icon: Icons.restaurant,
  color: Color(0xFFFF7043),
  keywords: {
    'apple', 'bread', 'water', 'milk', 'meat', 'fish', 'egg', 'eggs',
    'cheese', 'butter', 'rice', 'fruit', 'juice', 'coffee', 'tea', 'wine',
    'beer', 'sugar', 'salt', 'pepper', 'soup', 'salad', 'pasta', 'pizza',
    'cake', 'chocolate', 'cookie', 'breakfast', 'lunch', 'dinner', 'meal',
    'food', 'drink', 'eat', 'cook', 'taste', 'delicious', 'hungry',
    'thirsty', 'kitchen', 'vegetable', 'vegetables', 'banana', 'orange',
    'potato', 'tomato', 'carrot', 'onion', 'lemon', 'bean', 'beans',
    'corn', 'chicken', 'beef', 'pork', 'ham', 'sandwich', 'snack',
    'restaurant', 'plate', 'cup', 'bowl', 'bottle', 'spoon', 'knife',
    'fork', 'fresh', 'sweet', 'sour', 'bake', 'boil', 'fry', 'menu',
    'grocery', 'fridge', 'ingredient', 'tasty', 'yummy', 'flavor',
    'break', 'sip', 'bite', 'cafe', 'cooker',
  },
);

const VocabularyCategory _travel = VocabularyCategory(
  id: 'travel',
  title: 'Travel & Places',
  icon: Icons.flight_takeoff,
  color: Color(0xFF42A5F5),
  keywords: {
    'travel', 'trip', 'journey', 'vacation', 'holiday', 'visit', 'tour',
    'tourist', 'guide', 'flight', 'plane', 'airport', 'train', 'station',
    'bus', 'car', 'taxi', 'ticket', 'hotel', 'map', 'road', 'street',
    'city', 'town', 'village', 'country', 'world', 'arrive', 'leave',
    'depart', 'passport', 'suitcase', 'luggage', 'destination', 'ride',
    'drive', 'passenger', 'abroad', 'downtown', 'highway', 'subway',
    'tram', 'border', 'coast', 'beach', 'island', 'port', 'bridge',
    'traveler', 'traveller', 'booking', 'reservation', 'sight', 'view',
    'scenery', 'traffic', 'direction', 'route', 'rental', 'wheel',
    'pedestrian', 'stop', 'platform', 'schedule', 'departure', 'arrival',
  },
);

const VocabularyCategory _family = VocabularyCategory(
  id: 'family',
  title: 'Family & People',
  icon: Icons.family_restroom,
  color: Color(0xFFEC407A),
  keywords: {
    'family', 'father', 'mother', 'parent', 'parents', 'brother',
    'sister', 'son', 'daughter', 'grandmother', 'grandfather',
    'grandparent', 'uncle', 'aunt', 'cousin', 'nephew', 'niece',
    'husband', 'wife', 'child', 'children', 'baby', 'boy', 'girl',
    'kid', 'man', 'woman', 'person', 'people', 'friend', 'friends',
    'neighbor', 'neighbour', 'relative', 'marry', 'married', 'marriage',
    'wedding', 'guest', 'name', 'birth', 'born', 'teenager', 'adult',
    'gentleman', 'lady', 'couple', 'grandson', 'granddaughter', 'guy',
    'team', 'member', 'community', 'crowd', 'stranger', 'owner',
  },
);

const VocabularyCategory _work = VocabularyCategory(
  id: 'work',
  title: 'Work & Business',
  icon: Icons.work,
  color: Color(0xFF7E57C2),
  keywords: {
    'work', 'job', 'office', 'boss', 'manager', 'employee', 'employer',
    'colleague', 'worker', 'staff', 'business', 'company', 'market',
    'shop', 'store', 'money', 'salary', 'wage', 'income', 'pay', 'earn',
    'sell', 'buy', 'purchase', 'trade', 'product', 'customer', 'client',
    'contract', 'meeting', 'project', 'deadline', 'career', 'profession',
    'factory', 'industry', 'hire', 'fire', 'quit', 'retire', 'interview',
    'resume', 'invoice', 'budget', 'profit', 'loss', 'invest', 'bank',
    'loan', 'debt', 'finance', 'economy', 'deliver', 'supply', 'order',
    'service', 'employ', 'retirement', 'achievement', 'success',
    'successful', 'fail', 'failure', 'task', 'duty', 'responsibility',
    'skill', 'experience', 'training', 'apply', 'applicant', 'promotion',
  },
);

const VocabularyCategory _school = VocabularyCategory(
  id: 'school',
  title: 'School & Learning',
  icon: Icons.school,
  color: Color(0xFFFFB300),
  keywords: {
    'school', 'teacher', 'student', 'pupil', 'learn', 'study', 'teach',
    'read', 'write', 'lesson', 'course', 'class', 'classroom', 'homework',
    'exam', 'test', 'quiz', 'question', 'answer', 'book', 'pen', 'pencil',
    'notebook', 'paper', 'word', 'language', 'subject', 'math', 'science',
    'history', 'university', 'college', 'degree', 'education', 'knowledge',
    'dictionary', 'essay', 'grammar', 'vocabulary', 'spell', 'letter',
    'page', 'library', 'semester', 'grade', 'score', 'correct', 'mistake',
    'error', 'understand', 'explain', 'remember', 'forget', 'listen',
    'speak', 'practice', 'practise', 'review', 'repeat', 'pronounce',
    'pronunciation', 'translate', 'translation', 'meaning', 'example',
    'exercise', 'professor', 'lecture', 'graduate', 'scholar', 'reading',
  },
);

const VocabularyCategory _health = VocabularyCategory(
  id: 'health',
  title: 'Health & Body',
  icon: Icons.favorite,
  color: Color(0xFFEF5350),
  keywords: {
    'health', 'healthy', 'sick', 'ill', 'pain', 'hurt', 'ache', 'doctor',
    'nurse', 'patient', 'hospital', 'medicine', 'pill', 'tooth', 'teeth',
    'dentist', 'eye', 'eyes', 'ear', 'nose', 'mouth', 'head', 'hair',
    'face', 'hand', 'arm', 'leg', 'foot', 'feet', 'finger', 'body',
    'heart', 'bone', 'blood', 'skin', 'cold', 'fever', 'cough', 'rest',
    'exercise', 'strong', 'weak', 'disease', 'cure', 'treatment', 'injure',
    'injury', 'breathe', 'breath', 'wound', 'swallow', 'hunger',
    'thirst', 'weight', 'tall', 'short', 'fat', 'thin', 'sleep', 'tired',
    'energy', 'active', 'sleepy', 'sweat', 'shower', 'wash', 'clean',
    'stomach', 'back', 'neck', 'shoulder', 'knee', 'ankle', 'wrist',
    'elbow', 'lung', 'brain', 'muscle', 'nervous', 'heal', 'recover',
  },
);

const VocabularyCategory _nature = VocabularyCategory(
  id: 'nature',
  title: 'Nature & Weather',
  icon: Icons.park,
  color: Color(0xFF66BB6A),
  keywords: {
    'nature', 'weather', 'sun', 'rain', 'snow', 'wind', 'cloud', 'sky',
    'storm', 'thunder', 'lightning', 'tree', 'trees', 'forest', 'wood',
    'flower', 'grass', 'plant', 'leaf', 'leaves', 'garden', 'mountain',
    'hill', 'river', 'lake', 'sea', 'ocean', 'sand', 'rock', 'stone',
    'earth', 'soil', 'air', 'bird', 'birds', 'animal', 'animals', 'dog',
    'cat', 'horse', 'cow', 'pig', 'sheep', 'mouse', 'insect', 'eagle',
    'hot', 'cold', 'warm', 'cool', 'green', 'cloudy', 'sunny', 'rainy',
    'snowy', 'windy', 'fog', 'mist', 'wave', 'shore', 'cave', 'valley',
    'field', 'planet', 'star', 'moon', 'sunlight', 'shade', 'dry', 'wet',
    'golden', 'beautiful', 'wild', 'grow', 'bloom', 'seed', 'root',
  },
);

const VocabularyCategory _home = VocabularyCategory(
  id: 'home',
  title: 'Home & Routines',
  icon: Icons.home,
  color: Color(0xFF26A69A),
  keywords: {
    'home', 'house', 'room', 'bedroom', 'bathroom', 'dining', 'door',
    'window', 'floor', 'wall', 'roof', 'yard', 'bed', 'sofa', 'chair',
    'table', 'desk', 'lamp', 'light', 'mirror', 'bath', 'towel', 'soap',
    'toilet', 'carpet', 'curtain', 'furniture', 'clean', 'dirty', 'tidy',
    'key', 'lock', 'garage', 'apartment', 'neighborhood', 'neighbourhood',
    'kitchen', 'cook', 'sink', 'oven', 'dish', 'dishes', 'wash',
    'sweep', 'water', 'garden', 'porch', 'stair', 'stairs', 'balcony',
    'address', 'building', 'corner', 'hall', 'basement', 'laundry',
    'broom', 'bucket', 'plug', 'switch', 'wire', 'tool', 'hammer',
    'paint', 'rent', 'move', 'settle', 'dwell', 'residence', 'landlord',
  },
);

const VocabularyCategory _time = VocabularyCategory(
  id: 'time',
  title: 'Time & Numbers',
  icon: Icons.schedule,
  color: Color(0xFF29B6F6),
  keywords: {
    'time', 'day', 'week', 'month', 'year', 'hour', 'minute', 'second',
    'moment', 'morning', 'afternoon', 'evening', 'night', 'today',
    'tomorrow', 'yesterday', 'tonight', 'soon', 'early', 'late', 'now',
    'clock', 'date', 'calendar', 'birthday', 'century', 'weekend',
    'number', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
    'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
    'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
    'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
    'hundred', 'thousand', 'million', 'zero', 'first', 'third',
    'last', 'next', 'double', 'half', 'quarter', 'count', 'order',
    'during', 'until', 'past', 'future', 'present', 'age', 'old', 'young',
    'spring', 'summer', 'autumn', 'winter', 'instant', 'occasion',
  },
);

const VocabularyCategory _feelings = VocabularyCategory(
  id: 'feelings',
  title: 'Feelings & Emotions',
  icon: Icons.emoji_emotions,
  color: Color(0xFFFFA726),
  keywords: {
    'happy', 'sad', 'angry', 'mad', 'afraid', 'scared', 'fear', 'love',
    'like', 'hate', 'dislike', 'excited', 'excitement', 'nervous', 'calm',
    'quiet', 'bored', 'boring', 'surprised', 'surprise', 'proud', 'shy',
    'lonely', 'worry', 'worried', 'hope', 'dream', 'smile', 'laugh',
    'cry', 'joy', 'kind', 'nice', 'mean', 'generous', 'jealous', 'ashamed',
    'confused', 'confuse', 'relax', 'relaxed', 'fun', 'enjoy', 'favorite',
    'favourite', 'glad', 'grateful', 'thankful', 'upset', 'sorrow',
    'anger', 'rage', 'anxious', 'anxiety', 'comfort', 'comfortable',
    'uncomfortable', 'satisfied', 'content', 'eager', 'curious',
    'peaceful', 'friendly', 'careful', 'careless', 'brave', 'courage',
    'sincere', 'honest', 'polite', 'rude', 'selfish', 'gentle', 'sweet',
    'silly', 'cheerful', 'mood', 'feeling', 'emotion', 'agree', 'disagree',
  },
);
