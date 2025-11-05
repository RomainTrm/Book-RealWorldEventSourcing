defmodule FlightTracker.FileInjector do
  alias FlightTracker.MessageBroadcaster
  use GenServer
  require Logger

  def start_link(file) do
    GenServer.start_link(__MODULE__, file, name: __MODULE__)
  end

  @impl true
  def init(file) do
    Process.send_after(self(), :read_file, 2_000)
    {:ok, file}
  end

  @impl true
  def handle_info(:read_file, file) do
    File.stream!(file)
    |> Enum.map(&String.trim/1)
    |> Enum.each(fn evt -> MessageBroadcaster.broadcast_event(evt) end)

    {:noreply, file}
  end
end
