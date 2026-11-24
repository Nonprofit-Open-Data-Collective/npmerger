# Leadership and board outcomes for each merger case

Classifies what happened to the two chief executives and the two boards,
from the Part VII panel of
[`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md)
(donor and recipient rosters, t-2..t+2 on each organization's own
calendar).

## Usage

``` r
merger_leadership(part7)
```

## Arguments

- part7:

  The `part7` table from
  [`build_merger_data()`](https://nonprofit-open-data-collective.github.io/npmerger/reference/build_merger_data.md).

## Value

A data.table, one row per `MERGER_ID` with donor, recipient before, and
recipient after rosters: CEO identities and flags, `CEO_CAT`, board
counts and shares, and `BOARD_CAT`.

## Details

**CEO** (one per organization): a person whose title matches CEO,
executive director, president and CEO, administrator, or superintendent
(not deputy, vice, assistant, board, or former), the highest paid if
several; otherwise the highest-paid officer or key employee with pay
above zero. The donor CEO comes from the donor's last roster at or
before t0, and the recipient CEO from the recipient's last roster before
t0. A CEO "remains" when the person appears anywhere on the recipient's
roster at t+1 or t+2.

`CEO_CAT`:

- `recipient_ceo_only`: the recipient CEO remains and the donor CEO does
  not join;

- `both_ceos`: both remain at the recipient;

- `donor_ceo_only`: the donor CEO joins and the recipient CEO leaves;

- `neither`: both are gone;

- `shared_ceo`: the same person led both before the merger, or the donor
  CEO was already on the recipient's roster.

**Board** (trustees and officers, plus 990-EZ listings, which have no
position flags; excludes key employees and highest-paid staff who are
not trustees or officers, and former officers). The recipient board
before is the roster at t-1 (else t-2), after is t+1 (else t+2), and the
donor board is its last roster at or before t0. `BOARD_RETAIN` is the
share of the recipient board still there after; `DONOR_JOINERS` counts
donor members on the board after who were not on it before;
`DONOR_SEAT_SHARE` is their share of seats after.

`BOARD_CAT`:

- `intact_donor_dissolves`: `BOARD_RETAIN >= 0.5` and no donor joiners;

- `combine_minor`: `BOARD_RETAIN >= 0.5`, joiners hold \< 20% of seats;

- `combine_major`: `BOARD_RETAIN >= 0.5`, joiners hold \>= 20% of seats;

- `recipient_turnover`: `BOARD_RETAIN < 0.5`.
