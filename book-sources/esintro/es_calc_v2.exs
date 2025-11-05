#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule EventSourcedCalculator.V2 do
  def handle_command(%{value: _val}, %{cmd: :add, value: v}) do
    %{event_type: :value_added, value: v}
  end

  def handle_command(%{value: _val}, %{cmd: :sub, value: v}) do
    %{event_type: :value_subtracted, value: v}
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
                   %{event_type: :value_subtracted, value: v}) do
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
