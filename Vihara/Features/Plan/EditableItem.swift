import SwiftUI

/// Makes a stop draggable and gives it the menu that does the same things (F-05).
///
/// **The menu is not a fallback, it is the other half of the feature.** An
/// alternative to dragging cannot be bolted on later because it changes the edit
/// model, which is why `docs/ROADMAP.md` lists "build the Verschieben nach… path in
/// the same week as the gesture" as the countermeasure to this exact risk. Both paths
/// emit a ``PlanEdit`` through ``PlanEditingContext/apply`` and share
/// ``PlanEditingContext/moveTargets``, so neither can offer a move the other refuses.
///
/// Dragging alone would also put the feature out of reach of VoiceOver, Switch
/// Control and anyone whose hands do not do a precise long-press-and-hold.
struct EditableItem: ViewModifier {
    let item: ItineraryItem
    let day: TripDay?
    let editing: PlanEditingContext
    let locale: Locale

    func body(content: Content) -> some View {
        if editing.isEnabled, let day {
            content
                .draggable(item.id.rawValue)
                .contextMenu { menu(day: day) }
                // VoiceOver cannot long-press, so the same operations are offered as
                // rotor actions on the element itself.
                .accessibilityActions { menu(day: day) }
        } else {
            content
        }
    }

    @ViewBuilder
    private func menu(day: TripDay) -> some View {
        let targets = editing.moveTargets(item, day)
        if !targets.isEmpty {
            Menu(localized("plan.edit.moveTo", locale: locale)) {
                ForEach(targets, id: \.self) { slot in
                    Button(slot.label) {
                        editing.apply(.move(item: item.id, toSlot: slot, onDay: day.id))
                    }
                }
            }
        }

        Button(localized(item.isPinned ? "plan.edit.unpin" : "plan.edit.pin", locale: locale)) {
            editing.apply(.setPinned(item: item.id, !item.isPinned))
        }

        Button(localized("plan.edit.remove", locale: locale), role: .destructive) {
            editing.apply(.remove(item: item.id))
        }
    }
}

/// A fix the planner would make, offered rather than performed (F-06).
///
/// Shown as a sentence with two buttons. It never animates the change while the
/// traveller is still looking at what they did — silent reshuffling is the
/// trust-breaking behaviour the product exists to avoid, so the plan stays exactly as
/// they left it until they say otherwise.
struct ReflowProposalRow: View {
    let proposal: ReflowProposal
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Plan.S.s2) {
            Text(localized("plan.reflow.suggestion",
                           proposal.itemName,
                           proposal.toSlot.label,
                           locale: locale))
                .viharaText(Theme.Plan.F.meta)
                .foregroundStyle(Theme.C.accentDeep)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Plan.S.s4) {
                Button(action: onAccept) {
                    Text("plan.reflow.accept")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.accentDeep)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("plan.reflow.keep")
                        .viharaText(Theme.Plan.F.meta)
                        .foregroundStyle(Theme.C.textMuted)
                        .viharaInlineHitTarget()
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
