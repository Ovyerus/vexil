# Vexil

> An Elixir flag parser that does _just_ enough.

Vexil is a CLI flag parsing library for Elixir, intended to be used in places
where you might want to parse user input akin to how command line arguments are
parsed, but in an area where you aren't getting the input from an actual command
line, say a website or a chat platform bot.

I found [OptionParser](https://hexdocs.pm/elixir/1.12/OptionParser.html)'s
settings to be too confusing for me, and
[Optimus](https://github.com/funbox/optimus) is intended for use in regular
command line application (with the in-built help and closing the application
when encountering input errors), so Vexil slots in between the two as a sort of
middle ground, letting you control how errors are displayed/handled for the
user, and still having a sane interface for defining flags and options.

---

Vexil is currently beta-quality software, but is well tested with over 90%
coverage at time of writing, including most standard usage scenarios for it.
Until proper documentation is written and it has been sufficiently tested in a
real-world application however, it will staying in [ZeroVer](https://0ver.org/)
and certain aspects of its functionality may change at any time until a stable
`1.0` release.

Pull requests for bug fixes are welcome, including corresponding tests to make
sure they actually work for what it is they're trying to fix.

## Installation

Add `vexil` to your dependencies in `mix.exs`.

```elixir
def deps do
  [{:vexil, "~> 0.1"}]
end
```

## Example

```elixir
iex> argv = "--end-at 256 -vvv some stuff after" |> OptionParser.split()
["--end-at", "256", "-vvv", "some", "stuff", "after"]
iex> options = [
...>   options: [
...>     end_at: %Vexil.Structs.Option{
...>       short: "e",
...>       long: "end-at",
...>       parser: :integer, # Default `:string`
...>       required: true
...>     }
...>   ],
...>   flags: [
...>     verbose: %Vexil.Structs.Flag{
...>       short: "v",
...>       long: "verbose",
...>       multiple: true
...>     }
...>   ]
...> ]
iex> {:ok, values, {option_errors, flag_errors}} = Vexil.parse(argv, options)
{:ok,
 %{
   argv: ["some", "stuff", "after"],
   flags: %{verbose: 3},
   options: %{end_at: 256}
 }, {[], []}}
iex> argv2 = "-vvv some stuff after" |> OptionParser.split()
iex> {:ok, values, {option_errors, flag_errors}} = Vexil.parse(argv2, options)
{:ok, %{argv: ["some", "stuff", "after"], flags: %{verbose: 3}, options: %{}},
 {[{:error, :missing_required_options, [:end_at]}], []}}
```

This section will be updated as documentation is expanded.

## License

Vexil is released under the MIT License, see the [LICENSE](./LICENSE) file for
details.
