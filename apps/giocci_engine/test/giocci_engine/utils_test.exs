defmodule GiocciEngine.UtilsTest do
  use ExUnit.Case

  defmodule TestModule do
    def add(a, b), do: a + b
    def boom, do: raise("boom")
  end

  test "exec_func returns result on success" do
    assert {:ok, 3} = GiocciEngine.Utils.exec_func({TestModule, :add, [1, 2]})
  end

  test "exec_func returns error for undefined function" do
    assert {:error, "function_not_defined: {String, :nope, []}"} =
             GiocciEngine.Utils.exec_func({String, :nope, []})
  end

  test "exec_func returns error for unexpected exception" do
    assert {:error, message} = GiocciEngine.Utils.exec_func({TestModule, :boom, []})
    assert message =~ "execution_failed"
  end

  test "decode returns term for valid binary" do
    binary = :erlang.term_to_binary(%{ok: true})

    assert {:ok, %{ok: true}} = GiocciEngine.Utils.decode(binary)
  end

  test "decode returns error for invalid binary" do
    assert {:error, "decode_failed"} = GiocciEngine.Utils.decode(<<0, 1, 2>>)
  end
end
