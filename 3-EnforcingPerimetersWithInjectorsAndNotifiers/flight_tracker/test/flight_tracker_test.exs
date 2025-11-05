defmodule FlightTrackerTest do
  use ExUnit.Case
  doctest FlightTracker

  test "greets the world" do
    assert FlightTracker.hello() == :world
  end
end
