defmodule GiocciRelay.EngineSelectionPolicy do
  @moduledoc """
  Selects an Engine from the Relay's registered candidates.

  The Relay calls `candidates_changed/3` whenever registration changes the
  candidate list, and serializes all callbacks through the EngineRegistrar.
  """

  @callback init(keyword()) :: {:ok, term()} | {:error, term()}
  @callback candidates_changed([String.t()], [String.t()], term()) :: term()
  @callback select([String.t()], map(), term()) ::
              {:ok, String.t(), term()} | {:error, term()}
end
