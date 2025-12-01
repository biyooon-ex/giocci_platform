defmodule GiocciClientTest do
  use ExUnit.Case
  doctest GiocciClient

  test "greets the world" do
    assert GiocciClient.hello() == :world
  end
end
