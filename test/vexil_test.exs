defmodule VexilTest do
  @moduledoc false

  alias Vexil.{Errors, Structs}
  use ExUnit.Case, async: true
  doctest Vexil

  describe "parse/2" do
    @describetag :parse

    test "passes through argv when no options or flags" do
      assert Vexil.parse(["foo", "bar"]) ==
               {:ok, %{argv: ["foo", "bar"], flags: %{}, options: %{}}, {[], []}}
    end

    test "returns an error when flags aren't a keyword list" do
      assert Vexil.parse(["foo"], flags: %{}) == {:error, :flags_not_keywords}
      assert Vexil.parse(["foo"], flags: "") == {:error, :flags_not_keywords}
      assert Vexil.parse(["foo"], flags: 'foobar') == {:error, :flags_not_keywords}
      assert Vexil.parse(["foo"], flags: [:foo]) == {:error, :flags_not_keywords}
    end

    test "returns an error when options aren't a keyword list" do
      assert Vexil.parse(["foo"], options: %{}) == {:error, :options_not_keywords}
      assert Vexil.parse(["foo"], options: "") == {:error, :options_not_keywords}
      assert Vexil.parse(["foo"], options: 'foobar') == {:error, :options_not_keywords}
      assert Vexil.parse(["foo"], options: [:foo]) == {:error, :options_not_keywords}
    end

    test "returns an error when there's a bad item given as a flag" do
      assert Vexil.parse(["foo"], flags: [foo: %{}]) == {:error, :invalid_flag, :foo}
      assert Vexil.parse(["foo"], flags: [foo: ""]) == {:error, :invalid_flag, :foo}
      assert Vexil.parse(["foo"], flags: [foo: '']) == {:error, :invalid_flag, :foo}
      assert Vexil.parse(["foo"], flags: [foo: []]) == {:error, :invalid_flag, :foo}
    end

    test "returns an error when there's a bad item given as a option" do
      assert Vexil.parse(["foo"], options: [foo: %{}]) == {:error, :invalid_option, :foo}
      assert Vexil.parse(["foo"], options: [foo: ""]) == {:error, :invalid_option, :foo}
      assert Vexil.parse(["foo"], options: [foo: '']) == {:error, :invalid_option, :foo}
      assert Vexil.parse(["foo"], options: [foo: []]) == {:error, :invalid_option, :foo}
    end

    test "returns an error when there's conflicting long/short names between flags and options" do
      flags = [
        bar: %Structs.Flag{
          short: "b",
          long: "bar"
        },
        foo: %Structs.Flag{
          short: "f",
          long: "foo"
        }
      ]

      options = [
        baz: %Structs.Option{
          short: "B",
          long: "baz"
        },
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      options2 = [
        baz: %Structs.Option{
          short: "B",
          long: "baz"
        },
        foo: %Structs.Option{
          short: "F",
          long: "foo"
        }
      ]

      assert Vexil.parse(["foo"], flags: flags, options: options) ==
               {:error, :conflicting_key, "f"}

      assert Vexil.parse(["foo"], flags: flags, options: options2) ==
               {:error, :conflicting_key, "foo"}
    end

    test "returns an error when an option is required and has a default" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          required: true,
          default: "bar"
        }
      ]

      assert Vexil.parse(["foo"], options: options) ==
               {:error, :required_option_has_default, :foo}
    end

    test "returns an error when an option has a parser that isn't built in nor a function" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :my_epic_parser
        }
      ]

      assert Vexil.parse(["foo"], options: options) ==
               {:error, :invalid_parser, :foo}
    end
  end

  describe "parse/2 - flags" do
    @describetag :parse
    @describetag :flags

    test "parses a simple flag" do
      flags = [
        foo: %Structs.Flag{
          short: "f",
          long: "foo"
        }
      ]

      result = {:ok, %{argv: [], flags: %{foo: true}, options: %{}}, {[], []}}
      result2 = {:ok, %{argv: ["before", "after"], flags: %{foo: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["--foo"], flags: flags) == result
      assert Vexil.parse(["-f"], flags: flags) == result
      assert Vexil.parse(["before", "--foo", "after"], flags: flags) == result2
      assert Vexil.parse(["before", "-f", "after"], flags: flags) == result2
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
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["--foo", "--bar", "--qux"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["--foo", "--bar", "--qux", "--xyzzy"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
                {[], []}}

      # And now test all the short flags
      assert Vexil.parse(["-f", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-b", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-f", "-b", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
                {[], []}}

      # And now test several mixes of short and long flags
      assert Vexil.parse(["-f", "--bar"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "--bar", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-f", "--bar", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["--foo", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["--foo", "-b", "-q"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["--foo", "-b", "-q", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-f", "--bar", "--qux"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-f", "--bar", "--qux", "-x"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
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
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-fbq"], flags: three) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true, qux: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-fbqx"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
                {[], []}}

      assert Vexil.parse(["-fb", "-qx"], flags: four) ==
               {:ok,
                %{argv: [], flags: %{foo: true, bar: true, qux: true, xyzzy: true}, options: %{}},
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
               {:ok, %{argv: [], flags: %{foo: 1}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: 2}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-f", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: 3}, options: %{}}, {[], []}}

      assert Vexil.parse(["-ff"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: 2}, options: %{}}, {[], []}}

      assert Vexil.parse(["-fff"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: 3}, options: %{}}, {[], []}}

      assert Vexil.parse(["-ff", "-f"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: 3}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: 1, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-b", "-f"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: 2, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-ffb"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: 2, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-fbf"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: 2, bar: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-bf"], flags: two) ==
               {:ok, %{argv: [], flags: %{bar: true, foo: 1}, options: %{}}, {[], []}}
    end

    test "flags not provided default to false" do
      foo = %Structs.Flag{
        short: "f",
        long: "foo"
      }

      bar = %Structs.Flag{
        short: "b",
        long: "bar"
      }

      one = [foo: foo]
      two = [foo: foo, bar: bar]

      assert Vexil.parse([], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: false}, options: %{}}, {[], []}}

      assert Vexil.parse([], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: false, bar: false}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f"], flags: one) ==
               {:ok, %{argv: [], flags: %{foo: true}, options: %{}}, {[], []}}

      assert Vexil.parse(["-f", "-b"], flags: two) ==
               {:ok, %{argv: [], flags: %{foo: true, bar: true}, options: %{}}, {[], []}}
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
               {:ok, %{argv: [], flags: %{}, options: %{}},
                {[], [{:error, :unknown_flag, "f"}, {:error, :unknown_flag, "b"}]}}

      assert Vexil.parse(["-fb"], flags: flags) ==
               {:ok, %{argv: [], flags: %{foo: 1}, options: %{}},
                {[], [{:error, :unknown_flag, "b"}]}}

      assert Vexil.parse(["--foo", "-fb"], flags: flags) ==
               {:ok, %{argv: [], flags: %{foo: 2}, options: %{}},
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

      result = {
        :ok,
        %{argv: [], flags: %{bar: true}, options: %{}},
        {[], [{:error, :duplicate_flag, :bar}]}
      }

      assert Vexil.parse(["--bar", "--bar"], flags: one) == result
      assert Vexil.parse(["-b", "-b"], flags: one) == result
      assert Vexil.parse(["--bar", "-b"], flags: one) == result
      assert Vexil.parse(["-bb"], flags: one) == result

      assert Vexil.parse(["--foo", "--bar", "-b"], flags: two) ==
               {
                 :ok,
                 %{argv: [], flags: %{foo: 1, bar: true}, options: %{}},
                 {[], [{:error, :duplicate_flag, :bar}]}
               }
    end

    # TODO: test error early for the above here
    test "returns only an error when seeing a duplicate flag when told to error early" do
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
      result = {:error, :duplicate_flag, :bar}

      assert Vexil.parse(["--bar", "--bar"], flags: one, error_early: true) == result
      assert Vexil.parse(["-b", "-b"], flags: one, error_early: true) == result
      assert Vexil.parse(["--bar", "-b"], flags: one, error_early: true) == result
      assert Vexil.parse(["-bb"], flags: one, error_early: true) == result
      assert Vexil.parse(["--foo", "--bar", "-b"], flags: two, error_early: true) == result
    end
  end

  describe "parse/2 - options" do
    @describetag :parse
    @describetag :options

    test "parses a simple option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      result = {:ok, %{argv: [], flags: %{}, options: %{foo: "bar"}}, {[], []}}
      result2 = {:ok, %{argv: ["before", "after"], flags: %{}, options: %{foo: "bar"}}, {[], []}}

      assert Vexil.parse(["-f", "bar"], options: options) == result
      assert Vexil.parse(["--foo", "bar"], options: options) == result
      # Make sure we split on an equals directly after
      assert Vexil.parse(["-f=bar"], options: options) == result
      assert Vexil.parse(["--foo=bar"], options: options) == result

      assert Vexil.parse(["before", "-f", "bar", "after"], options: options) == result2
      assert Vexil.parse(["before", "--foo", "bar", "after"], options: options) == result2
      assert Vexil.parse(["before", "-f=bar", "after"], options: options) == result2
      assert Vexil.parse(["before", "--foo=bar", "after"], options: options) == result2
    end

    test "parses multiple consecutive options" do
      foo = %Structs.Option{
        short: "f",
        long: "foo"
      }

      bar = %Structs.Option{
        short: "b",
        long: "bar"
      }

      qux = %Structs.Option{
        short: "q",
        long: "qux"
      }

      options = [foo: foo, bar: bar, qux: qux]

      result =
        {:ok, %{argv: [], flags: %{}, options: %{foo: "bar", bar: "baz", qux: "qux"}}, {[], []}}

      result2 =
        {:ok, %{argv: [], flags: %{}, options: %{foo: "bar", bar: "baz", qux: nil}}, {[], []}}

      assert Vexil.parse(["--foo", "bar", "--bar", "baz", "--qux", "qux"], options: options) ==
               result

      assert Vexil.parse(["-f", "bar", "-b", "baz", "-q", "qux"], options: options) == result
      assert Vexil.parse(["-f=bar", "-b=baz", "-q=qux"], options: options) == result
      assert Vexil.parse(["--foo=bar", "--bar=baz", "--qux=qux"], options: options) == result

      assert Vexil.parse(["--foo", "bar", "--bar", "baz"], options: options) == result2
      assert Vexil.parse(["-f", "bar", "-b", "baz"], options: options) == result2
      assert Vexil.parse(["-f=bar", "-b=baz"], options: options) == result2
      assert Vexil.parse(["--foo=bar", "--bar=baz"], options: options) == result2
    end

    test "parses a simple option with a default" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          default: "foo-default"
        }
      ]

      assert Vexil.parse([], options: options) ==
               {:ok, %{argv: [], flags: %{}, options: %{foo: "foo-default"}}, {[], []}}

      assert Vexil.parse(["foobar"], options: options) ==
               {:ok, %{argv: ["foobar"], flags: %{}, options: %{foo: "foo-default"}}, {[], []}}

      assert Vexil.parse(["--foo", "bar"], options: options) ==
               {:ok, %{argv: [], flags: %{}, options: %{foo: "bar"}}, {[], []}}
    end

    test "parses a greedy option which collects all arguments until the next option it sees" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          greedy: true
        },
        bar: %Structs.Option{
          short: "b",
          long: "bar"
        }
      ]

      result = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{foo: ["bar", "baz", "bang", "qux", "xyzzy"], bar: nil}
        },
        {[], []}
      }

      result2 = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{foo: ["bar", "baz", "bang", "qux", "xyzzy"], bar: "shrug"}
        },
        {[], []}
      }

      assert Vexil.parse(["--foo", "bar", "baz", "bang", "qux", "xyzzy"], options: options) ==
               result

      assert Vexil.parse(["-f", "bar", "baz", "bang", "qux", "xyzzy"], options: options) == result
      assert Vexil.parse(["--foo=bar", "baz", "bang", "qux", "xyzzy"], options: options) == result
      assert Vexil.parse(["-f=bar", "baz", "bang", "qux", "xyzzy"], options: options) == result

      assert Vexil.parse(
               ["--foo", "bar", "baz", "bang", "qux", "xyzzy", "--bar", "shrug"],
               options: options
             ) == result2

      assert Vexil.parse(
               ["-f", "bar", "baz", "bang", "qux", "xyzzy", "--bar", "shrug"],
               options: options
             ) == result2

      assert Vexil.parse(
               ["--foo=bar", "baz", "bang", "qux", "xyzzy", "--bar", "shrug"],
               options: options
             ) == result2

      assert Vexil.parse(
               ["-f=bar", "baz", "bang", "qux", "xyzzy", "--bar", "shrug"],
               options: options
             ) == result2
    end

    # TODO: testing for greedy with a max limit

    test "allows for integer and float parsers for an option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :integer
        },
        bar: %Structs.Option{
          short: "b",
          long: "bar",
          parser: :float
        }
      ]

      result = {:ok, %{argv: [], flags: %{}, options: %{foo: 31, bar: 5.3}}, {[], []}}

      assert Vexil.parse(["--foo", "31", "--bar", "5.3"], options: options) == result
      assert Vexil.parse(["-f", "31", "-b", "5.3"], options: options) == result
      assert Vexil.parse(["--foo=31", "--bar=5.3"], options: options) == result
      assert Vexil.parse(["-f=31", "-b=5.3"], options: options) == result
    end

    test "allows a custom parser for options" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          # TODO: maybe more elegant solution for custom parsers so we don't need any empty second arg when not greedy? (only pass it when actually greedy??)
          parser: fn val, _greedy ->
            Jason.decode(val)
          end
        }
      ]

      result = {:ok, %{argv: [], flags: %{}, options: %{foo: %{"bar" => "baz"}}}, {[], []}}

      assert Vexil.parse(["--foo", ~s({"bar": "baz"})], options: options) == result
      assert Vexil.parse(["-f", ~s({"bar": "baz"})], options: options) == result

      # TODO: would we need to do manual quote parsing for `=` with spaces? Need to look into how OptionParser.split works (maybe end up providing our own)
      # assert Vexil.parse([~s(--foo={"bar": "baz"})], options: options) == result
      # assert Vexil.parse([~s(-f={"bar": "baz"})], options: options) == result
    end

    test "allows greedy option with a custom parser" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          greedy: true,
          parser: fn input, _greedy ->
            try do
              {:ok, Enum.map(input, &String.to_integer/1)}
            rescue
              e -> {:error, e}
            end
          end
        }
      ]

      result = {:ok, %{argv: [], flags: %{}, options: %{foo: [1, 2, 3, 4, 5]}}, {[], []}}

      assert Vexil.parse(["--foo", "1", "2", "3", "4", "5"], options: options) == result
      assert Vexil.parse(["-f", "1", "2", "3", "4", "5"], options: options) == result
      assert Vexil.parse(["--foo=1", "2", "3", "4", "5"], options: options) == result
      assert Vexil.parse(["-f=1", "2", "3", "4", "5"], options: options) == result
    end

    test "allows usage of options being declared multiple times" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          multiple: true
        },
        bar: %Structs.Option{
          short: "b",
          long: "bar",
          multiple: true
        }
      ]

      result = {
        :ok,
        %{argv: [], flags: %{}, options: %{foo: ["bar", "baz"], bar: ["bar", "baz"]}},
        {[], []}
      }

      assert Vexil.parse(["--foo", "bar", "--foo", "baz", "--bar", "bar", "--bar", "baz"],
               options: options
             ) == result

      assert Vexil.parse(["--foo", "bar", "--bar", "bar", "--foo", "baz", "--bar", "baz"],
               options: options
             ) == result

      assert Vexil.parse(["-f", "bar", "-f", "baz", "-b", "bar", "-b", "baz"], options: options) ==
               result

      assert Vexil.parse(["-f", "bar", "-b", "bar", "-f", "baz", "-b", "baz"], options: options) ==
               result

      assert Vexil.parse(["-f", "bar", "-f=baz", "-b", "bar", "-b", "baz"], options: options) ==
               result

      assert Vexil.parse(["-f", "bar", "-b=bar", "-f", "baz", "-b", "baz"], options: options) ==
               result
    end

    test "has an error in the relevant list when seeing an unknown option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      result = fn name ->
        {
          :ok,
          %{
            argv: ["bong"],
            flags: %{},
            options: %{foo: nil}
          },
          {[{:error, :unknown_option, name}], []}
        }
      end

      assert Vexil.parse(["--bar", "bong"], options: options) == result.("bar")
      assert Vexil.parse(["-b", "bong"], options: options) == result.("b")
      assert Vexil.parse(["--bar=bong"], options: options) == result.("bar")
      assert Vexil.parse(["-b=bong"], options: options) == result.("b")
    end

    test "returns only an error when seeing an unknown option when told to error early" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      result = fn name ->
        {:error, :unknown_option, name}
      end

      assert Vexil.parse(["--bar", "bong"], options: options, error_early: true) == result.("bar")
      assert Vexil.parse(["-b", "bong"], options: options, error_early: true) == result.("b")
      assert Vexil.parse(["--bar=bong"], options: options, error_early: true) == result.("bar")
      assert Vexil.parse(["-b=bong"], options: options, error_early: true) == result.("b")
    end

    test "has an error in the relevant list when a required option is missing" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          required: true
        },
        bar: %Structs.Option{
          short: "b",
          long: "bar",
          required: true
        }
      ]

      result1 = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{}
        },
        {[{:error, :missing_required_options, [:foo, :bar]}], []}
      }

      result2 = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{foo: "faz"}
        },
        {[{:error, :missing_required_options, [:bar]}], []}
      }

      result3 = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{bar: "baz"}
        },
        {[{:error, :missing_required_options, [:foo]}], []}
      }

      assert Vexil.parse([], options: options) == result1
      assert Vexil.parse(["--foo", "faz"], options: options) == result2
      assert Vexil.parse(["--bar", "baz"], options: options) == result3
    end

    test "returns only an error when a required option is missing when told to error early" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          required: true
        },
        bar: %Structs.Option{
          short: "b",
          long: "bar",
          required: true
        }
      ]

      result1 = {:error, :missing_required_options, [:foo, :bar]}
      result2 = {:error, :missing_required_options, [:bar]}
      result3 = {:error, :missing_required_options, [:foo]}

      assert Vexil.parse([], options: options, error_early: true) == result1
      assert Vexil.parse(["--foo", "faz"], options: options, error_early: true) == result2
      assert Vexil.parse(["--bar", "baz"], options: options, error_early: true) == result3
    end

    test "has an error in the relevant list when an invalid value is given to an option with a parser" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :integer
        }
      ]

      result = {
        :ok,
        %{
          argv: [],
          flags: %{},
          options: %{foo: nil}
        },
        {[{:error, :invalid_value, :foo, "expected integer, got `bong`"}], []}
      }

      assert Vexil.parse(["--foo", "bong"], options: options) == result
      assert Vexil.parse(["-f", "bong"], options: options) == result
      assert Vexil.parse(["--foo=bong"], options: options) == result
      assert Vexil.parse(["-f=bong"], options: options) == result
    end

    test "returns only an error when an invalid value is given to an option with a parser when told to error early" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :integer
        }
      ]

      result = {:error, :invalid_value, :foo, "expected integer, got `bong`"}

      assert Vexil.parse(["--foo", "bong"], options: options, error_early: true) == result
      assert Vexil.parse(["-f", "bong"], options: options, error_early: true) == result
      assert Vexil.parse(["--foo=bong"], options: options, error_early: true) == result
      assert Vexil.parse(["-f=bong"], options: options, error_early: true) == result
    end

    test "has an error in the relevant list when seeing a duplicate option not specified as multiple" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      result = {
        :ok,
        %{
          argv: ["bong"],
          flags: %{},
          options: %{foo: "bong"}
        },
        {[{:error, :duplicate_option, :foo}], []}
      }

      assert Vexil.parse(["--foo", "bong", "--foo", "bong"], options: options) == result
      assert Vexil.parse(["-f", "bong", "-f", "bong"], options: options) == result
      assert Vexil.parse(["--foo=bong", "--foo=bong"], options: options) == result
      assert Vexil.parse(["-f=bong", "-f=bong"], options: options) == result
    end

    test "returns only an error when seeing a duplicate option not specified as multiple when told to error early" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      result = {:error, :duplicate_option, :foo}

      assert Vexil.parse(["--foo", "bong", "--foo", "bong"], options: options, error_early: true) ==
               result

      assert Vexil.parse(["-f", "bong", "-f", "bong"], options: options, error_early: true) ==
               result

      assert Vexil.parse(["--foo=bong", "--foo=bong"], options: options, error_early: true) ==
               result

      assert Vexil.parse(["-f=bong", "-f=bong"], options: options, error_early: true) == result
    end
  end

  describe "parse!/2" do
    test "returns the result of parse" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      flags = [
        bar: %Structs.Flag{
          short: "b",
          long: "bar"
        }
      ]

      result1 = %{argv: [], flags: %{}, options: %{foo: "faz"}}
      result2 = %{argv: [], flags: %{bar: true}, options: %{}}

      assert Vexil.parse!(["--foo", "faz"], options: options) == result1
      assert Vexil.parse!(["-f", "faz"], options: options) == result1

      assert Vexil.parse!(["--bar"], flags: flags) == result2
      assert Vexil.parse!(["-b"], flags: flags) == result2
    end

    test "raises an error for an invalid argv" do
      assert_raise Errors.ArgvError, fn ->
        Vexil.parse!([1])
      end
    end

    test "raises an error when flags is not a keyword list" do
      assert_raise ArgumentError, "flags must be a keyword list", fn ->
        Vexil.parse!([], flags: "")
      end
    end

    test "raises an error when options is not a keyword list" do
      assert_raise ArgumentError, "options must be a keyword list", fn ->
        Vexil.parse!([], options: "")
      end
    end

    test "raises an error when an option is not the correct struct" do
      options = [
        foo: ""
      ]

      assert_raise Errors.InvalidOptionError,
                   "invalid option given 'foo', must be `Vexil.Structs.Option`",
                   fn ->
                     Vexil.parse!([], options: options)
                   end
    end

    test "raises an error when a flag is not the correct struct" do
      flags = [
        foo: ""
      ]

      assert_raise Errors.InvalidFlagError,
                   "invalid flag given 'foo', must be `Vexil.Structs.Flag`",
                   fn ->
                     Vexil.parse!([], flags: flags)
                   end
    end

    test "raises an error when a required option has a default" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          default: "faz",
          required: true
        }
      ]

      assert_raise Errors.RequiredOptionHasDefaultError,
                   "required option 'foo' has a default value",
                   fn ->
                     Vexil.parse!([], options: options)
                   end
    end

    test "raies an error when theres a conflicting short or long key between flags and options" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      flags = [
        foo: %Structs.Flag{
          short: "f",
          long: "foo"
        }
      ]

      # TODO: make this prefer long keys before short keys?
      assert_raise Errors.ConflictingKeyError,
                   "conflicting key 'f' given between flags and options",
                   fn ->
                     Vexil.parse!([], options: options, flags: flags)
                   end
    end

    test "raises an exception when an invalid parser is given for an option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :my_epic_parser
        }
      ]

      assert_raise Errors.InvalidParserError,
                   "invalid parser for option 'foo', must be :string, :integer, :float, or a unary function",
                   fn ->
                     Vexil.parse!([], options: options)
                   end
    end

    test "raises an error when given an unknown flag" do
      assert_raise Errors.UnknownFlagError, "unknown flag 'f'", fn ->
        Vexil.parse!(["-fb"], flags: [])
      end
    end

    test "raises an error when given an unknown option" do
      assert_raise Errors.UnknownOptionError, "unknown option 'foo'", fn ->
        Vexil.parse!(["--foo"], options: [])
      end
    end

    test "raises an error when given a duplicate flag" do
      flags = [
        foo: %Structs.Flag{
          short: "f",
          long: "foo"
        }
      ]

      assert_raise Errors.DuplicateFlagError, "duplicate flag 'foo'", fn ->
        Vexil.parse!(["--foo", "--foo"], flags: flags)
      end
    end

    test "raises an error when given a duplicate option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo"
        }
      ]

      assert_raise Errors.DuplicateOptionError, "duplicate option 'foo'", fn ->
        Vexil.parse!(["--foo", "bar", "--foo", "bar"], options: options)
      end
    end

    test "raises an error when missing a required option" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          required: true
        }
      ]

      assert_raise Errors.RequiredOptionError, fn ->
        Vexil.parse!([], options: options)
      end
    end

    assert "raises an error when an invalid value is given to an option with a parser" do
      options = [
        foo: %Structs.Option{
          short: "f",
          long: "foo",
          parser: :integer
        }
      ]

      assert_raise Errors.InvalidValueError, "invalid value for option 'foo'", fn ->
        Vexil.parse!(["--foo", "bong"], options: options)
      end
    end
  end

  # TODO: tests for using flags and options at the same time. Just need to make sure they work properly together.
end
