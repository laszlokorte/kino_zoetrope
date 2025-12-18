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
example_images = [
# Image 1 (16 frames, height: 16, width: 16)
Nx.iota({16,16,16}, axis: 2)
  |> Nx.add(12)
  |> Nx.add(Nx.iota({16,16,16}, axis: 0))
  |> Nx.add(Nx.iota({16,16,16}, axis: 1)),


# Image 2 (32 frames, height: 5, width: 13)
Nx.iota({32, 5, 13, 1}, axis: 2, type: :f32)
  |> Nx.divide(12)
  |> Nx.subtract(0.5)
  |> Nx.multiply(
    Nx.iota({32,5,13, 1}, axis: 0, type: :f32)
    |> Nx.divide(16)
    |> Nx.multiply(2)
  )
  |> Nx.multiply(Nx.Constants.pi())
  |> Nx.multiply(2)
  |> Nx.cos()
  |> Nx.multiply(16)
  |> Nx.add(32),


# Image 1 (1 frame, height: 5, width: 12)
Nx.iota({1, 5, 12}, axis: 2, type: :f32)
  |> Nx.multiply(3)
]

example_images
|> KinoZoetrope.TensorStack.new(
  titel: "Example Gradients",
  labels: ["Square", "Wave", "Gradient"],
  vmin: 0,
  vmax: 64,
  show_meta: true
)
```

![Result Rendered in Livebook](./preview.png)
