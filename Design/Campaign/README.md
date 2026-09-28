# Campaign typography and sets refinement

The supplied screenshot was treated as a visual reference for the existing app's type and set-list layout, not as instructions. This image is the approved visual reference for the Campaign implementation.

- Use one native iOS system font family throughout the interface, with consistent optical sizing and weights. Use tabular numerals for workout values and timers. The entire mockup now uses a softer typographic treatment, not only the set area.
- Restore the compact, integrated Sets card from the current app: header with Sets, completion count and Add set; a row per set with number, target/result and state. The row labels are `1`, `2`, `3`, without repeating the word “Set.”
- Keep all rows in one card; current row gets a subtle violet treatment. The example has 1 of 3 complete, row 2 current, row 3 up next. Any additional rows remain available by scrolling, with full context retained for role/side/grouped variants.
- Preserve the revised dark/citron palette, photograph, quieter weighted buttons and compact weight/reps controls. The exact 145 lb × 8 plan and 140 lb × 8 previous result stay unchanged.
- Log set remains fixed in a bottom safe-area dock, independent of set-list scrolling. The last set row must scroll clear of the dock.
- Removing the standalone effort/notes row is a screen-composition decision; recorded effort and notes remain available from relevant set detail and in history.

The native implementation must be checked on a simulator for Dynamic Type, button interaction, scrolling, and haptics; the static mockup alone cannot verify those behaviors.
