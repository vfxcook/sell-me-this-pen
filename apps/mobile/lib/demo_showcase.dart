import 'api.dart';

/// On-device Demo Mode showcase — the ONE sanctioned place in the app
/// for sample content.
///
/// Why this exists: on a real phone there is usually no backend
/// running (the default URL is an emulator address), so a demo that
/// needs the backend shows nothing at all. This showcase runs fully
/// offline, with no keys and no network, so anyone opening the app
/// can see what a full audience test looks like in about a minute.
///
/// Honesty rules for this file, enforced by the screen that renders it:
/// - Every phase of the demo renders the DemoBanner above the content.
/// - These events and results are NEVER sent to, mixed with, or shown
///   as a real simulation. Real simulation screens (live feed,
///   results) still render backend data only.
/// - Metrics below are plain counts of these 16 sample messages, with
///   denominator and method stated — never percentages of real people.
class DemoShowcase {
  static const String ideaTitle = 'InkLink — the pen that remembers';
  static const String ideaDescription =
      'A pen that turns handwritten notes into searchable text on your '
      'phone. Write on ordinary paper, search any word later. ₹1,999.';
  static const String audienceNote =
      '16 sample audience members: students, teachers, office staff, '
      'shop owners and one sceptical parent.';

  static const List<SimEvent> events = [
    SimEvent(
      id: 'demo-01',
      agentName: 'Ananya',
      persona: 'College student',
      classification: 'positive',
      message:
          'I lose half my class notes every semester. If this actually '
          'finds my handwritten pages by searching a word, I would buy '
          'it on day one.',
    ),
    SimEvent(
      id: 'demo-02',
      agentName: 'Rohan',
      persona: 'Office manager',
      classification: 'question',
      message:
          'Does it work with any notebook, or do I need special paper? '
          'My team will not switch notebooks for a pen.',
    ),
    SimEvent(
      id: 'demo-03',
      agentName: 'Meera',
      persona: 'School teacher',
      classification: 'positive',
      message:
          'I write feedback on 40 notebooks a week. Searching old '
          'remarks instead of flipping pages would save me hours.',
    ),
    SimEvent(
      id: 'demo-04',
      agentName: 'Vikram',
      persona: 'Sceptical parent',
      classification: 'objection',
      message:
          '₹1,999 for a pen? My daughter already has a phone that takes '
          'photos of notes. Convince me this is different.',
    ),
    SimEvent(
      id: 'demo-05',
      agentName: 'Sara',
      persona: 'Startup founder',
      classification: 'suggestion',
      message:
          'Sell the pen with 100 pages of free cloud backup. The pen '
          'is the hook — the search is the product.',
    ),
    SimEvent(
      id: 'demo-06',
      agentName: 'Arjun',
      persona: 'Accountant',
      classification: 'negative',
      message:
          'Handwriting recognition for mixed Hindi-English notes is '
          'still hit-or-miss. One wrong search and trust is gone.',
    ),
    SimEvent(
      id: 'demo-07',
      agentName: 'Divya',
      persona: 'Medical student',
      classification: 'question',
      message:
          'How long does the battery last? If it dies mid-lecture, '
          'it is just an expensive normal pen.',
    ),
    SimEvent(
      id: 'demo-08',
      agentName: 'Kabir',
      persona: 'Small shop owner',
      classification: 'positive',
      message:
          'I write daily accounts by hand. If I can search “payment '
          'pending” across months of registers, that is real money saved.',
    ),
    SimEvent(
      id: 'demo-09',
      agentName: 'Neha',
      persona: 'Design student',
      classification: 'suggestion',
      message:
          'Show it working on messy handwriting in the ad — not neat '
          'calligraphy. Everyone’s notes look like mine: rushed.',
    ),
    SimEvent(
      id: 'demo-10',
      agentName: 'Farhan',
      persona: 'Tech reviewer',
      classification: 'objection',
      message:
          'Privacy: my notes go to your cloud? Students write personal '
          'stuff. Local-first storage would be a much easier sell.',
    ),
    SimEvent(
      id: 'demo-11',
      agentName: 'Lakshmi',
      persona: 'Tuition teacher',
      classification: 'positive',
      message:
          'Parents pay me to track progress. If I can pull up every '
          'note I wrote about a child in one search, that is my '
          'premium feature.',
    ),
    SimEvent(
      id: 'demo-12',
      agentName: 'Aditya',
      persona: 'College student',
      classification: 'negative',
      message:
          'I will lose the pen in a week. At ₹1,999, losing it hurts '
          'more than losing a ₹20 pen. Where is the find-my-pen feature?',
    ),
    SimEvent(
      id: 'demo-13',
      agentName: 'Priya',
      persona: 'HR manager',
      classification: 'question',
      message:
          'Can two people share one pen, or does it mix up '
          'handwriting? Our interview panel shares stationery all '
          'the time.',
    ),
    SimEvent(
      id: 'demo-14',
      agentName: 'Imran',
      persona: 'Bookstore owner',
      classification: 'suggestion',
      message:
          'Bundle it with a notebook at launch. A ₹2,499 pen + '
          'notebook kit feels like a gift, not a gadget.',
    ),
    SimEvent(
      id: 'demo-15',
      agentName: 'Sneha',
      persona: 'Young professional',
      classification: 'positive',
      message:
          'My meeting notes are useless after a week because I cannot '
          'find anything. Searchable handwriting is the one feature '
          'I would actually pay for.',
    ),
    SimEvent(
      id: 'demo-16',
      agentName: 'Ravi',
      persona: 'Retired banker',
      classification: 'neutral',
      message:
          'I like paper. I do not hate the idea, but I would need to '
          'see it read my shaky handwriting before I believe it.',
    ),
  ];

  /// Shaped like the backend results payload so the results section
  /// renders with the same widgets as a real report.
  static const Map<String, dynamic> results = {
    'summary':
        'Strong interest, price and trust are the fight. The sample '
        'audience loved the search idea but pushed back hard on '
        '₹1,999, handwriting accuracy for mixed-language notes, and '
        'cloud privacy. The winning pitch is not the pen — it is '
        '“never lose a note again”, plus a find-my-pen safety net.',
    'metrics': [
      {
        'name': 'Positive reactions',
        'numerator': 5,
        'denominator': '16 sample messages',
        'method': 'sample count',
      },
      {
        'name': 'Objections raised',
        'numerator': 2,
        'denominator': '16 sample messages',
        'method': 'sample count',
      },
      {
        'name': 'Questions asked',
        'numerator': 3,
        'denominator': '16 sample messages',
        'method': 'sample count',
      },
      {
        'name': 'Suggestions offered',
        'numerator': 3,
        'denominator': '16 sample messages',
        'method': 'sample count',
      },
    ],
    'positive_themes': [
      'Searchable handwritten notes — the one feature people would pay for',
      'Time saved finding old notes (class, accounts, feedback)',
      'Works with existing paper habits instead of replacing them',
    ],
    'negative_themes': [
      '₹1,999 feels steep for a losable pen',
      'Handwriting accuracy for mixed Hindi-English notes doubted',
      'Cloud privacy of personal notes',
      'Battery dying mid-lecture',
    ],
    'objections': [
      '₹1,999 for a pen when a phone camera is free',
      'Notes going to the cloud feels unsafe for personal writing',
    ],
    'questions': [
      'Does it need special paper?',
      'How long does the battery last?',
      'Can multiple people share one pen?',
      'Where does my data live?',
    ],
    'suggestions': [
      'Bundle a notebook at launch (₹2,499 kit)',
      'Add find-my-pen',
      'Offer local-first storage option',
      'Show messy real handwriting in the ad, not calligraphy',
    ],
    'key_takeaways': [
      'Lead with “never lose a note again”, not the hardware',
      'Answer price with the kit bundle + find-my-pen',
      'Prove accuracy on messy, mixed-language handwriting first',
      'Privacy: local-first is a selling point, not a footnote',
    ],
    'disclaimer':
        'DEMO ONLY — This report is built from the 16 sample messages '
        'above. It is not a real simulation and does not represent '
        'verified human consumer behavior, actual purchase intent, or '
        'statistically representative market research.',
  };
}
