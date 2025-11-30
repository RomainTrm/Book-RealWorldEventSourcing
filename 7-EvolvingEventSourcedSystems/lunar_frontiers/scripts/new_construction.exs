#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
# from the parent directory, execute via:
# iex -S mix run scripts/single_site.exs

alias LunarFrontiers.App.Commands
import LunarFrontiers.App.Application

player_id = "newplayer_alice"
gid = UUID.uuid4()
b1id = UUID.uuid4()
b2id = UUID.uuid4()

IO.puts "New game #{gid}, going to build #{b1id} and #{b2id}"

dispatch(%Commands.StartGame{game_id: gid})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 1})


dispatch(%Commands.SpawnBuilding.V2{
  completion_ticks: 5,
  location: 1,
  player_id: player_id,
  site_id: b1id,
  site_type: :oxygen_generator,
  tick: 1,
  game_id: gid
})

dispatch(%Commands.SpawnBuilding.V2{
  completion_ticks: 3,
  location: 1,
  player_id: player_id,
  site_id: b2id,
  site_type: :power_generator,
  tick: 1,
  game_id: gid
})

# Advance the game enough to finish both construction processes
[2..8]
|> Enum.each(fn tick ->
  dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: tick})
end)

# Now check the key `buildings:{guid}` for each of the buildings
# in Redis to verify the final projection
