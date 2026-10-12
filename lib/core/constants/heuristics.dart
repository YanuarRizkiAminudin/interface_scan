/// Nielsen's 10 Usability Heuristics
class NielsenHeuristic {
  final int id;
  final String shortName;
  final String fullName;
  final String description;

  const NielsenHeuristic({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.description,
  });
}

const List<NielsenHeuristic> kNielsenHeuristics = [
  NielsenHeuristic(
    id: 1,
    shortName: 'Visibility of System Status',
    fullName: 'H1 – Visibility of System Status',
    description:
        'The design should always keep users informed about what is going on, '
        'through appropriate feedback within reasonable time.',
  ),
  NielsenHeuristic(
    id: 2,
    shortName: 'Match Between System and the Real World',
    fullName: 'H2 – Match Between System and the Real World',
    description:
        'The design should speak the users\' language. Use words, phrases, and '
        'concepts familiar to the user.',
  ),
  NielsenHeuristic(
    id: 3,
    shortName: 'User Control and Freedom',
    fullName: 'H3 – User Control and Freedom',
    description:
        'Users often perform actions by mistake. They need a clearly marked '
        '"emergency exit" to leave the unwanted state.',
  ),
  NielsenHeuristic(
    id: 4,
    shortName: 'Consistency and Standards',
    fullName: 'H4 – Consistency and Standards',
    description:
        'Users should not have to wonder whether different words, situations, '
        'or actions mean the same thing.',
  ),
  NielsenHeuristic(
    id: 5,
    shortName: 'Error Prevention',
    fullName: 'H5 – Error Prevention',
    description:
        'Good error messages are important, but the best designs carefully '
        'prevent problems from occurring in the first place.',
  ),
  NielsenHeuristic(
    id: 6,
    shortName: 'Recognition Rather than Recall',
    fullName: 'H6 – Recognition Rather than Recall',
    description:
        'Minimize the user\'s memory load by making elements, actions, and '
        'options visible.',
  ),
  NielsenHeuristic(
    id: 7,
    shortName: 'Flexibility and Efficiency of Use',
    fullName: 'H7 – Flexibility and Efficiency of Use',
    description:
        'Shortcuts—hidden from novice users—may speed up the interaction for '
        'the expert user.',
  ),
  NielsenHeuristic(
    id: 8,
    shortName: 'Aesthetic and Minimalist Design',
    fullName: 'H8 – Aesthetic and Minimalist Design',
    description:
        'Interfaces should not contain irrelevant or rarely needed information. '
        'Every extra unit of information competes with the relevant information.',
  ),
  NielsenHeuristic(
    id: 9,
    shortName: 'Help Users Recognize, Diagnose, and Recover from Errors',
    fullName: 'H9 – Help Users Recognize, Diagnose, and Recover from Errors',
    description:
        'Error messages should be expressed in plain language, precisely '
        'indicate the problem, and constructively suggest a solution.',
  ),
  NielsenHeuristic(
    id: 10,
    shortName: 'Help and Documentation',
    fullName: 'H10 – Help and Documentation',
    description:
        'It\'s best if the system doesn\'t need any additional explanation. '
        'However, it may be necessary to provide documentation to help users '
        'understand how to complete their tasks.',
  ),
];

NielsenHeuristic heuristicById(int id) =>
    kNielsenHeuristics.firstWhere((h) => h.id == id,
        orElse: () => kNielsenHeuristics.first);
