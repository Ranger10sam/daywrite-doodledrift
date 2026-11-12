# Browser playtest revision 2

This revision replaces the previous floating-static-stroke design. Every stroke
is now one compound RigidBody2D with gravity, mass, damping and shape CCD. Loose
ink falls, rotates and collides with terrain, the ball and other ink. Only a
stroke with both endpoints supported by terrain is fixed as a bridge. Its bolts
indicate support. Losing an anchor releases it. Draw Mode pauses the simulation;
gravity resumes on Done. Checkpoints snapshot the current transformed geometry.

All 50 authored contour layouts now contain crossings 860–924 pixels wide,
instead of small gaps readily cleared by an ordinary jump. The opening levels
are Meadow Bridge and Ramp Garden. Pressure-plate gates in selected stages
require a physical weight: drop a short loose stroke into the gold cradle to
hold the gate open. The ball alone releases the plate when it rolls away.
The final crossing layouts retain biome slopes, roofs, wind fields and ferries.

Physical side walls contain both the ball and loose ink. Bottomless falls still
trigger checkpoint recovery. Sky palettes, clouds, birds, flowers, terrain and
water have been brightened. Draw Mode zooms out to make both bridge banks visible.

Ink now costs 0.04 units per accepted pixel times type multiplier. Fragile ink
lasts 3.2 seconds after contact to support the longer crossings. Other surface
effects remain distinct. The first hint explains support; drawn structures are
still player-created, never automatically installed.

## Verification for this revision

- Eight revision checks pass: loose ink falls and lands on terrain, supported
  ink stays anchored, both physical boundaries contain the ball, an unweighted
  plate keeps its gate closed, a dropped weight opens it, and all 50 maps block
  an automated right-plus-continuous-jumping attempt without drawings.
- All 50 production finish triggers were reached with a conservative alternative
  route using anchored Solid bridges and dropped weights, placed through the
  real drawing controller with Normal resources and regeneration. This does not
  validate every Bounce/Boost/Ice/Fragile alternative or human difficulty balance.
- Browser verification observed the brighter scene, new opening puzzle, Draw
  Mode and falling geometry. The localhost preview was rebuilt and remains served.

Evidence: `builds/revision-suite.log`, `builds/revision-campaign.log`,
`tests/campaign_replay_results.json`. Earlier QA reports and screenshots describe
the previous revision; their full assertion count and performance measurements
must not be attributed to this changed rigid-body simulation. Android APK remains
the earlier build. This update targets the browser playtest requested here.
