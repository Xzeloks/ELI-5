enum SimplificationStyle {
  eli5,
  summary,
  expert,
}

// Helper to get a display string for each style
String displayStringForSimplificationStyle(SimplificationStyle style) {
  switch (style) {
    case SimplificationStyle.eli5:
      return 'ELI5';
    case SimplificationStyle.summary:
      return 'Summary';
    case SimplificationStyle.expert:
      return 'Expert';
    default:
      return '';
  }
}

// Helper to get an explanation for each style
String explanationForSimplificationStyle(SimplificationStyle style) {
  switch (style) {
    case SimplificationStyle.eli5:
      return 'Explains complex topics in very simple terms, as if for a 5-year-old.';
    case SimplificationStyle.summary:
      return 'Provides a concise overview of the main points, hitting key takeaways.';
    case SimplificationStyle.expert:
      return 'Offers a detailed and nuanced explanation, assuming some prior knowledge.';
    default:
      return 'Select a style to see its explanation.';
  }
} 