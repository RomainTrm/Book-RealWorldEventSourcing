defmodule UserProvisioning.ProcessManager do
  use GenServer

  def start_link(%{user_id: _id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{user_id: id}) do
    state = %{user_id: id, status: :idle, avatar_generation_status: :unknown, db_provisioning_status: :unknown}
    {:ok, state}
  end

  def handle_call({:process_event, evt}, _from, state) do
    handle_event(state, evt)
  end

  defp handle_event(state, %{event_type: :new_user_created}) do
    cmds = [
      %{command_type: :provision_user_db, aggregate: :user, user_id: state.user_id},
      %{command_type: :generate_avatar, aggregate: :user, user_id: state.user_id}
    ]
    state = %{state | status: :processing}
    {:reply, cmds, state}
  end

  defp handle_event(state, %{event_type: :avatar_generation_started}) do
    {:reply, [], state}
  end

  defp handle_event(state, %{event_type: :db_provisioning_started}) do
    {:reply, [], state}
  end

  defp handle_event(state, %{event_type: :db_provisioning_passed}) do
    cmds = cond do
      state.avatar_generation_status == :passed -> [
        %{command_type: :notify_user_provisioning_succeeded, aggregate: :user, user_id: state.user_id}
      ]
      state.avatar_generation_status == :failed -> [
        %{command_type: :notify_user_provisioning_failed, aggregate: :user, user_id: state.user_id}
      ]
      true -> []
    end
    state = %{state | db_provisioning_status: :passed}
    {:reply, cmds, state}
  end

  defp handle_event(state, %{event_type: :db_provisioning_failed}) do
    cmds = cond do
      state.avatar_generation_status == :unknown -> []
      true -> [
        %{command_type: :notify_user_provisioning_failed, aggregate: :user, user_id: state.user_id}
      ]
    end
    state = %{state | db_provisioning_status: :passed}
    {:reply, cmds, state}
  end

  defp handle_event(state, %{event_type: :avatar_generation_passed}) do
    cmds = cond do
      state.db_provisioning_status == :passed -> [
        %{command_type: :notify_user_provisioning_succeeded, aggregate: :user, user_id: state.user_id}
      ]
      state.db_provisioning_status == :failed -> [
        %{command_type: :notify_user_provisioning_failed, aggregate: :user, user_id: state.user_id}
      ]
      true -> []
    end
    state = %{state | avatar_generation_status: :passed}
    {:reply, cmds, state}
  end

  defp handle_event(state, %{event_type: :avatar_generation_failed}) do
    cmds = cond do
      state.db_provisioning_status == :unknown -> []
      true -> [
        %{command_type: :notify_user_provisioning_failed, aggregate: :user, user_id: state.user_id}
      ]
    end
    state = %{state | avatar_generation_status: :failed}
    {:reply, cmds, state}
  end

  defp handle_event(_, %{event_type: :user_provisioning_succeeded}) do
    {:stop, :normal, [], %{}}
  end

  defp handle_event(_, %{event_type: :user_provisioning_failed}) do
    {:stop, :normal, [], %{}}
  end
end
