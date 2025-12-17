# KinoZoetrope

Helper for rendering 3d and 4d `Nx.Tensor` as image sequences in livebook.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kino_zoetrope` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kino_zoetrope, "~> 0.1.0"}
  ]
end
```

## Example

```elixir
[  Nx.iota({16,16,16}, axis: 2)
|> Nx.add(Nx.iota({16,16,16}, axis: 0))
|> Nx.add(Nx.iota({16,16,16}, axis: 1)),
   Nx.iota({16,8,16}, axis: 1)
|> Nx.add(Nx.iota({16,8,16}, axis: 0))
]
|> Kinox.TensorStack.new(titel: "Example Gradients", labels: ["Square", "Portrait"])
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/kino_zoetrope>.
