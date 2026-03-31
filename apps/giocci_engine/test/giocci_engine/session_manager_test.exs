defmodule GiocciEngine.SessionManagerTest do
  use ExUnit.Case

  alias GiocciEngine.SessionManager

  describe "parse_env_endpoints/1" do
    test "parses a single endpoint" do
      assert SessionManager.parse_env_endpoints("tcp/192.168.1.100:7447") ==
               ["tcp/192.168.1.100:7447"]
    end

    test "parses multiple comma-separated endpoints" do
      assert SessionManager.parse_env_endpoints("tcp/192.168.1.100:7447,tcp/192.168.1.101:7447") ==
               ["tcp/192.168.1.100:7447", "tcp/192.168.1.101:7447"]
    end

    test "trims whitespace around commas" do
      assert SessionManager.parse_env_endpoints(
               " tcp/192.168.1.100:7447 , tcp/192.168.1.101:7447 "
             ) ==
               ["tcp/192.168.1.100:7447", "tcp/192.168.1.101:7447"]
    end

    test "ignores empty segments from trailing commas" do
      assert SessionManager.parse_env_endpoints("tcp/192.168.1.100:7447,") ==
               ["tcp/192.168.1.100:7447"]
    end
  end
end
