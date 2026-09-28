# Lessons

<!-- lesson:L-new -->
- Always run the price check before a release.
  _evidence: gate-1 steer (matali run 20260927-0001)_

<!-- lesson:L-code -->
- Pricing math in `pricing-engine.ts` runs through `decimal.js`; don't round before the `$total` boundary.
  _evidence: owner's `decimal.js` note (matali run 20260927-0001)_
