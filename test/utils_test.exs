defmodule UtilsTest do
  @moduledoc false

  import Vexil.Utils
  use ExUnit.Case, async: true
  doctest Vexil.Utils

  describe "split_double_dash" do
    test "splits argv on the double dash" do
      assert split_double_dash(["foo", "bar", "--flag", "--", "don't", "capture"]) ==
               {["foo", "bar", "--flag"], ["don't", "capture"]}
    end

    test "has an empty list at the end" do
      assert split_double_dash(["foo", "bar", "--flag", "--"]) ==
               {["foo", "bar", "--flag"], []}
    end

    test "has an empty list at the beginning" do
      assert split_double_dash(["--", "foo", "bar"]) == {[], ["foo", "bar"]}
    end

    test "doesn't split when given `false` to `obey`" do
      assert split_double_dash(["foo", "bar", "--flag", "--", "don't", "capture"], false) ==
               {["foo", "bar", "--flag", "--", "don't", "capture"], []}
    end

    test "doesn't split after the first double dash" do
      assert split_double_dash(["foo", "bar", "--flag", "--", "--", "don't", "capture"]) ==
               {["foo", "bar", "--flag"], ["--", "don't", "capture"]}

      assert split_double_dash(["foo", "bar", "--flag", "--", "don't", "--", "capture"]) ==
               {["foo", "bar", "--flag"], ["don't", "--", "capture"]}

      assert split_double_dash(["foo", "bar", "--flag", "--", "don't", "capture", "--"]) ==
               {["foo", "bar", "--flag"], ["don't", "capture", "--"]}
    end

    test "doesn't split on triple or other amount of dashes" do
      for i <- 3..10 do
        input_and_result = ["foo", "bar", "--flag", String.duplicate("-", i), "don't", "capture"]
        assert split_double_dash(input_and_result) == {input_and_result, []}
      end
    end
  end

  describe "consume_argv_greedy" do
    test "consumes argv until the first dash" do
      assert consume_argv_greedy(["foo", "bar", "--flag", "don't", "capture"]) ==
               {["foo", "bar"], ["--flag", "don't", "capture"]}
    end

    test "consumes argv until the end" do
      assert consume_argv_greedy(["foo", "bar", "do", "capture"]) ==
               {["foo", "bar", "do", "capture"], []}
    end
  end

  describe "split_eq" do
    test "splits on the equals sign" do
      assert split_eq("foo=bar", []) == {"foo", ["bar"]}
      assert split_eq("foo=bar", ["faz", "baz"]) == {"foo", ["bar", "faz", "baz"]}
      assert split_eq("foo=bar faz baz", []) == {"foo", ["bar faz baz"]}
    end

    test "only splits the first equal" do
      assert split_eq("foo=bar=faz", []) == {"foo", ["bar=faz"]}
      assert split_eq("foo=bar=faz", ["baz"]) == {"foo", ["bar=faz", "baz"]}
      assert split_eq("foo=bar=faz=bax", ["baz"]) == {"foo", ["bar=faz=bax", "baz"]}
    end

    test "doesn't do splitting when no equals" do
      assert split_eq("foo bar", []) == {"foo bar", []}
      assert split_eq("foo bar", ["faz", "baz"]) == {"foo bar", ["faz", "baz"]}
    end
  end
end
