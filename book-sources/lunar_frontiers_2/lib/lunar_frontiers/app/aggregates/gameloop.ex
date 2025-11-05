#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Aggregates.Gameloop do
  alias LunarFrontiers.App.Aggregates.Gameloop
  alias LunarFrontiers.App.Events.GameloopAdvanced
  alias LunarFrontiers.App.Commands.AdvanceGameloop
  alias __MODULE__

  defstruct [
    :game_id,
    :tick
  ]

  def execute(%Gameloop{} = _loop,
    %AdvanceGameloop{tick: tick, game_id: id}) do
    event = %GameloopAdvanced{
      game_id: id,
      tick: tick
    }

    {:ok, event}
  end

  def apply(%Gameloop{} = _loop,
    %GameloopAdvanced{tick: tick, game_id: id}) do
    %Gameloop{
      game_id: id,
      tick: tick
    }
  end
end
