/*
 * Matching an incoming payment to the invoice it pays.
 * The property under test: the matcher never links a payment to the wrong invoice.
 *
 * Run it:  java -jar alloy.jar exec -f -t text matching.als
 */

sig Vendor {}
sig Account {}
sig Ref {}

sig Invoice {
  vendor  : one Vendor,
  account : one Account,
  ref     : lone Ref
}

sig Payment {
  reportedAccount : one Account,
  reportedRef     : lone Ref,
  truth           : lone Invoice   // the invoice this payment is really for
}

// Reality: the sender echoes the identifiers printed on the invoice it is paying.
// A payment with no truth is for an invoice we never issued.
fact payment_echoes_the_invoice {
  all p : Payment | some p.truth implies {
    p.reportedAccount = p.truth.account
    p.reportedRef     = p.truth.ref
  }
}

// Two assumptions about the world. Each one is written down so a reviewer
// can agree with it or reject it.
pred no_foreign_refs {
  all p : Payment | no p.truth implies no (p.reportedRef & Invoice.ref)
}

pred ref_is_unique_per_invoice {
  all disj i1, i2 : Invoice | no (i1.ref & i2.ref)
}

// What the matcher can see: fields present on both sides.
fun candidates [p : Payment] : set Invoice {
  { i : Invoice | some p.reportedRef and i.ref = p.reportedRef and i.account = p.reportedAccount }
}

pred sound [m : Payment -> Invoice] {
  all p : Payment, i : Invoice | p->i in m implies i = p.truth
}

// Rule 1: link every candidate.
fun matched_v1 : Payment -> Invoice {
  { p : Payment, i : Invoice | i in candidates[p] }
}

// Rule 2: link only when exactly one candidate exists.
fun matched_v2 : Payment -> Invoice {
  { p : Payment, i : Invoice | i in candidates[p] and one candidates[p] }
}

// Rule 1 is wrong. Two invoices on one account can carry the same reference
// number, and the rule links the payment to both of them.
assert v1_is_sound {
  no_foreign_refs implies sound[matched_v1]
}
check v1_is_sound for 4 expect 1

// Rule 2 refuses to guess when the candidate is ambiguous, and that is sound.
assert v2_is_sound {
  no_foreign_refs implies sound[matched_v2]
}
check v2_is_sound for 6 expect 0

// The assumption is load bearing. Drop it and rule 2 is wrong again, because
// a payment for an invoice we never issued can still have one lookalike.
assert v2_is_sound_without_assumptions {
  sound[matched_v2]
}
check v2_is_sound_without_assumptions for 4 expect 1

// What rule 2 gives up: it drops the real pair when the number is ambiguous.
assert v2_matches_every_real_pair {
  no_foreign_refs implies
    all p : Payment | (some p.truth and some p.truth.ref) implies p.truth in p.matched_v2
}
check v2_matches_every_real_pair for 4 expect 1

// Those are the only pairs it drops.
assert v2_matches_every_real_pair_when_refs_are_unique {
  (no_foreign_refs and ref_is_unique_per_invoice) implies
    all p : Payment | (some p.truth and some p.truth.ref) implies p.truth in p.matched_v2
}
check v2_matches_every_real_pair_when_refs_are_unique for 6 expect 0

// Guard against a rule that is sound because it never fires.
run v2_can_match { some matched_v2 } for 4 expect 1
