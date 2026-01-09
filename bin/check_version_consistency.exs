#!/usr/bin/env elixir

defmodule CheckVersions do
  def run do
    versions = load_versions!()
    errors = []

    errors =
      errors
      |> check_root_dockerfile(versions)
      |> check_apps_dockerfiles(versions)
      |> check_docker_compose(versions)
      |> check_mix_exs(versions)
      |> check_tool_versions(versions)

    if errors == [] do
      IO.puts("version check: OK")
    else
      Enum.each(errors, &IO.puts(:stderr, &1))
      System.halt(1)
    end
  end

  defp load_versions! do
    versions_path = Path.expand("VERSIONS", File.cwd!())

    content =
      case File.read(versions_path) do
        {:ok, data} -> data
        {:error, reason} -> raise "failed to read VERSIONS: #{inspect(reason)}"
      end

    versions =
      content
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        line = String.trim(line)

        cond do
          line == "" -> acc
          String.starts_with?(line, "#") -> acc
          true ->
            case String.split(line, "=", parts: 2) do
              [key, value] ->
                Map.put(acc, String.trim(key), String.trim(value))

              _ ->
                raise "invalid line in VERSIONS: #{line}"
            end
        end
      end)

    required = [
      "ELIXIR_VERSION",
      "ERLANG_VERSION",
      "UBUNTU_VERSION",
      "ZENOH_VERSION",
      "PROJECT_VERSION"
    ]
    missing = Enum.reject(required, &Map.has_key?(versions, &1))

    if missing != [] do
      raise "missing keys in VERSIONS: #{Enum.join(missing, ", ")}"
    end

    versions
  end

  defp check_root_dockerfile(errors, versions) do
    file = "Dockerfile"
    content = File.read!(file)

    base_tag = base_elixir_tag(versions)
    errors =
      check_match(
        errors,
        file,
        content,
        ~r/FROM #{Regex.escape(base_tag)}/,
        "base image mismatch",
        base_tag
      )

    zenoh_version = versions["ZENOH_VERSION"]
    errors =
      check_match(
        errors,
        file,
        content,
        ~r/ARG ZENOH_VERSION=#{Regex.escape(zenoh_version)}/,
        "ZENOH_VERSION mismatch",
        "ZENOH_VERSION=#{zenoh_version}"
      )

    errors
  end

  defp check_apps_dockerfiles(errors, versions) do
    base_tag = base_elixir_tag(versions)
    ubuntu_tag = "ubuntu:" <> versions["UBUNTU_VERSION"]

    Path.wildcard("apps/*/Dockerfile")
    |> Enum.reduce(errors, fn file, acc ->
      content = File.read!(file)

      acc =
        check_match(
          acc,
          file,
          content,
          ~r/FROM #{Regex.escape(base_tag)}/,
          "base image mismatch",
          base_tag
        )

      check_match(
        acc,
        file,
        content,
        ~r/FROM #{Regex.escape(ubuntu_tag)}/,
        "runner image mismatch",
        ubuntu_tag
      )
    end)
  end

  defp check_docker_compose(errors, versions) do
    file = "docker-compose.yml"
    content = File.read!(file)
    zenoh_version = versions["ZENOH_VERSION"]

    check_match(
      errors,
      file,
      content,
      ~r/image:\s+\S*zenohd:#{Regex.escape(zenoh_version)}/,
      "zenohd image tag mismatch",
      "zenohd:#{zenoh_version}"
    )
  end

  defp check_mix_exs(errors, versions) do
    project_version = versions["PROJECT_VERSION"]

    files = Path.wildcard("apps/*/mix.exs")

    {errors, elixir_entries} =
      Enum.reduce(files, {errors, []}, fn file, {acc, entries} ->
        content = File.read!(file)

        acc =
          check_match(
            acc,
            file,
            content,
            ~r/version:\s*\"#{Regex.escape(project_version)}\"/,
            "project version mismatch",
            project_version
          )

        case Regex.run(~r/elixir:\s*\"([^\"]+)\"/, content, capture: :all_but_first) do
          [req] -> {acc, [{file, req} | entries]}
          _ -> {[ "#{file}: elixir requirement not found" | acc ], entries}
        end
      end)

    check_consistency(errors, "elixir requirement mismatch", elixir_entries)
  end

  defp check_tool_versions(errors, versions) do
    file = ".tool-versions"
    content = File.read!(file)

    elixir_version = versions["ELIXIR_VERSION"]
    erlang_version = versions["ERLANG_VERSION"]
    erlang_major = erlang_major(erlang_version)

    errors =
      check_match(
        errors,
        file,
        content,
        ~r/^erlang\s+#{Regex.escape(erlang_version)}$/m,
        "erlang tool version mismatch",
        "erlang #{erlang_version}"
      )

    check_match(
      errors,
      file,
      content,
      ~r/^elixir\s+#{Regex.escape(elixir_version)}-otp-#{Regex.escape(erlang_major)}$/m,
      "elixir tool version mismatch",
      "elixir #{elixir_version}-otp-#{erlang_major}"
    )
  end

  defp base_elixir_tag(versions) do
    "hexpm/elixir:" <>
      versions["ELIXIR_VERSION"] <>
      "-erlang-" <>
      versions["ERLANG_VERSION"] <>
      "-ubuntu-" <>
      versions["UBUNTU_VERSION"]
  end

  defp check_consistency(errors, message, entries) do
    case Enum.uniq_by(entries, fn {_file, value} -> value end) do
      [] ->
        errors

      [{_file, _value}] ->
        errors

      _ ->
        formatted =
          entries
          |> Enum.map(fn {file, value} -> "#{file}: #{value}" end)
          |> Enum.join(", ")

        ["#{message}: #{formatted}" | errors]
    end
  end

  defp erlang_major(version) do
    case String.split(version, ".") do
      [major | _] -> major
      _ -> version
    end
  end

  defp check_match(errors, file, content, regex, message, expected) do
    if Regex.match?(regex, content) do
      errors
    else
      ["#{file}: #{message} (expected: #{expected})" | errors]
    end
  end
end

CheckVersions.run()
