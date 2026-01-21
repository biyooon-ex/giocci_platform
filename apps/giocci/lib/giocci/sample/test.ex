defmodule Giocci.Sample.Test do
  @moduledoc false

  require Logger

  def exec(relay_name) do
    :ok = Giocci.register_client(relay_name)
    Logger.info("register_client/1 success!")

    :ok = Giocci.save_module(relay_name, Giocci.Sample.Module)
    Logger.info("save_module/2 success!")

    mfargs = {Giocci.Sample.Module, :add, [1, 2]}

    3 = Giocci.exec_func(relay_name, mfargs)
    Logger.info("exec_func/2 success!")

    :ok = Giocci.exec_func_async(relay_name, mfargs, self())
    Logger.info("exec_func_async/3 success!")

    receive do
      {:giocci, 3} ->
        Logger.info("exec_func_async/3 success!")
    end

    :ok
  end
end
