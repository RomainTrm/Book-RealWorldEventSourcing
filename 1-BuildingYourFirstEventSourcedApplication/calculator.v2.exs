defmodule Calculator do
  def handle_command(%{value: _val}, %{cmd: :add, value: v}) do
    %{event_type: :value_added, value: v}
  end

  def handle_command(%{value: _val}, %{cmd: :min, value: v}) do
    %{event_type: :value_substracted, value: v}
  end

  def handle_command(%{value: _val}, %{cmd: :mul, value: v}) do
    %{event_type: :value_multiplied, value: v}
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
end
