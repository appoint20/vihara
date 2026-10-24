#!/bin/bash
#
# Enforces the dependency rule from docs/adr/002-modules.md.
#
# The layers live in folders rather than in separate Swift packages, so nothing stops
# a domain file from importing SwiftUI except this script. Run it in CI; when it
# starts feeling like a substitute for real module boundaries, that is the signal to
# extract the packages (see the ADR for the trigger).
#
#   Domain  → Foundation only. No SwiftUI, no UIKit, no Data, no Features.
#   Data    → Domain and Foundation. No SwiftUI, no UIKit, no Features.
#   Design  → no Domain, no Data, no Features.
#
set -uo pipefail
cd "$(dirname "$0")/.."

status=0

fail() {
    echo "  ✘ $1"
    status=1
}

echo "Domain must not import UI frameworks"
if grep -rlE '^import (SwiftUI|UIKit)' Vihara/Domain 2>/dev/null | grep .; then
    fail "the domain layer imports a UI framework"
fi

echo "Data must not import UI frameworks"
if grep -rlE '^import (SwiftUI|UIKit)' Vihara/Data 2>/dev/null | grep .; then
    fail "the data layer imports a UI framework"
fi

echo "Domain must not reference concrete data types"
for symbol in URLSessionHTTPClient PilotDestinationCatalogue StubTripGenerator \
              HeuristicTripBriefParser InMemoryTripRepository RemoteTripGenerator \
              TripStreamDTO; do
    if grep -rl "\b$symbol\b" Vihara/Domain 2>/dev/null | grep .; then
        fail "the domain layer names $symbol, which belongs to the data layer"
    fi
done

echo "Features must not name concrete data types"
# Screens depend on protocols and use cases. A feature reaching for a stub is a
# feature that cannot be pointed at the real backend later. Previews may, since a
# preview is allowed to build its own world.
for symbol in SampleItineraries PilotDestinationCatalogue StubTripGenerator \
              HeuristicTripBriefParser InMemoryTripRepository FileTripRepository \
              UserDefaultsInterviewDraftStore RemoteTripGenerator; do
    for file in $(grep -rl "\b$symbol\b" Vihara/Features --include='*.swift' 2>/dev/null); do
        # Comment lines are skipped: prose naming a stub is not a dependency on it.
        awk -v file="$file" -v sym="$symbol" '
            /#Preview/ { if (!preview) preview = NR }
            /^[[:space:]]*(\/\/|\*|\/\*)/ { next }
            $0 ~ sym { if (!preview || NR < preview) print file ":" NR ": " $0 }
        ' "$file" | grep . && fail "$file names $symbol outside a preview"
    done
done

echo "The design system must not know about the domain"
# Comments are stripped first: prose about a "Destination card" is not a dependency.
for symbol in TripBrief ItineraryItem DayBlock TripDay Destination Wallet; do
    if grep -rn "\b$symbol\b" Vihara/DesignSystem --include='*.swift' 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+: *(//|\*|/\*)' | grep .; then
        fail "the design system names $symbol — components stay presentational"
    fi
done

echo "Only the theme may hold colour literals"
if grep -rlE '(Color|UIColor)\((\.sRGB|red:|hex:)' Vihara \
    --include='*.swift' 2>/dev/null | grep -v 'DesignSystem/Theme.swift' | grep .; then
    fail "a colour literal escaped Theme.swift"
fi

echo "The shared folder must stay Foundation-only"
# ViharaShared is compiled into BOTH the app and the share extension. An app
# extension links its own binary, so anything it drags in it pays for in launch time
# and memory — and an extension gets a fraction of the app's budget. SwiftUI here
# would also make the contract untestable from a command line.
if grep -rlE '^import (SwiftUI|UIKit)' ViharaShared 2>/dev/null | grep .; then
    fail "ViharaShared imports a UI framework"
fi

echo "The shared folder must not know the domain"
# The extension cannot see Vihara/Domain, so a reference here compiles in the app and
# breaks the extension — a failure that only shows up when the appex is built.
for symbol in Trip TripBrief ItineraryItem Place Destination Wallet Identifier; do
    if grep -rn "\b$symbol\b" ViharaShared --include='*.swift' 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+: *(//|\*|/\*)' | grep .; then
        fail "ViharaShared names $symbol, which the share extension cannot see"
    fi
done

echo "The share extension must not reach into the app"
# Same reason, plus one of taste: the extension draws one sentence, and compiling the
# design system into it to do that would be absurd.
for symbol in Theme AppDependencies PlaceVocabulary ResolveCapture PilotDestinationCatalogue; do
    if grep -rn "\b$symbol\b" ViharaShare --include='*.swift' 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+: *(//|\*|/\*)' | grep .; then
        fail "ViharaShare names $symbol, which lives in the app target"
    fi
done

echo "No affiliate marker may ship in the client"
# ADR-006: affiliate links are minted by the service and arrive opaque. A tracking
# parameter in this target is either a dead link waiting for the next App Review or a
# fabricated one that earns nothing — and it cannot be rotated when a programme
# changes hands. Comments are stripped: prose naming a marker is not one.
for marker in 'aid=' 'marker=' 'partner_id=' 'affiliate_id=' 'utm_source=' 'utm_campaign='; do
    if grep -rn -- "$marker" Vihara --include='*.swift' 2>/dev/null \
        | grep -vE '^[^:]+:[0-9]+: *(//|\*|/\*)' | grep .; then
        fail "an affiliate marker ($marker) is hard-coded in the client — see docs/adr/006"
    fi
done

echo "Only the composition root may build dependencies"
# Previews may build their own dependencies; screen code may not. Previews sit below
# the type they preview, so "after the first #Preview" is a sound test for it.
for file in $(grep -rl 'AppDependencies' Vihara/Features --include='*.swift' 2>/dev/null); do
    awk -v file="$file" '
        /#Preview/ { if (!preview) preview = NR }
        /AppDependencies/ { if (!preview || NR < preview) print file ":" NR ": " $0 }
    ' "$file" | grep . && fail "$file builds the composition root outside a preview"
done

if [ $status -eq 0 ]; then
    echo "✔ layering holds"
fi
exit $status
