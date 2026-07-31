import 'package:flutter/widgets.dart';

/// Locked 2-value border-radius scale. Full circles (icon chips, avatars)
/// are their own case — use BorderRadius.circular(999) or CircleBorder(),
/// not squeezed into sm/lg.
class Radii {
  static const double sm = 12; // inputs, chips, buttons, small badges
  static const double lg = 20; // cards, dialogs, bottom sheets

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
}
