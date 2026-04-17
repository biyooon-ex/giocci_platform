defmodule MixHelpers do
  @doc """
  Load and parse a VERSIONS file into a map of key => value strings.
  Raises if the file cannot be read.
  """
  def load_versions!(versions_path) do
    case File.read(versions_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, "=", parts: 2) do
            [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
            _ -> acc
          end
        end)

      {:error, reason} ->
        raise "Failed to read VERSIONS at #{versions_path}: #{inspect(reason)}"
    end
  end
end
