# Unshipped prototypes

These components have no import path from the production entry point. They were moved out of `lib/` during FN-146 rather than deleting their behavior tests or leaving them in the shipping source library.

The existing widget tests still exercise them. They are outside the production accessibility coverage map; promoting a prototype into `lib/design_system/` requires re-adding and satisfying the corresponding accessibility classification. No release-size claim is made from source reachability alone.
