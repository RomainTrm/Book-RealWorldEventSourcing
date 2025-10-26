defmodule Calculator do
  @max_value 10_000
  @min_value 0

  def handle_command(%{value: val}, %{cmd: :add, value: v}) do
    value = min(@max_value - val, v)
    %{event_type: :value_added, value: value}
  end

  def handle_command(%{value: val}, %{cmd: :min, value: v}) do
    value = max(@min_value, val - v)
    %{event_type: :value_substracted, value: value}
  end

  def handle_command(%{value: val}, %{cmd: :mul, value: v})
    when val * v > @max_value do
    %{error: :multiply_failed}
  end

  def handle_command(%{value: _val}, %{cmd: :mul, value: v}) do
    %{event_type: :value_multiplied, value: v}
  end

  def handle_command(%{value: _val}, %{cmd: :div, value: 0}) do
    %{error: :divide_failed}
  end

  def handle_command(%{value: _val}, %{cmd: :div, value: v}) do
    %{event_type: :value_divided, value: v}
  end

  def handle_event(%{value: val},
                   %{event_type: :value_added, value: v}) do
    %{value: val + v}
  end

  def handle_event(%{value: val},
                   %{event_type: :value_substracted, value: v}) do
    %{value: val - v}
  end

  def handle_event(%{value: val},
                   %{event_type: :value_multiplied, value: v}) do
    %{value: val * v}
  end

  def handle_event(%{value: val},
                   %{event_type: :value_divided, value: v}) do
    %{value: val / v}
  end

  def handle_event(%{value: _val} = state, _event) do
    state
  end
end
