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
