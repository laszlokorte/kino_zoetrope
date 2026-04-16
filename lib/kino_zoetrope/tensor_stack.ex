defmodule KinoZoetrope.TensorStack do
  @moduledoc """
  Documentation for `KinoZoetrope.TensorStack`.
  """
  alias KinoZoetrope.Colormap
  use Kino.JS, assets_path: "lib/assets"

  def new(tensors, args \\ [])

  def new(tensor = %Nx.Tensor{}, args) do
    new([tensor], args)
  end

  def new(tensors = [_ | _], args) do
    stacks =
      tensors
      |> Enum.with_index()
      |> Enum.map(fn {tensor, ti} ->
        {frames, h, w, c} =
          {Nx.shape(tensor), Keyword.get(args, :multiple, true)}
          |> case do
            {{frames, h, w, 3}, _} ->
              {frames, h, w, 3}

            {{frames, h, w, 4}, _} ->
              {frames, h, w, 4}

            {{frames, h, w, 1}, _} ->
              {frames, h, w, 1}

            {{h, w, 1}, true} ->
              {1, h, w, 1}

            {{frames, h, w}, true} ->
              {frames, h, w, 1}

            {{h, w, c}, false} ->
              {1, h, w, c}

            {{h, w}, false} ->
              {1, h, w, 1}

            {shape, _multiple} ->
              raise "Expect tensors to be of shape {frames, width, height, 4}, {frames, width, height, 3}, {frames, width, height, 1} or {frames, width, height}, got: #{inspect(shape)}"
          end

        real_min = Nx.reduce_min(tensor) |> Nx.to_number()
        real_max = Nx.reduce_max(tensor) |> Nx.to_number()
        out_min = Keyword.get(args, :vmin, real_min)
        out_max = Keyword.get(args, :vmax, real_max)

        range =
          Nx.subtract(
            Keyword.get(args, :vmax, real_max),
            Keyword.get(args, :vmin, real_min)
          )

        normalized =
          if Keyword.get(args, :normalize, c == 1) do
            tensor
            |> Nx.subtract(Keyword.get(args, :vmin, real_min))
            |> Nx.divide(range)
            |> Nx.multiply(255)
          else
            tensor
          end
          |> Nx.as_type(:u8)

        images =
          for f <- 0..(frames - 1) do
            image =
              normalized
              |> Nx.reshape({frames, h, w, c}, names: [:frames, :height, :width, :channels])
              |> Nx.slice_along_axis(f, 1, axis: 0)
              |> Nx.reshape({h, w, c}, names: [:height, :width, :channels])
              |> Image.from_nx!()

            {:ok, binary} =
              image |> Vix.Vips.Image.write_to_buffer(Keyword.get(args, :image_type, ".png"))

            "data:image/png;base64,#{Base.encode64(binary)}"
          end

        image_tags =
          for {base64, i} <- Enum.with_index(images) do
            %{index: frames - i, width: w, height: h, data: base64}
          end

        {t, _} = Nx.type(tensor)

        %{
          images: image_tags,
          width: w,
          height: h,
          channels: c,
          frames: frames,
          type: inspect(Nx.type(tensor)),
          real_min: real_min,
          real_max: real_max,
          out_min: out_min,
          out_max: out_max,
          float: t == :f,
          show_label:
            args
            |> Keyword.get(
              :show_labels,
              Enum.count(tensors) > 1 or Keyword.has_key?(args, :labels)
            ),
          label: args |> Keyword.get(:labels, []) |> Enum.at(ti, "Image #{ti + 1}"),
          cmap: args |> Keyword.get(:cmaps, []) |> Enum.at(ti, Keyword.get(args, :cmap, nil)),
          resize:
            args
            |> Keyword.get(:resize, false)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, false)
              v -> v
            end
            |> case do
              true -> true
              _ -> false
            end,
          sharp:
            args
            |> Keyword.get(:sharp, true)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, true)
              v -> v
            end
            |> case do
              false -> false
              _ -> true
            end,
          legend:
            args
            |> Keyword.get(:legend, true)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, true)
              v -> v
            end
            |> case do
              true -> true
              _ -> false
            end,
          x_axis:
            args
            |> Keyword.get(:x_axis, nil)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, nil)
              v -> v
            end,
          y_axis:
            args
            |> Keyword.get(:y_axis, nil)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, nil)
              v -> v
            end,
          legend_labels:
            args
            |> Keyword.get(:legend_labels, true)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, true)
              v -> v
            end
            |> case do
              true -> true
              _ -> false
            end,
          legend_markers:
            args
            |> Keyword.get(:legend_markers, true)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, true)
              v -> v
            end
            |> case do
              true -> true
              _ -> false
            end,
          size:
            args
            |> Keyword.get(:size, nil)
            |> case do
              [_ | _] = l -> l |> Enum.at(ti, nil)
              v -> v
            end
            |> case do
              {w, h} -> %{x: w, y: h}
              width when is_number(width) -> %{x: width}
              _ -> nil
            end,
          markers:
            args
            |> Keyword.get(:markers, [])
            |> Enum.filter(fn
              %{for: imgs} -> Enum.member?(imgs, ti)
              _ -> false
            end)
            |> Enum.map(fn %{points: p} = m ->
              %{m | points: Enum.map(p, fn {x, y} -> %{x: x, y: y} end)}
            end)
        }
      end)

    Kino.JS.new(__MODULE__, %{
      stacks: stacks,
      titel: Keyword.get(args, :titel, "Images"),
      show_meta: args |> Keyword.get(:show_meta, true),
      frame_label: args |> Keyword.get(:frame_label, "Frame"),
      cmap_names: JSON.encode!(Colormap.cmapNames()),
      cmap_data: Colormap.cmapData()
    })
  end
end
