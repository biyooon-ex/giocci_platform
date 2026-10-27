defmodule Giocci.DynamicModule do
  @moduledoc """
  Retains the BEAM for a module compiled without a file on the code path.

  Use this inside modules defined in IEx, Livebook, or with `Code.compile_string/2`
  before calling `Giocci.save_module/3`. Include it again when redefining the
  module. Only the latest compilation is retained for each module until this
  VM exits. Modules compiled to BEAM files do not need to use this module.
  """

  defmacro __using__(_opts) do
    quote do
      @after_compile Giocci.DynamicModule
    end
  end

  @doc false
  def __after_compile__(env, beam) do
    {:ok, {module, md5}} = :beam_lib.md5(beam)
    object_code = {module, beam, String.to_charlist(env.file)}

    :persistent_term.put({__MODULE__, module}, {object_code, md5})
  end

  @doc false
  @spec object_code(module()) ::
          {module(), binary(), :file.filename()} | :error | {:error, String.t()}
  def object_code(module) do
    case :persistent_term.get({__MODULE__, module}, :error) do
      :error ->
        :code.get_object_code(module)

      {object_code, md5} ->
        if Code.ensure_loaded?(module) and module.module_info(:md5) == md5 do
          object_code
        else
          {:error, "dynamic_module_stale"}
        end
    end
  end
end
