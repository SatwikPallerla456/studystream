# Plex native catalog and matching API findings

This focused static pass recovers manual candidate search, selected-match application, unmatching, edition-aware identity paths and pagination helpers needed for Tangerine's catalog. It does not execute Plex, contact its providers or inspect a personal library. Decompiling the entire server is outside scope.

The analyzed faithful arm64 server slice has SHA-256 `769c80e0fcf3efdd40f5c8c8003d0dc1b02400b79a73d3335f82d820a9e49cc7`. Canonical REA results use Ghidra 12.1.4 and targeted analysis profile digest `c15686b0efcd6f1168a72b6a5a810b4bee545cad17dfa3f40d7a16269dce40e6`. Function seeds are analyst assertions; the retained pseudocode supplies the actual recovered control flow. Pseudocode is reconstructed C, with explicit unreachable-block/type-propagation warnings, rather than original C++ source or observed execution. Compiler-generated ownership code and unresolved virtual calls limit exact type recovery.

## Evidence ledger

All entries link to retained pseudocode. Matching raw `evidence/server-native-NNN-procedure_pseudo_code.json` records preserve the full identity/profile/limitations.

| Label | Procedure and retained output | REA Evidence ID |
| --- | --- | --- |
| A01 | [Edition migration, 0x10055e92c](../.verification/plex-targeted-20261019/pseudocode/server-native-008.c) | `ev_664a1522264b5c9c5f17decb839fa5ba97e3ef9821df76dbe2241ee9c9af7c88` |
| A02 | [Edition-aware lookup branch, 0x10057eed8](../.verification/plex-targeted-20261019/pseudocode/server-native-009.c) | `ev_76544d9a6d571dd0c27998426bb855629ffb7201de6b5d84b10477a8b66596da` |
| A03 | [Path mapper, 0x10073cefc](../.verification/plex-targeted-20261019/pseudocode/server-native-011.c) | `ev_994f8216663b37655148e6b4277c6441f93607acb7e3aa70b94ca3c701bf3be3` |
| A04 | [Match/refresh body, 0x1008487fc](../.verification/plex-targeted-20261019/pseudocode/server-native-015.c) | `ev_ab74104d2a9ec5fc51c55de576b4c5bf14673f883d1b9eed4354ae10a89a4f1e` |
| A05 | [Selected identity assignment/merge path, 0x10084a1f8](../.verification/plex-targeted-20261019/pseudocode/server-native-016.c) | `ev_63874f5b260987a83929758dd7a9411dbf04629428fb10f3dd4e880cb010b03e` |
| A06 | [EPG enhancement, 0x1009d0684](../.verification/plex-targeted-20261019/pseudocode/server-native-017.c) | `ev_558f1e00bcbd2ef005b1b758b6eb1a675d362135fe1952d595992c0aeac7667a` |
| A07 | [Universal provider request, 0x100ad08f8](../.verification/plex-targeted-20261019/pseudocode/server-native-018.c) | `ev_0c6685f99f5502b37c10cce491da9425da27ab1de05c679df1bd4b455bdbfe99` |
| A08 | [Metadata update argument parser, 0x100797ce4](../.verification/plex-targeted-20261019/pseudocode/server-native-022.c) | `ev_4f837379410ec9bdfd4792cba2dd881f8f9bcf57b839f2643f48286617a3e06e` |
| A09 | [Response pagination headers, 0x100c8f130](../.verification/plex-targeted-20261019/pseudocode/server-native-030.c) | `ev_c3f667b0af3177bd44048a6da270ed4a3d4f52a9ff7c18860fcc00abc245f839` |
| A10 | [Remote play-state sync paging, 0x100ac79ac](../.verification/plex-targeted-20261019/pseudocode/server-native-031.c) | `ev_76e107e49a2836ff12270b680ed4768038e8981a07a4c275cb1b17d2e40690b4` |
| A11 | [HTTP client paging, 0x100ee521c](../.verification/plex-targeted-20261019/pseudocode/server-native-032.c) | `ev_7bce689d444ccc32e0150d9dbf39fb48c8ba5d6f2a17332823776a54bd233f7a` |
| A12 | [Unmatch route callable, 0x1006bfdac](../.verification/plex-targeted-20261019/pseudocode/server-native-033.c) | `ev_63b38685183b22e8452cfbcee763bf4fd0f572ded2df2c6a476ce9d9a9c5804a` |
| A13 | [Candidate-search callable, 0x1006bec08](../.verification/plex-targeted-20261019/pseudocode/server-native-034.c) | `ev_a903dfe431e8b0b8e119172c1cd1ceb3bb0e636579d03c769c71cac04df8f740` |
| A14 | [Unmatch body, 0x100847a20](../.verification/plex-targeted-20261019/pseudocode/server-native-035.c) | `ev_8146c11325282c76ff205a48cd6d87c43f99fabe3eccec65cedd138b735bc293` |
| A15 | [Candidate search body, 0x1008452c4](../.verification/plex-targeted-20261019/pseudocode/server-native-036.c) | `ev_997423dea83d809d885ff8121167a58b1eb04b67ed70a7c56fa36bc9a7e589e9` |
| A16 | [Single-item validation, 0x1006c44cc](../.verification/plex-targeted-20261019/pseudocode/server-native-037.c) | `ev_d91c5f78d76d67f9ffbad51da8e35412645c1fbaa4e97005eb649931fe56e0ab` |
| A17 | [Metadata identity reset, 0x100847c54](../.verification/plex-targeted-20261019/pseudocode/server-native-039.c) | `ev_5dd941fc640756dbc966c69110f9cfeb6e60d5b04dc2c1c4a202662b9eeba562` |
| A18 | [Selected-match callable, 0x1006bf1ac](../.verification/plex-targeted-20261019/pseudocode/server-native-040.c) | `ev_275e75347cbe73822beff38b1fe168228e1123e46e609d31a056ff9a1a5c6273` |
| A19 | [Field-state membership, 0x10081e590](../.verification/plex-targeted-20261019/pseudocode/server-native-041.c) | `ev_86e684214965cfbfcf50e28efeabf47e46058aab60baae13d0e90dff5bc0ddb8` |
| A20 | [Field-state insertion/removal, 0x10084c268](../.verification/plex-targeted-20261019/pseudocode/server-native-042.c) | `ev_31a1de0d7df0a90c36c4b470c0735cf6133d1775d3c111c9588c242f5ddb9041` |
| A21 | [Locked-field loader, 0x100852a0c](../.verification/plex-targeted-20261019/pseudocode/server-native-043.c) | `ev_79fb5531515ebc74d2d47788536ea229e151b96e90d7f980398ef1d7886ce4e4` |

The huge registry `0x1006a0fe4` **did not produce canonical pseudocode**: [server-native-010](../.verification/plex-targeted-20261019/evidence/server-native-010-procedure_pseudo_code.json) records an execution failure without an Evidence ID. It was not retried unchanged. Separate ordinary immutable [LLVM registry assembly](../.verification/plex-targeted-20261019/derived/server-main-route-registry.asm) binds `/matches` to callable `0x1006bec08`, `/match` to `0x1006bf1ac`, and `/unmatch` to `0x1006bfdac` within this registry. Numeric registration flags have not been given unsupported HTTP/access-control meanings. A03 itself is a type/path mapper, not route registration.

## Manual search, selection and correction

**Candidate search is separate from committing a match.** A13 validates a single metadata item, constructs optional search overrides, then invokes A15 and returns its candidate objects. For an explicit name override, it uses different parameter names by metadata type: `show`, `artist`, `title`, `author`, `audiobook`, or fallback `name`. It also handles optional `parentTitle` and `year`.

A15 resolves library/provider configuration, language override, country default `US` and adult-content preference. Its legacy agent-search branch builds `/system/agents/search?…&manual=1`, performs the request, parses results and has an explicit empty-result path. Other provider paths are present; an unresolved virtual call cannot be treated as recovered remote ranking logic. The search results are candidates, not proof that selecting the first result is always correct.

**Selection is an explicit mutation path.** A18 logs that HTTP methods other than its preferred method are deprecated and says “Use PUT instead.” It accepts indexed `guid[n]` parameters into an integer-keyed map, resolves an `mbid`-related option, then calls A05 to apply identity and A04 with manual/refresh flags. It returns status 200 after these calls. The complete route prefix and every accepted alias/parameter constraint are not reconstructed merely from the suffix registration.

A05 canonicalizes the supplied identity, reloads the current metadata item and runs the identity-reset helper. It looks for an existing compatible target using the new GUID and the current library/index context. If no eligible target is found, it changes the item's identity and conditionally updates unlocked metadata fields before saving. If a suitable target exists and downstream compatibility checks succeed, it calls merge helper `0x10084d13c`, replaces the current object's ID with the resulting ID and follows a different persistence path. This is concrete evidence that matching can cause a catalog merge; it is not evidence that Tangerine should merge its original resource IDs. Full migration of watched state, history, media-part relationships and rollback behavior requires the merge helper's internals and callers.

For Tangerine, keep existing file/resource IDs and notes/progress anchors stable. Make a selected provider identity a separate link; permit correcting or clearing that link without regenerating file IDs. If grouping two catalog cards becomes appropriate, perform an explicit transaction and retain distinct assets/editions. These are independent implementation decisions informed by the recovered risk of identity changes.

## Unmatch, metadata reset and editions

A12 checks a single metadata item, resolves a context, invokes A14 and returns 200. A16's validation is **cardinality/lookup validation**, not a demonstrated authorization check: it requires one shared-pointer entry, otherwise logs an invalid metadata ID and throws status 404.

A14 calls A17 with reset parameters, then chooses `tv.plex.agents.none` or `com.plexapp.agents.none` according to a library-agent classifier and invokes the common match/refresh body A04 using language `xn` and zero flags. Unmatching therefore includes reset and none-agent refresh machinery; it cannot be described accurately as deleting only a provider-link string.

A17 changes identity first, and only follows the substantial reset path when that call reports a change. It consults the same field-state helper `0x10081e590` before clearing many scalar fields, artwork or tag groups. It treats uploaded artwork specially and has explicit edition/show-edition handling. A08 separately parses `.value`, `.locked`, tag and tagging update arguments, rejects unknown fields/invalid scopes, and applies later mutations. A19 lazily loads a set/map of field IDs and returns membership; A20 removes a field ID when given zero, otherwise inserts it with a set byte, and marks the state dirty. This establishes the guard mechanism used to preserve marked fields through reset. A21 additionally recovers the loader: it splits a stored string into `&`-separated entries, splits entries on `=`, finds `lockedFields`, then splits its value on `|` and converts nonempty tokens to integer field IDs inserted into the lock set. The delimiter bytes are independently retained in [the byte inspection](../.verification/plex-targeted-20261019/derived/server-field-lock-delimiter-bytes.json). A malformed integer follows a bad-cast error path. This establishes a query-string-shaped `lockedFields=1|2|…` representation, not a field-name enumeration or a fully recovered serializer/escaping contract. A08 calls A20 when applying parsed `.locked` arguments. The full reset rules and each numeric field mapping still require contextual tracing.

A01 executes a migration adding `edition_title` and its index, confirming that the packaged database template is older than the native runtime schema. A02 contains a bounded identity lookup branch constrained by library, optional year, escaped title and escaped edition title. A05 also feeds edition/index context into target lookup; A17 uses `edition` or `show_edition` source metadata while rebuilding an unlocked edition field. These paths establish that edition affects identity. They do not establish a universal filename score, all edition aliases, cut-duration equivalence, edition UI grouping or shared progress semantics.

## What provider requests establish—and what they do not

A07 constructs an outbound request using the configured `UniveralMetadataProviderUrl` plus `/providers/universal/library/matches`. The literal setting's spelling is retained as shipped. Request fields include `filename`, `includeFullMetadata=1`, `includeAncestorMetadata=1`, optional `plexHash`, `openSubtitlesHash`, `fileSize` and language. Its response parser selects `Video`/`Directory` nodes and interprets returned metadata. This recovers the local request/response boundary; the service-side scorer remains outside the executable and was not contacted.

A06 uses a similar universal URL for **EPG enhancement** and rejects a parsed score below 94. Its EPG logs and caller-specific purpose prevent applying 94 as a movie/library matching threshold. Likewise, the scanner investigation's legacy score branch and modern-agent synthetic score of 100 are separate paths. None of these values is an established universal automatic-match confidence policy for Tangerine.

## Pagination and permissions: bounded conclusions

A09 is response-side header plumbing: after a successful dynamic cast to a paged-result context and nonnegative context checks, it appends `X-Plex-Container-Start` and `X-Plex-Container-Total-Size`. It does **not** establish inbound request bounds, page-size defaults, stable query ordering, SQL offsets or cursor validation.

A10 is an outbound **remote play-state synchronization client**, not a general inbound catalog controller. It requests selected view-state fields, orders by `viewUpdatedAt:asc,<identifier>:asc`, supplies container start/size and uses 1000 or 200 according to a branch. It parses `size`, `totalSize`, `offset`, checks consistency and can restart when overlap cannot be found. A11 is another outbound HTTP paging helper that supplies container headers and checks returned start/total-size headers and expected page bounds. The exact consistency checks are retained in the code; these client page sizes are not global Plex API limits.

No complete inbound catalog permission policy was recovered in these functions. Metadata ID validation, a device token, a numeric route flag or a provider country/adult setting must not be mislabeled as a library authorization decision. This is a named remaining gap, not evidence that Plex lacks permissions.

Tangerine should use source-aware media resolution, library-scoped grants across every listing/search/artwork/stream/mutation route, stable `(sortKey, ID)` pagination and explicit transport revisions. Those choices address the current implementation gaps documented in the [Tangerine gap map](../.verification/plex-targeted-20261019/tangerine-catalog-gap-map.md); they do not depend on copying undocumented Plex flags.
