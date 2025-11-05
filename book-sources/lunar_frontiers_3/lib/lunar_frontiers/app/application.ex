#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Application do
  require Logger

  use Commanded.Application, otp_app: :lunar_frontiers

  router(LunarFrontiers.App.Router)

  # Provide / Override runtime configuration
  def init(config) do
    Logger.info("Starting Lunar Frontiers Event Sourcing App")
    {:ok, config}
  end
end
