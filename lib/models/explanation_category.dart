enum ExplanationCategory {
  meaning('Meaning'),
  reading('Reading / Pronunciation'),
  context('Context'),
  examples('Examples'),
  breakdown('Breakdown'),
  formality('Formality / Register'),
  similarWords('Similar Words');

  final String displayName;
  const ExplanationCategory(this.displayName);
}
