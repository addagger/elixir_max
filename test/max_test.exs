defmodule MAXTest do
  use ExUnit.Case
  doctest MAX

  test "greets the world" do
    assert MAX.hello() == :world
  end
end
