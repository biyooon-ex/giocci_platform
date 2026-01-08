defmodule GiocciRelay.UtilsTest do
  use ExUnit.Case

  test "decode returns term for valid binary" do
    binary = :erlang.term_to_binary(%{ok: true})

    assert {:ok, %{ok: true}} = GiocciRelay.Utils.decode(binary)
  end

  test "decode returns error for invalid binary" do
    assert {:error, :decode_failed} = GiocciRelay.Utils.decode(<<0, 1, 2>>)
  end
end
