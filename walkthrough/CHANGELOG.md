# Changelog

## 0.2.0
- Add `/walkthrough:update` — refresh an existing walkthrough HTML in place. Reconstructs the prior
  content from the chosen document (the embedded `DET` detail store is the high-fidelity source),
  folds in explicitly-named spec/source files, and overwrites the same file as one coherent
  document. Always confirms the target before overwriting; user- and intent-invokable; reuses
  `create`'s references unchanged for rendering. No new file, no backup, no update chrome.

## 0.1.0
- Initial release. `/walkthrough:create` renders the current session as a self-contained
  interactive HTML document in a fixed house style (dark + warm-light themes). On-demand;
  user- and intent-invokable. Output to `.claude/walkthrough/`.
