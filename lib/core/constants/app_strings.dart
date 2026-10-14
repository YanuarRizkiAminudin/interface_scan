class AppStrings {
  // App
  static const String appName = 'InterfaceScan';
  static const String appTagline = 'AI-Assisted UI Evaluation';

  // Home
  static const String newEvaluation = 'New Evaluation';
  static const String recentEvaluations = 'Recent Evaluations';
  static const String noEvaluationsYet = 'Tap New Evaluation to get started.';

  // Analysis – context (Discover phase)
  static const String contextSection = 'Case Study Context';
  static const String appOrWebsite = 'App / Website Name';
  static const String appOrWebsiteHint = 'e.g. Tokopedia, Gmail, BCA Mobile…';
  static const String mainTask = 'Main User Task';
  static const String mainTaskHint =
      'e.g. Transfer money, search and buy a product…';
  static const String evaluationName = 'Evaluation name';

  // Analysis – screenshot picker
  static const String screenshotsSection = 'Screenshots (min 3, max 5)';
  static const String addScreenshot = 'Add Screenshot';
  static const String screenshotCountHint =
      'Select 3–5 screenshots from the same user flow.';
  static const String noScreenshotsYet =
      'No screenshots yet.\nTap + to pick from gallery.';
  static const String maxScreenshotsReached =
      'Maximum of 5 screenshots reached.';

  // Analysis – run / progress
  static const String analyze = 'Analyze';
  static const String reAnalyze = 'Re-analyze';
  static const String analysisInProgress = 'Analyzing screenshots…';
  static const String runningImageAnalysis = 'Running visual analysis…';
  static const String runningOcr = 'OCR – extracting text…';
  static const String generatingAiSuggestions = 'Generating AI heuristic suggestions…';
  static const String proceedToReview = 'Review Findings';

  // Analysis – results sections
  static const String visualMetrics = 'Visual Metrics';
  static const String ocrResults = 'OCR Results';
  static const String aiSuggestions = 'AI Suggestions';
  static const String perScreenDetail = 'Per-Screen Detail';
  static const String avgOf = 'avg. of';
  static const String screens = 'screens';

  // Findings
  static const String reviewFindings = 'Review Findings';
  static const String accept = 'Accept';
  static const String edit = 'Edit';
  static const String reject = 'Reject';
  static const String severity = 'Severity';
  static const String heuristic = 'Heuristic';
  static const String reason = 'Reason';
  static const String confidence = 'Confidence';
  static const String recommendation = 'Recommendation';
  static const String accepted = 'Accepted';
  static const String rejected = 'Rejected';
  static const String noFindings = 'No findings to review.';
  static const String saveEvaluation = 'Save Evaluation';

  // Comparison
  static const String comparison = 'Before vs After';
  static const String original = 'Original';
  static const String redesign = 'Redesign';
  static const String addRedesignScreenshot = 'Add Redesign Screenshot';
  static const String evaluationSummary = 'Evaluation Summary';
  static const String totalFindings = 'Total Findings';
  static const String acceptedFindings = 'Accepted';
  static const String rejectedFindings = 'Rejected';

  // Settings
  static const String settings = 'Settings';
  static const String geminiApiKey = 'Gemini API Key';
  static const String geminiApiKeyHint = 'AIza…';
  static const String geminiApiKeyHelp =
      'Required for AI heuristic suggestions. '
      'Get a free key at aistudio.google.com.';
  static const String save = 'Save';
  static const String apiKeySaved = 'API key saved.';
  static const String cancel = 'Cancel';

  // Errors
  static const String errorPickingImage = 'Failed to pick image.';
  static const String errorAnalysis = 'Analysis failed. Please try again.';
  static const String errorOcr = 'OCR failed. Please try again.';
  static const String errorAi =
      'AI suggestions unavailable. Continuing without them.';
  static const String errorSave = 'Failed to save evaluation.';
  static const String apiKeyMissing =
      'AI API key not configured. AI suggestions are disabled.';

  // Misc UI
  static const String delete = 'Delete';
  static const String deleteEvaluation = 'Delete Evaluation';
  static const String deleteConfirm =
      'Delete this evaluation? This cannot be undone.';
  static const String evaluations = 'evaluations';
  static const String evaluation = 'evaluation';
  static const String screen = 'screen';
  static const String screens2 = 'screens';
  static const String finding = 'finding';
  static const String findings = 'findings';
  static const String redesignBadge = 'Redesign';

  // Evaluation Detail
  static const String evaluationDetail = 'Evaluation Detail';
  static const String continueAnalysis = 'Continue Analysis';
  static const String noScreenshotsRecorded = 'No screenshots recorded.';
  static const String noFindingsRecorded = 'No findings recorded yet.';
  static const String screenshotsLabel = 'Screenshots';
  static const String findingsSummary = 'Findings Summary';
  static const String metricsSummary = 'Visual Metrics Summary';
  static const String notAnalyzedYet = 'Not analyzed yet.';

  // Add Finding (manual)
  static const String addFinding = 'Add Finding';
  static const String addFindingManual = 'Add Manual Finding';
  static const String findingTitle = 'Finding Title';
  static const String findingTitleHint = 'e.g. No error feedback on login failure';
  static const String findingReason = 'Reason / Observation';
  static const String findingReasonHint =
      'Describe what you observed and why it is a problem…';
  static const String findingRecommendation = 'Recommendation';
  static const String findingRecommendationHint =
      'Suggest how to fix or improve this…';
  static const String findingAdded = 'Finding added.';
  static const String titleRequired = 'Title is required.';
  static const String reasonRequired = 'Reason is required.';

  // Heuristics Reference
  static const String heuristicsReference = 'Heuristics Reference';
  static const String heuristicsSubtitle =
      "Nielsen's 10 Usability Heuristics";
  static const String heuristicsIntro =
      'These 10 general principles are used to evaluate user interface design. '
      'Each finding in InterfaceScan is mapped to one of these heuristics.';
}
