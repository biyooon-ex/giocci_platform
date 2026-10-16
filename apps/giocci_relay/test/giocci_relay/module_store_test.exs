defmodule GiocciRelay.ModuleStoreTest do
  use ExUnit.Case

  setup do
    start_supervised!({GiocciRelay.ModuleStore, []})
    :ok
  end

  test "put/get stores module per client" do
    module_object_code = {GiocciRelay, <<1, 2, 3>>, ~c"giocci_relay.ex"}

    assert :ok = GiocciRelay.ModuleStore.put("client-1", module_object_code)
    assert {:ok, state} = GiocciRelay.ModuleStore.get()
    assert [^module_object_code] = state["client-1"]
  end

  test "put replaces module for same client" do
    old_object_code = {GiocciRelay, <<1>>, ~c"old.ex"}
    new_object_code = {GiocciRelay, <<2>>, ~c"new.ex"}

    assert :ok = GiocciRelay.ModuleStore.put("client-1", old_object_code)
    assert :ok = GiocciRelay.ModuleStore.put("client-1", new_object_code)

    assert {:ok, state} = GiocciRelay.ModuleStore.get()
    assert [^new_object_code] = state["client-1"]
  end

  test "put preserves different modules" do
    object_code_a = {GiocciRelay, <<1>>, ~c"a.ex"}
    object_code_b = {GiocciRelay.ModuleStore, <<2>>, ~c"b.ex"}

    assert :ok = GiocciRelay.ModuleStore.put("client-1", object_code_a)
    assert :ok = GiocciRelay.ModuleStore.put("client-1", object_code_b)

    assert {:ok, state} = GiocciRelay.ModuleStore.get()

    modules = Enum.map(state["client-1"], fn {module, _bin, _file} -> module end)
    assert MapSet.new(modules) == MapSet.new([GiocciRelay, GiocciRelay.ModuleStore])
  end

  test "inspection lists and fetches only the specified client's modules" do
    module_object_code = {GiocciRelay, <<1, 2, 3>>, ~c"giocci_relay.ex"}
    other_object_code = {GiocciRelay.ModuleStore, <<4>>, ~c"module_store.ex"}

    assert {:ok, []} = GiocciRelay.ModuleStore.list("client-1")

    assert {:error, "module_not_found"} =
             GiocciRelay.ModuleStore.fetch("client-1", GiocciRelay)

    assert :ok = GiocciRelay.ModuleStore.put("client-1", module_object_code)
    assert :ok = GiocciRelay.ModuleStore.put("client-2", other_object_code)

    assert {:ok, [GiocciRelay]} = GiocciRelay.ModuleStore.list("client-1")

    assert {:ok, {^module_object_code, %DateTime{time_zone: "Etc/UTC"}}} =
             GiocciRelay.ModuleStore.fetch("client-1", GiocciRelay)

    assert {:error, "module_not_found"} =
             GiocciRelay.ModuleStore.fetch("client-1", GiocciRelay.ModuleStore)
  end

  test "re-saving an identical BEAM updates the saved timestamp without changing the object code" do
    object_code = {GiocciRelay, <<1, 2, 3>>, ~c"giocci_relay.ex"}
    assert :ok = GiocciRelay.ModuleStore.put("client-1", object_code)

    assert {:ok, {^object_code, first_saved_at}} =
             GiocciRelay.ModuleStore.fetch("client-1", GiocciRelay)

    Process.sleep(2)
    assert :ok = GiocciRelay.ModuleStore.put("client-1", object_code)

    assert {:ok, {^object_code, second_saved_at}} =
             GiocciRelay.ModuleStore.fetch("client-1", GiocciRelay)

    assert DateTime.compare(second_saved_at, first_saved_at) == :gt
    assert {:ok, %{"client-1" => [^object_code]}} = GiocciRelay.ModuleStore.get()
  end
end
