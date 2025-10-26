defmodule Calculator do
  def handle_command(%{value: val}, %{cmd: :add, value: v}) do
    %{value: val + v}
  end

  def handle_command(%{value: val}, %{cmd: :min, value: v}) do
    %{value: val - v}
  end

  def handle_command(%{value: val}, %{cmd: :mul, value: v}) do
    %{value: val * v}
  end

  def handle_command(%{value: val}, %{cmd: :div, value: v}) do
    %{value: val / v}
  end
end
