import 'package:flutter/material.dart';

import '../../core/theme/zova_colors.dart';
import '../../core/widgets/tr_text.dart';

/// One letter of the English alphabet with its name, IPA and a model word.
class _LetterData {
  const _LetterData(this.letter, this.name, this.ipa, this.example, this.meaning);

  final String letter;
  final String name;
  final String ipa;
  final String example;
  final String meaning;
}

/// A pronunciation tip written for Persian speakers.
class _PronunciationTip {
  const _PronunciationTip(this.sound, this.tip, this.example);

  final String sound;
  final String tip;
  final String example;
}

const List<_LetterData> _letters = [
  _LetterData('A', 'a', '/eɪ/', 'apple', 'سیب'),
  _LetterData('B', 'b', '/biː/', 'book', 'کتاب'),
  _LetterData('C', 'c', '/siː/', 'cat', 'گربه'),
  _LetterData('D', 'd', '/diː/', 'dog', 'سگ'),
  _LetterData('E', 'e', '/iː/', 'egg', 'تخم‌مرغ'),
  _LetterData('F', 'f', '/ɛf/', 'fish', 'ماهی'),
  _LetterData('G', 'g', '/dʒiː/', 'girl', 'دختر'),
  _LetterData('H', 'h', '/eɪtʃ/', 'house', 'خانه'),
  _LetterData('I', 'i', '/aɪ/', 'ice', 'یخ'),
  _LetterData('J', 'j', '/dʒeɪ/', 'juice', 'آب‌میوه'),
  _LetterData('K', 'k', '/keɪ/', 'key', 'کلید'),
  _LetterData('L', 'l', '/ɛl/', 'lion', 'شیر'),
  _LetterData('M', 'm', '/ɛm/', 'mother', 'مادر'),
  _LetterData('N', 'n', '/ɛn/', 'night', 'شب'),
  _LetterData('O', 'o', '/oʊ/', 'orange', 'پرتقال'),
  _LetterData('P', 'p', '/piː/', 'pen', 'خودکار'),
  _LetterData('Q', 'q', '/kjuː/', 'question', 'سؤال'),
  _LetterData('R', 'r', '/ɑːr/', 'rain', 'باران'),
  _LetterData('S', 's', '/ɛs/', 'sun', 'خورشید'),
  _LetterData('T', 't', '/tiː/', 'table', 'میز'),
  _LetterData('U', 'u', '/juː/', 'umbrella', 'چتر'),
  _LetterData('V', 'v', '/viː/', 'video', 'ویدئو'),
  _LetterData('W', 'w', '/ˈdʌbəljuː/', 'water', 'آب'),
  _LetterData('X', 'x', '/ɛks/', 'box', 'جعبه'),
  _LetterData('Y', 'y', '/waɪ/', 'yellow', 'زرد'),
  _LetterData('Z', 'z', '/ziː/', 'zebra', 'گورخر'),
];

const List<_PronunciationTip> _tips = [
  _PronunciationTip(
    '/θ/',
    'Put your tongue lightly between your teeth and blow air out.',
    'think, three, thank',
  ),
  _PronunciationTip(
    '/ð/',
    'Same position as /θ/ but with your voice turned on.',
    'this, that, mother',
  ),
  _PronunciationTip(
    '/w/',
    'Round your lips and glide, without touching your lower lip with your teeth.',
    'water, well, why',
  ),
  _PronunciationTip(
    '/r/',
    'Curl the tip of your tongue back — do not trill it.',
    'red, rain, very',
  ),
  _PronunciationTip(
    '/æ/',
    'A wide, short "a" — open your mouth more than in Persian.',
    'cat, apple, man',
  ),
  _PronunciationTip(
    '/ə/',
    'The lazy "schwa": the shortest, most relaxed sound in English.',
    'about, banana, computer',
  ),
];

/// Alphabet & Pronunciation: the 26 letters plus tips for sounds Persian
/// learners find tricky.
class AlphabetScreen extends StatelessWidget {
  const AlphabetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const TrText('Alphabet & Pronunciation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const TrText(
              'Learn the English alphabet',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const TrText(
              'Tap a letter to hear how it is written and see a model word.',
              style: TextStyle(color: ZovaColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: _letters.length,
              itemBuilder: (context, index) {
                final letter = _letters[index];
                return _LetterTile(
                  letter: letter,
                  onTap: () => _showLetter(context, letter),
                );
              },
            ),
            const SizedBox(height: 28),
            const TrText(
              'Sounds to master',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const TrText(
              'English sounds that Persian speakers often mix up.',
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final tip in _tips) ...[
              _TipCard(tip: tip),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  void _showLetter(BuildContext context, _LetterData letter) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZovaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ZovaColors.gradientStart, ZovaColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    letter.letter,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letter.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.trTempl('letter name · {0}', [letter.ipa]),
                        style: const TextStyle(
                          fontSize: 15,
                          color: ZovaColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const TrText(
              'Example',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ZovaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZovaColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    letter.example,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ZovaColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    letter.meaning,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 17,
                      color: ZovaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.onTap});

  final _LetterData letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZovaColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter.letter,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              letter.ipa,
              style: const TextStyle(
                fontSize: 11,
                color: ZovaColors.secondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final _PronunciationTip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZovaColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ZovaColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tip.sound,
              style: const TextStyle(
                color: ZovaColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.tip,
                  style: const TextStyle(
                    color: ZovaColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.example,
                  style: const TextStyle(
                    color: ZovaColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
