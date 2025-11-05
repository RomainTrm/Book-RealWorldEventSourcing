#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule Batch.ProcessManager do
  use GenServer

  def start_link(%{id: _id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{id: id}) do
    {:ok,
     %{
       id: id,
       files: %{},
       status: :idle
     }}
  end

  def handle_call({:process_event, evt}, _from, state) do
    handle_event(state, evt)
  end

  defp handle_event(
         state,
         %{
           event_type: :batch_created,
           files: files
         }
       ) do
    f = Enum.map(files, fn f -> {f, :pending} end) |> Map.new()

    state = %{
      state
      | files: f,
        status: :created
    }

    reply =
      Enum.map(files, fn f ->
        %{
          command_type: :process_file,
          file: f
        }
      end)

    {:reply, reply, state}
  end

  defp handle_event(state, %{
         event_type: :file_processed,
         file: %{id: file_id, status: file_status}
       }) do
    files = Map.put(state.files, file_id, file_status)

    state = %{
      state
      | files: files,
        status: determine_status(files)
    }

    # To add functionality we could send retry commands for those
    # files that have failed

    {:reply, [], state}
  end

  defp determine_status(file_map) do
    cond do
      Enum.all?(
        file_map,
        fn {_f, status} -> status == :success end
      ) ->
        :success

      Enum.any?(
        file_map,
        fn {_f, status} -> status == :error end
      ) ->
        :error

      true ->
        :pending
    end
  end
end
