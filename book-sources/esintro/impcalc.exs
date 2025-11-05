#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule Calculator do
  def add(x, y) do
    x + y
  end

  def mul(x, y) do
    x * y
  end

  def div(x, y) do
    x / y
  end

  def sub(x, y) do
    x - y
  end
end
