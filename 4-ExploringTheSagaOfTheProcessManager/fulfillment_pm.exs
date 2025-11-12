defmodule OrderFulfillment.ProcessManager do
  use GenServer

  def start_link(%{id: _id} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{id: id}) do
    {:ok, %{id: id, status: :created, items: []}}
  end

  def handle_call({:process_event, evt}, _from, state) do
    handle_event(state, evt)
  end

  defp handle_event(state, %{event_type: :order_created, items: order_items}) do
    cmds = Enum.map(order_items, fn item ->
      %{command_type: :reserve_quantity, aggregate: :stock_unit, quantity: item.quantity, sku: item.sku}
    end)

    state = %{state | status: :created, items: order_items}
    {:reply, cmds, state}
  end

  defp handle_event(state, %{event_type: :payment_approved, order_id: oid}) do
    cmd = %{command_type: :ship_order, aggregate: :order, order_id: oid}
    state = %{state | status: :shipping}
    {:reply, [cmd], state}
  end

  defp handle_event(state, %{event_type: :payment_declined}) do
    state = %{state | status: :paymend_failure}
    {:reply, [], state}
  end

  defp handle_event(_state, %{event_type: :order_canceled}) do
    {:stop, :normal, [], %{}}
  end

  defp handle_event(state, %{event_type: :order_shipped}) do
    cmds = Enum.map(state.items, fn item ->
      %{command_type: :remove_quantity, aggregate: :stock_unit, quanitty: item.quantity, sku: item.sku}
    end)

    {:stop, :normal, cmds, %{}}
  end

  defp handle_event(state, %{event_type: :payment_details_updated}) do
    cmd = %{command_type: :ship_order, aggregate: :order, order_id: state.id}
    state = %{state | status: :shipping}
    {:reply, [cmd], state}
  end
end
