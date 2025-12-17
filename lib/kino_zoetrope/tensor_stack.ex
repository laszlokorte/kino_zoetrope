defmodule KinoZoetrope.TensorStack do
  @moduledoc """
  Documentation for `KinoZoetrope.TensorStack`.
  """
  use Kino.JS

  def new(tensors, args \\ []) do
    stacks =
      tensors
      |> Enum.with_index()
      |> Enum.map(fn {tensor, ti} ->
        {frames, w, h, c} =
          Nx.shape(tensor)
          |> case do
            {frames, w, h, 3} ->
              {frames, w, h, 3}

            {frames, w, h, 4} ->
              {frames, w, h, 4}

            {frames, w, h, 1} ->
              {frames, w, h, 1}

            {frames, w, h} ->
              {frames, w, h, 1}

            _ ->
              raise "Expect tensors to be of shape {frames, width, height, 4}, {frames, width, height, 3}, {frames, width, height, 1} or {frames, width, height}"
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
          if Keyword.get(args, :normalize, true) do
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
              |> Nx.slice_along_axis(f, 1, axis: 0)
              |> Nx.reshape({w, h, c})
              |> Image.from_nx!()

            {:ok, binary} =
              image |> Vix.Vips.Image.write_to_buffer(Keyword.get(args, :image_type, ".png"))

            "data:image/png;base64,#{Base.encode64(binary)}"
          end

        image_tags =
          for {base64, i} <- Enum.with_index(images) do
            %{index: frames - i, width: w, height: h, data: base64}
          end

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
          label: args |> Keyword.get(:labels, []) |> Enum.at(ti, "Image #{ti + 1}")
        }
      end)

    Kino.JS.new(__MODULE__, %{stacks: stacks, titel: Keyword.get(args, :titel, "Images")})
  end

  asset "main.js" do
    """
    function sliderListener(figure, slider, sliderOutput) {
      return (evt) => {
        const imgs = figure.querySelectorAll('.stack img')
        const activeImgs = figure.querySelectorAll('.stack img:nth-of-type('+(slider.valueAsNumber)+')')
        Array.prototype.forEach.call(imgs, (c,i) => {c.style.zIndex = 0});
        Array.prototype.forEach.call(activeImgs, (c,i) => {c.style.zIndex = 1});
        sliderOutput.value = `${slider.valueAsNumber} / ${slider.max}`;
      }
    }

    export function init(ctx, args) {
      ctx.importCSS("main.css")

      const figure = document.createElement('figure');
      figure.classList.add("plot-figure")
      const figCaption = document.createElement('figCaption');
      const figCaptionTitle = document.createElement('strong');
      figCaptionTitle.appendChild(document.createTextNode(args.titel))


      const sliderList = document.createElement("dl");
      const sliderHead = document.createElement("dt");
      const sliderBody = document.createElement("dd");
      const slider = document.createElement("input");
      const sliderOutput = document.createElement("output");

      const maxFrame = args.stacks.map(f => f.frames).reduce((a,b) => Math.max(a,b), 0);
      slider.setAttribute("type", "range")
      slider.setAttribute("min", "0")
      slider.setAttribute("max", maxFrame)

      slider.value = 0;
      sliderOutput.value = `0 / ${maxFrame}`;

      sliderHead.appendChild(document.createTextNode("Frame"))

      sliderBody.appendChild(slider)
      sliderBody.appendChild(sliderOutput)

      sliderList.appendChild(sliderHead)
      sliderList.appendChild(sliderBody)

      figCaption.appendChild(figCaptionTitle);
      figCaption.appendChild(sliderList);
      figure.appendChild(figCaption)

      const stacks = document.createElement("div");
      stacks.classList.add("stacks")
      const images = new DocumentFragment();
      for(let s of args.stacks) {
        const stackContainer = document.createElement("div");
        stackContainer.classList.add("image-with-desc")
        const stack = document.createElement("div");
        stack.classList.add("stack")
        stack.classList.add("image-with-desc-image")


        const stackLabel = document.createElement("div");
        stackLabel.classList.add("stack-label")

        stackLabel.appendChild(document.createTextNode(s.label))
        stackContainer.appendChild(stackLabel)

        const metaList = document.createElement("dl");
        const metaListSizeKey = document.createElement("dt")
        metaListSizeKey.appendChild(document.createTextNode("Size"))
        const metaListSizeValue = document.createElement("dd")
        metaListSizeValue.appendChild(document.createTextNode(`${s.width} × ${s.height} × ${s.channels}`))
        metaList.appendChild(metaListSizeKey)
        metaList.appendChild(metaListSizeValue)

        for(let [k,v] of Object.entries({type: "Type", real_min: "Min", real_max: "Max"})) {
          const metaListKey = document.createElement("dt")
          metaListKey.appendChild(document.createTextNode(v))
          const metaListValue = document.createElement("dd")
          metaListValue.appendChild(document.createTextNode(`${s[k]}`))
          metaList.appendChild(metaListKey)
          metaList.appendChild(metaListValue)
        }

        for(let i of s.images) {
          const img = document.createElement("img");
          img.src = i.data
          img.style.zIndex = i.index
          img.setAttribute("width", i.width)
          img.setAttribute("height", i.height)
          const aspect = i.width/i.height;
          const maxSize= 20;
          if(aspect > 1) {
            img.style.maxWidth = `${maxSize}em`;
            img.style.maxHeight = `${maxSize/aspect}em`;
          } else {
            img.style.maxHeight = `${maxSize}em`;
            img.style.maxWidth = `${maxSize*aspect}em`;
          }
          img.style.zIndex = i.index
          img.classList.add("plot")
          img.classList.add("stack-item")

          stack.appendChild(img)
        }
        if(s.channels === 1) {
          const scale = document.createElement("div");
          scale.classList.add("stack-scale")
          const scaleLabels = document.createElement("div");
          scaleLabels.classList.add("scale-labels")

          const scaleGradient = document.createElement("div");
          scaleGradient.classList.add("scale-gradient")

          const svgNs = 'http://www.w3.org/2000/svg';
          const scaleMarkers = document.createElementNS(svgNs, "svg");
          scaleMarkers.classList.add("scale-markers")
          scaleMarkers.setAttribute("viewBox","0 0 100 100")
          scaleMarkers.setAttribute("preserveAspectRatio","none")
          scaleMarkers.setAttribute("width", 100)
          scaleMarkers.setAttribute("height", 100)

          for(const [l, c] of Object.entries({'real_min': "red", 'real_max': "cyan"})) {
            const scaleMarkerRange = document.createElementNS(svgNs, "line");
            const minY =  100 * ((s[l]- s.out_min)/(s.out_max - s.out_min))
            scaleMarkerRange.setAttribute("x1", -100)
            scaleMarkerRange.setAttribute("x2", 200)
            scaleMarkerRange.setAttribute("y1", 100 - minY)
            scaleMarkerRange.setAttribute("y2", 100 - minY)
            scaleMarkerRange.setAttribute("stroke", c)
            scaleMarkerRange.setAttribute("opacity", 0.5)
            scaleMarkerRange.setAttribute("stroke-width", "4")
            scaleMarkerRange.setAttribute("vector-effect", "non-scaling-stroke")

            scaleMarkers.appendChild(scaleMarkerRange)
          }
          scaleGradient.appendChild(scaleMarkers)

          const scaleTop = document.createElement("div");
          scaleTop.classList.add("scale-label")
          scaleTop.appendChild(document.createTextNode(s.out_max))

          const scaleBottom = document.createElement("div");
          scaleBottom.classList.add("scale-label")
          scaleBottom.appendChild(document.createTextNode(s.out_min))

          scaleLabels.appendChild(scaleTop)
          scaleLabels.appendChild(scaleBottom)

          scale.append(scaleGradient)
          scale.append(scaleLabels)

          stack.append(scale)

        }

        stackContainer.appendChild(stack)
        stackContainer.appendChild(metaList)
        stacks.appendChild(stackContainer)
      }
      figure.appendChild(stacks)
      ctx.root.appendChild(figure);

      slider.addEventListener('input', sliderListener(figure, slider, sliderOutput))
    }
    """
  end

  asset "main.css" do
    """
    .stacks {
      display: flex;
      flex-direction: row;
      justity-content: start;
      gap: 1em;
    }

    .stack-label {
      padding: 1em;
      font-weight: bold;
    }

    .image-with-desc {
      display: grid;
      justify-content: start;
      align-content: center;
      justify-items: center;
      align-items: center;
      display: flex;
      flex-direction: column;
      flex-basis: 10em;
      flex-shrink: 0;
      padding: 1em;
      border: 2px solid #aaa;
    }

    .image-with-desc-image,
    .image-with-desc-desc {
      grid-area: 1 / 1 / 2 / 2;
    }

    .plot-figure {
      display: grid;
      justify-content: stretch;
      margin: 0;
      padding: 0;
      gap: 1em;
    }

    .plot {
      image-rendering: pixelated;
      object-fit: contain;
      object-position: center;
      width: 100%;
      height: 100%;
      max-width: 20em;
      min-width: 5em;
      max-height: 20em;
      border: 1px solid black;
    box-sizing: border-box;
      padding: 0;
    }

    dl {
      font-family: monospace;
      display: grid;
      grid-template-columns: auto auto;
      justify-content: start;
      gap: 1ex 1em;
      align-items: center;
    }

    dt {
      font-weight: bold;
      text-align: right;
      justify-content: end;
    }

    dt, dd {
      margin: 0;
      white-space: nowrap;
      align-items: center;
      gap: 1ex;
      display: flex;
    }

    .stack {
      display: grid;
      grid-template-columns: max-content auto;
      grid-template-rows: max-content;
      justify-content: center;
      gap: 0.5ex;
    }

    .stack-item {
      grid-area: 1/1/2/2;
    }

    .stack-scale {
      grid-area: 1/2/ span 1 / span 1;
      display: flex;
      align-items: stretch;
      gap: 1ex;
    }

    .scale-gradient {
      background-image: linear-gradient(0deg, black, white);
      border: 1px solid black;
      width: 1em;
      flex-shrink: 0;
    }

    .scale-labels {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: start;
      font-family: monospace;
    }

    input[type=range] {
      height: 2.5em;
    }

    .scale-markers {
    width: 100%;
    height: 100%;
    }
    """
  end
end
