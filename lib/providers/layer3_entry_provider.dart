import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The domain (card type) that triggered descent into Layer 3.
/// Set by Layer 2 card Listeners on pointer-down, read by Layer 3
/// to determine which detail card to show.
final layer3EntryDomainProvider = StateProvider<String?>((ref) => null);
