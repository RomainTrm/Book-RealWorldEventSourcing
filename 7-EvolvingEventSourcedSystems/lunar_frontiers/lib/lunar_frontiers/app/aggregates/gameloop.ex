defmodule LunarFrontiers.App.Aggregates.Gameloop do
  alias LunarFrontiers.App.Commands.{
    AdvanceGameloop,
    StartGame
  }
  alias LunarFrontiers.App.Events.{
    GameloopAdvanced,
    GameStarted
  }
  alias __MODULE__

  defstruct [:game_id, :tick]

  def execute(%Gameloop{}, %StartGame{} = cmd) do
    evt = %GameStarted{game_id: cmd.game_id}
    {:ok, evt}
  end

  def execute(%Gameloop{}, %AdvanceGameloop{} = cmd) do
    evt = %GameloopAdvanced{
      game_id: cmd.game_id, tick: cmd.tick
    }
    {:ok, evt}
  end

  def apply(%Gameloop{}, %GameStarted{} = evt) do
    %Gameloop{
      game_id: evt.game_id, tick: 0
    }
  end

  def apply(%Gameloop{}, %GameloopAdvanced{} = evt) do
    %Gameloop{
      game_id: evt.game_id, tick: evt.tick
    }
  end
end
