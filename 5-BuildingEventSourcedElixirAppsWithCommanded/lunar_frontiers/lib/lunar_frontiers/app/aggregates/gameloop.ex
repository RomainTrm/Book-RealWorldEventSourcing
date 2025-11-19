defmodule LunarFrontiers.App.Aggregates.Gameloop do
  alias LunarFrontiers.App.Commands.AdvanceGameloop
  alias LunarFrontiers.App.Events.GameloopAdvanced
  alias __MODULE__

  defstruct [:game_id, :tick]

  def execute(%Gameloop{}, %AdvanceGameloop{} = cmd) do
    evt = %GameloopAdvanced{
      game_id: cmd.game_id, tick: cmd.tick
    }
    {:ok, evt}
  end

  def apply(%Gameloop{}, %GameloopAdvanced{} = evt) do
    %Gameloop{
      game_id: evt.game_id, tick: evt.tick
    }
  end
end
