defmodule VexilTest do
  @moduledoc false

  alias Vexil.Structs
  use ExUnit.Case, async: true
  doctest Vexil

  describe "parse/2" do
    test "passes through argv when no options or flags" do
      assert Vexil.parse(["foo", "bar"]) ==
               {:ok, %{argv: ["foo", "bar"], flags: [], options: []}, {[], []}}
    end

    test "parses a simple flag" do
      flags = [
        foo: %Structs.Flag{
          short: "f",
          long: "foo"
        }
      ]

      assert Vexil.parse(["--foo"], flags: flags) ==
               {:ok, %{argv: [], flags: [foo: true], options: []}, {[], []}}

      assert Vexil.parse(["-f"], flags: flags) ==
               {:ok, %{argv: [], flags: [foo: true], options: []}, {[], []}}

      assert Vexil.parse(["before", "--foo", "after"], flags: flags) ==
               {:ok, %{argv: ["before", "after"], flags: [foo: true], options: []}, {[], []}}

      assert Vexil.parse(["before", "-f", "after"], flags: flags) ==
               {:ok, %{argv: ["before", "after"], flags: [foo: true], options: []}, {[], []}}
    end

    test "parses multiple sequential flags" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo"
      }

      bar = %Structs.Flag{
        short: "b",
        long: "bar"
      }

      qux = %Structs.Flag{
        short: "q",
        long: "qux"
      }

      xyzzy = %Structs.Flag{
        short: "x",
        long: "xyzzy"
      }

      two = [foo: foo, bar: bar]
      three = [foo: foo, bar: bar, qux: qux]
      four = [foo: foo, bar: bar, qux: qux, xyzzy: xyzzy]

      # TODO: theres probably a way to automate all these with some sort of loop
      # Maybe use stream_data

      assert Vexil.parse(["--foo", "--bar"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["--foo", "--bar", "--qux"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["--foo", "--bar", "--qux", "--xyzzy"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}

      # And now test all the short flags
      assert Vexil.parse(["-f", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-b", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-b", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}

      # And now test several mixes of short and long flags
      assert Vexil.parse(["-f", "--bar"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "--bar", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "--bar", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}

      assert Vexil.parse(["--foo", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["--foo", "-b", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["--foo", "-b", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}

      assert Vexil.parse(["-f", "--bar", "--qux"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "--bar", "--qux", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}
    end

    test "parses short flags grouped in one section" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo"
      }

      bar = %Structs.Flag{
        short: "b",
        long: "bar"
      }

      qux = %Structs.Flag{
        short: "q",
        long: "qux"
      }

      xyzzy = %Structs.Flag{
        short: "x",
        long: "xyzzy"
      }

      two = [foo: foo, bar: bar]
      three = [foo: foo, bar: bar, qux: qux]
      four = [foo: foo, bar: bar, qux: qux, xyzzy: xyzzy]

      assert Vexil.parse(["-fb"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-fbq"], flags: three) ==
               {:ok, %{argv: [], flags: [foo: true, bar: true, qux: true], options: []}, {[], []}}

      assert Vexil.parse(["-fbqx"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}

      assert Vexil.parse(["-fb", "-qx"], flags: four) ==
               {:ok,
                %{argv: [], flags: [foo: true, bar: true, qux: true, xyzzy: true], options: []},
                {[], []}}
    end

    test "flags marked as multiple get accumulated" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo",
        multiple: true
      }

      bar = %Structs.Flag{
        short: "b",
        long: "bar"
      }

      one = [foo: foo]
      two = [foo: foo, bar: bar]

      assert Vexil.parse(["-f"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 1], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 2], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-f", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 3], options: []}, {[], []}}

      assert Vexil.parse(["-ff"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 2], options: []}, {[], []}}

      assert Vexil.parse(["-fff"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 3], options: []}, {[], []}}

      assert Vexil.parse(["-ff", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: [foo: 3], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: 1, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-f", "-b", "-f"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: 2, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-ffb"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: 2, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-fbf"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: 2, bar: true], options: []}, {[], []}}

      assert Vexil.parse(["-bf"], flags: two) ==
               {:ok, %{argv: [], flags: [bar: true, foo: 1], options: []}, {[], []}}
    end

    test "has an error in the relevant list when seeing an unknown flag" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo",
        multiple: true
      }

      flags = [foo: foo]

      # Need to use groups to test this as it gets seen as an option otherwise
      assert Vexil.parse(["-fb"], flags: []) ==
               {:ok, %{argv: [], flags: [], options: []},
                {[], [{:error, :unknown_flag, "b"}, {:error, :unknown_flag, "f"}]}}

      assert Vexil.parse(["-fb"], flags: flags) ==
               {:ok, %{argv: [], flags: [foo: 1], options: []},
                {[], [{:error, :unknown_flag, "b"}]}}

      assert Vexil.parse(["--foo", "-fb"], flags: flags) ==
               {:ok, %{argv: [], flags: [foo: 2], options: []},
                {[], [{:error, :unknown_flag, "b"}]}}
    end

    test "returns only an error when seeing an unknown flag when told to error early" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo",
        multiple: true
      }

      flags = [foo: foo]

      assert Vexil.parse(["-fb"], flags: [], error_early: true) ==
               {:error, :unknown_flag, "f"}

      assert Vexil.parse(["-fb"], flags: flags, error_early: true) ==
               {:error, :unknown_flag, "b"}

      assert Vexil.parse(["--foo", "-fb"], flags: flags, error_early: true) ==
               {:error, :unknown_flag, "b"}
    end

    test "has an error in the relevant list when seeing a duplicate flag" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo",
        multiple: true
      }

      bar = %Structs.Flag{
        short: "b",
        long: "bar"
      }

      one = [bar: bar]
      two = [foo: foo, bar: bar]

      assert Vexil.parse(["--bar", "--bar"], flags: one) ==
               {:ok, %{argv: [], flags: [bar: true], options: []},
                {[], [{:error, :duplicate_flag, :bar}]}}

      assert Vexil.parse(["-b", "-b"], flags: one) ==
               {:ok, %{argv: [], flags: [bar: true], options: []},
                {[], [{:error, :duplicate_flag, :bar}]}}

      assert Vexil.parse(["--bar", "-b"], flags: one) ==
               {:ok, %{argv: [], flags: [bar: true], options: []},
                {[], [{:error, :duplicate_flag, :bar}]}}

      assert Vexil.parse(["-bb"], flags: one) ==
               {:ok, %{argv: [], flags: [bar: true], options: []},
                {[], [{:error, :duplicate_flag, :bar}]}}

      assert Vexil.parse(["--foo", "--bar", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: [foo: 1, bar: true], options: []},
                {[], [{:error, :duplicate_flag, :bar}]}}
    end
  end
end
