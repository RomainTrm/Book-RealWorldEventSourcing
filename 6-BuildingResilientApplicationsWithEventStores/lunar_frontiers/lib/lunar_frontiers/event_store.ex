defmodule LunarFrontiers.EventStore do
  use EventStore, otp_app: :lunar_frontiers

  def init(config) do
    {:ok, config}
  end
end
