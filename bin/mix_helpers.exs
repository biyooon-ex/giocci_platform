defmodule MixHelpers do
  @doc """
  Loads the VERSIONS file and returns a map of key-value pairs.

  Falls back to dummy versions when the DEPENDABOT environment variable is set
  and the file is missing (Dependabot clones may not include all files).
  """
  def load_versions!(versions_path) do
    if File.exists?(versions_path) do
      versions_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        line = String.trim(line)

        cond do
          line == "" ->
            acc

          String.starts_with?(line, "#") ->
            acc

          true ->
            case String.split(line, "=", parts: 2) do
              [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
              _ -> acc
            end
        end
      end)
    else
      case System.get_env("DEPENDABOT") do
        "true" ->
          IO.warn(
            "VERSIONS file not found at #{versions_path}; using dummy versions for Dependabot environment"
          )

          %{"PROJECT_VERSION" => "0.1.0-dependabot", "ZENOHEX_VERSION" => "0.8.0"}

        _ ->
          raise("VERSIONS file not found at #{versions_path}")
      end
    end
  end
end
