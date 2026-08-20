/*
 * Applying ledger entries, where an entry can be reversed later.
 * The property under test: an entry is never posted twice.
 *
 * Run it:  java -jar alloy.jar exec -f -t text posting.als
 */

sig Line {}

var sig posted   in Line {}
var sig reversed in Line {}

fact init {
  no posted
  no reversed
}

// The lax rule only checks that the line is not currently posted.
pred post_lax [l : Line] {
  l not in posted
  posted'   = posted + l
  reversed' = reversed
}

// The safe rule also refuses a line that was already taken back.
pred post_safe [l : Line] {
  l not in posted
  l not in reversed
  posted'   = posted + l
  reversed' = reversed
}

pred reverse [l : Line] {
  l in posted
  reversed' = reversed + l
  posted'   = posted - l
}

pred stutter {
  posted'   = posted
  reversed' = reversed
}

pred next_lax  { (some l : Line | post_lax[l]  or reverse[l]) or stutter }
pred next_safe { (some l : Line | post_safe[l] or reverse[l]) or stutter }

// A takeback makes the line unposted again, so the lax rule posts it twice.
assert lax_never_posts_twice {
  always next_lax implies
    all l : Line | always (post_lax[l] implies after always not post_lax[l])
}
check lax_never_posts_twice for 2 but 5 steps expect 1

assert safe_never_posts_twice {
  always next_safe implies
    all l : Line | always (post_safe[l] implies after always not post_safe[l])
}
check safe_never_posts_twice for 3 but 10 steps expect 0

// The same property proved by induction instead of by walking traces.
// Two short checks stand in for every trace of any length.
pred inv {
  no (posted & reversed)
}

assert inv_holds_initially { inv }
check inv_holds_initially for 6 but 1 steps expect 0

assert inv_survives_every_step {
  (inv and next_safe) implies after inv
}
check inv_survives_every_step for 6 but 2 steps expect 0

// Guard against a rule that is safe because nothing ever happens.
run something_happens {
  always next_safe
  eventually some reversed
} for 2 but 5 steps expect 1
