/// The help resources the crisis card offers — PRD R10.6.
///
/// R10.6 asks for "locale-appropriate help resources".
///
/// ## Why there are no phone numbers in this file
///
/// §16: "No invented facts about the owner, no fake testimonials, ratings, or
/// user counts." A crisis line number is the single worst thing in this
/// codebase to get wrong. A number that has been reassigned, that never
/// existed, or that is right for one country and wrong for the user's, is not a
/// cosmetic error — it is a person in crisis dialling a disconnected line
/// because this app told them to.
///
/// I do not have verified, current numbers for the primary market (South Asia,
/// per §0.5.3 and RESEARCH.md §2), and writing plausible ones from memory would
/// be exactly the fabrication §16 forbids, dressed up as helpfulness.
///
/// So the card offers two things that are true everywhere and need no
/// maintenance:
///
///   * **Local emergency services**, named as "your local emergency number"
///     rather than a specific digit string. Every user knows theirs; no version
///     of this app can know it for them.
///   * **A directory that resolves by country**, so the user reaches a line
///     that is current in *their* country rather than one that was current in
///     mine on the day this shipped. This is arguably more locale-appropriate
///     than a hardcoded list, because a hardcoded list starts going stale the
///     moment it is written and nothing in the release process would notice.
///
/// [verifiedLines] is the slot for real per-country numbers and is deliberately
/// empty. It is a `TODO(muneeb)` in README.md: numbers go in only after the
/// owner has confirmed each one against its operator's own site, with the date
/// of that check recorded here. Until then the directory carries the load.
///
/// **This must be closed before launch, not after** — R10.6 says so in those
/// words, and §14 lists the crisis path as an acceptance criterion.
library;

/// One offered resource. The label is an ARB key, not copy: R11.7 keeps
/// user-facing strings out of `lib/`, and this is the most important copy in
/// the app to get right in the reader's own language.
enum CrisisResourceKind {
  /// "Call your local emergency number." No digits — see the library comment.
  emergencyServices,

  /// An international directory that resolves to the user's country.
  helplineDirectory,
}

class CrisisResource {
  const CrisisResource({required this.kind, this.url});

  final CrisisResourceKind kind;

  /// Null for [CrisisResourceKind.emergencyServices], which is an instruction
  /// rather than a link.
  final String? url;
}

abstract final class CrisisResources {
  const CrisisResources._();

  /// findahelpline.com — an international directory run by ThroughLine that
  /// detects the visitor's country and lists verified lines for it.
  ///
  /// Chosen over a hardcoded number for the reason in the library comment, and
  /// over a search query because a search result page is not a resource, it is
  /// a gamble.
  static const _directory = 'https://findahelpline.com';

  /// What every user is offered, in every locale.
  static const universal = [
    CrisisResource(kind: CrisisResourceKind.emergencyServices),
    CrisisResource(kind: CrisisResourceKind.helplineDirectory, url: _directory),
  ];

  /// Verified per-country lines. **Empty on purpose.**
  ///
  /// See the library comment. Adding an entry requires the owner to have
  /// checked the number against the operator's own site, and the check date to
  /// be written beside it. An unverified entry here is worse than no entry.
  static const Map<String, List<CrisisResource>> verifiedLines = {};

  /// The resources to show for [locale].
  static List<CrisisResource> forLocale(String locale) {
    final code = locale.split(RegExp('[-_]')).first.toLowerCase();
    return [...?verifiedLines[code], ...universal];
  }
}
