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

player_id = "px42"

gid = UUID.uuid4()
sid = UUID.uuid4()

IO.puts "New game #{gid}, going to build site #{sid}"

dispatch(%Commands.StartGame{game_id: gid})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 1})

dispatch(%Commands.SpawnSite{
  completion_ticks: 5,
  location: 1,
  player_id: player_id,
  site_id: sid,
  site_type: 1,
  tick: 1,
  game_id: gid
})

dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 2})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 3})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 4})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 5})
dispatch(%Commands.AdvanceGameloop{game_id: gid, tick: 6})
