defmodule Giocci.UtilsTest do
  use ExUnit.Case

  test "encode returns binary" do
    assert {:ok, binary} = Giocci.Utils.encode(%{ok: true})
    assert is_binary(binary)
  end

  test "decode returns term for valid binary" do
    binary = :erlang.term_to_binary(%{ok: true})

    assert {:ok, %{ok: true}} = Giocci.Utils.decode(binary)
  end

  test "decode returns error for invalid binary" do
    assert {:error, "decode_failed: payload may contain unknown atoms or unsafe terms"} =
             Giocci.Utils.decode(<<0, 1, 2>>)
  end
end
