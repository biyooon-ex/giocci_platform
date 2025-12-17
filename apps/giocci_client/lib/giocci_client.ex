defmodule GiocciClient do
  @moduledoc """
  Documentation for `GiocciClient`.
  """

  @doc """
  """
  @spec register_client(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate register_client(relay_name, opts \\ []), to: GiocciClient.Worker

  @doc """
  """
  @spec save_module(String.t(), module(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate save_module(relay_name, module, opts \\ []), to: GiocciClient.Worker

  @doc """
  """
  @spec exec_func(String.t(), tuple(), keyword()) ::
          {:ok, result :: term()} | {:error, reason :: term()}
  defdelegate exec_func(relay_name, mfargs, opts \\ []), to: GiocciClient.Worker

  @doc """
  """
  @spec exec_func_async(String.t(), tuple(), GenServer.server(), keyword()) ::
          :ok | {:error, reason :: term()}
  defdelegate exec_func_async(relay_name, mfargs, server, opts \\ []), to: GiocciClient.Worker
end
