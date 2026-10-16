defmodule Giocci.UtilsTest do
  use ExUnit.Case
  import Mock

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

  test "inspect replies with locally unknown function names decode safely" do
    name = "unknown_export_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end

    payload = :erlang.term_to_binary({:ok, %{data: [{name, 1}], measurements: %{}}})
    assert {:ok, {:ok, %{data: [{^name, 1}]}}} = Giocci.Utils.decode(payload)
  end

  test "a query with no responder is not a successful empty list" do
    with_mock Zenohex.Session,
      get: fn _, _, _, _ -> {:ok, []} end do
      assert {:error, "connection_failed: " <> _} =
               Giocci.Utils.zenohex_get(
                 :session,
                 "giocci/inspect/relay/missing",
                 100,
                 %{data: %{operation: :list_engines}, measurements: %{}},
                 record_measurements: false
               )
    end
  end

  test "an unexpected number of query replies is an explicit error" do
    with_mock Zenohex.Session,
      get: fn _, _, _, _ ->
        {:ok, [%Zenohex.Sample{payload: <<>>}, %Zenohex.Sample{payload: <<>>}]}
      end do
      assert {:error, "zenohex_error: expected one reply" <> _} =
               Giocci.Utils.zenohex_get(
                 :session,
                 "giocci/inspect/relay/duplicate",
                 100,
                 %{data: %{operation: :list_engines}, measurements: %{}},
                 record_measurements: false
               )
    end
  end
end
