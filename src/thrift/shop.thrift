namespace java com.stripe.thrift

struct Musician {
  1: required string name
  2: optional double net_worth
  3: optional bool is_grammy_winner
} (
  responsibleTeam = "Carmen"
)