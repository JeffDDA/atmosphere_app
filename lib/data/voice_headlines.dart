import '../models/condition_state.dart';

const voiceHeadlines = <ConditionState, String>{
  ConditionState.exceptional:
      'Extraordinary clarity tonight. Every photon is yours.',
  ConditionState.excellent:
      'Outstanding conditions. Deep sky is wide open.',
  ConditionState.good:
      'Solid night ahead. Good transparency, steady seeing.',
  ConditionState.marginalImproving:
      'Conditions improving. A window may open later.',
  ConditionState.marginalDegrading:
      'Conditions softening. Shoot your priority targets first.',
  ConditionState.poorGap:
      'Mostly cloudy, but a gap is forecast. Stay alert.',
  ConditionState.poorSeeing:
      'Turbulent atmosphere tonight. Planetary work will struggle.',
  ConditionState.smoke:
      'Smoke aloft. Transparency is compromised.',
  ConditionState.fog:
      'Fog likely. Dew management is critical.',
  ConditionState.overcast:
      'Overcast tonight. Rest your gear.',
  ConditionState.multiDayOvercast:
      'Extended cloud cover. Next opening is days away.',
  ConditionState.astroDarkGood:
      'Dark skies, good conditions. Faint targets are in play.',
  ConditionState.astroDarkPoor:
      'Dark but turbulent. Stick to wide-field.',
};
