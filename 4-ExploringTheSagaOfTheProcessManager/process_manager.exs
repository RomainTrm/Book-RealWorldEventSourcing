defmodule Batch.ProcessManager do
  use GenServer

  def start_link(%{id: _id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{id: id}) do
    state = %{id: id, files: %{}, status: :idle}
    {:ok, state}
  end

  def handle_call({:process_event, evt}, _from, state) do
    handle_event(state, evt)
  end

  defp handle_event(state, %{event_type: :batch_created, files: files}) do
    f = Enum.map(files, fn f -> {f, :peding} end) |> Map.new()
    state = %{state | files: f, status: :created}
    reply = Enum.map(files, fn f -> %{command_type: :process_file, file: f} end)
    {:reply, reply, state}
  end

  defp handle_event(state, %{
    event_type: :file_processed,
    file: %{id: file_id, status: file_status}
  }) do
    files = Map.put(state.files, file_id, file_status)
    state = %{state | files: files, status: determine_status(files)}

    # We could send retry commands to files that have failed
    {:reply, [], state}
  end

  defp determine_status(files) do
    cond do
      Enum.all?(files, fn {_f, status} -> status == :success end) -> :success
      Enum.any?(files, fn {_f, status} -> status == :error end) -> :error
      true -> :pending
    end
  end
end
