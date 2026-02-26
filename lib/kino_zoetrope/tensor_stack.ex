defmodule KinoZoetrope.TensorStack do
  @moduledoc """
  Documentation for `KinoZoetrope.TensorStack`.
  """
  use Kino.JS

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
      show_meta: args |> Keyword.get(:show_meta, true)
    })
  end

  @cmapData "data:image/png;base64,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"
  @cmapNames [
    "viridis",
    "plasma",
    "inferno",
    "magma",
    "cividis",
    "greys",
    "purples",
    "blues",
    "greens",
    "oranges",
    "reds",
    "YlOrBr",
    "YlOrRd",
    "OrRd",
    "PuRd",
    "rdPu",
    "BuPu",
    "GnBu",
    "PuBu",
    "YlGnBu",
    "PuBuGn",
    "BuGn",
    "YlGn",
    "binary",
    "gist_yarg",
    "gist_gray",
    "gray",
    "bone",
    "pink",
    "spring",
    "summer",
    "autumn",
    "winter",
    "cool",
    "Wistia",
    "hot",
    "afmhot",
    "gist_heat",
    "copper",
    "PiYG",
    "PRGn",
    "BrBG",
    "PuOr",
    "PdGy",
    "RdBu",
    "RdYlBu",
    "RdYlGn",
    "Spectral",
    "coolwarm",
    "bwr",
    "seismic",
    "berlin",
    "managua",
    "vanimo",
    "twilight",
    "twilight_shifted",
    "hsv",
    "Pastel1",
    "Pastel2",
    "Paired",
    "Accent",
    "Dark2",
    "Set1",
    "Set2",
    "Set3",
    "tab10",
    "tab20",
    "tab20b",
    "tab20c",
    "flag",
    "prism",
    "ocean",
    "gist_earth",
    "terrain",
    "gist_stern",
    "gnuplot",
    "gnuplot2",
    "CMRmap",
    "cubhelix",
    "brg",
    "gist_rainbow",
    "rainbow",
    "jet",
    "turbo",
    "nipy_spectral",
    "gist_ncar"
  ]

  asset "main.js" do
    """
    function hsvToRgb(h, s, v) {
      let r = 0, g = 0, b = 0;
      let i = Math.floor(h * 6);
      let f = h * 6 - i;
      let p = v * (1 - s);
      let q = v * (1 - f * s);
      let t = v * (1 - (1 - f) * s);
      switch (i % 6) {
        case 0: r=v; g=t; b=p; break;
        case 1: r=q; g=v; b=p; break;
        case 2: r=p; g=v; b=t; break;
        case 3: r=p; g=q; b=v; break;
        case 4: r=t; g=p; b=v; break;
        case 5: r=v; g=p; b=q; break;
      }
      return [r, g, b];
    }

    function sliderListener(figure, slider, sliderOutput) {
      return (evt) => {
        const imgs = figure.querySelectorAll('.stack img')
        const activeImgs = figure.querySelectorAll('.stack img:nth-of-type('+(slider.valueAsNumber+1)+')')
        Array.prototype.forEach.call(imgs, (c,i) => {c.style.zIndex = 0});
        Array.prototype.forEach.call(activeImgs, (c,i) => {c.style.zIndex = 1});

        const markers = figure.querySelectorAll('.stack .image-marker')
        const activeMarkers = figure.querySelectorAll('.stack .image-marker:nth-of-type('+(slider.valueAsNumber+1)+')')
        Array.prototype.forEach.call(markers, (c,i) => {c.style.display = "none"});
        Array.prototype.forEach.call(activeMarkers, (c,i) => {c.style.display = "initial"});
        sliderOutput.value = `${slider.valueAsNumber} / ${slider.max}`;
      }
    }

    export function init(ctx, args) {
      const svgNs = 'http://www.w3.org/2000/svg';

      ctx.importCSS("main.css")

      const numf = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2, minimumFractionDigits: 2 });
      const numd = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0, minimumFractionDigits: 0 });

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

      const maxFrame = args.stacks.map(f => f.frames).reduce((a,b) => Math.max(a,b), 0) - 1;
      slider.setAttribute("type", "range")
      slider.setAttribute("min", "0")
      slider.setAttribute("max", maxFrame)
      slider.classList.add("slider-input")

      slider.value = 0;
      sliderOutput.value = `0 / ${maxFrame}`;
      sliderOutput.classList.add("slider-output")

      sliderHead.appendChild(document.createTextNode("Frame"))

      sliderBody.classList.add("slider-body")
      sliderBody.appendChild(slider)
      sliderBody.appendChild(sliderOutput)

      sliderList.classList.add("slider-list")
      sliderList.appendChild(sliderHead)
      sliderList.appendChild(sliderBody)

      figCaption.appendChild(figCaptionTitle);
      if(maxFrame > 0) {
          figCaption.appendChild(sliderList);
      }
      figure.appendChild(figCaption)

      const stacks = document.createElement("div");
      stacks.classList.add("stacks")
      const images = new DocumentFragment();
      for(let s of args.stacks) {
        const fmt = s.float ? numf : numd;
        const stackContainer = document.createElement("div");
        stackContainer.classList.add("image-with-desc")
        const stack = document.createElement("div");
        stack.classList.add("stack")
        stack.classList.add("image-with-desc-image")

        if(s.show_label) {
          const stackLabel = document.createElement("div");
          stackLabel.classList.add("stack-label")

          stackLabel.appendChild(document.createTextNode(s.label))
          stackContainer.appendChild(stackLabel)
        }

        const metaFrag = new DocumentFragment()
        if(args.show_meta) {
          const meta_args = args.show_meta === true ? {type: "Type", real_min: "Min", real_max: "Max"} : args.show_meta
          const metaList = document.createElement("dl");
          const metaListSizeKey = document.createElement("dt")
          metaListSizeKey.appendChild(document.createTextNode("Size"))
          const metaListSizeValue = document.createElement("dd")
          metaListSizeValue.appendChild(document.createTextNode(`${s.width} × ${s.height} × ${s.channels}`))
          metaList.appendChild(metaListSizeKey)
          metaList.appendChild(metaListSizeValue)

          for(let [k,v] of Object.entries(meta_args)) {
            const metaListKey = document.createElement("dt")
            metaListKey.appendChild(document.createTextNode(v))
            const metaListValue = document.createElement("dd")
            const formatted = typeof s[k] == "number" ? fmt.format(s[k]) : s[k]
            metaListValue.appendChild(document.createTextNode(`${formatted}`))
            metaList.appendChild(metaListKey)
            metaList.appendChild(metaListValue)
          }

          metaFrag.appendChild(metaList)
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
            img.style.maxWidth = `${numf.format(maxSize)}em`;
            img.style.maxHeight = `${numf.format(maxSize/aspect)}em`;
          } else {
            img.style.maxHeight = `${numf.format(maxSize)}em`;
            img.style.maxWidth = `${numf.format(maxSize*aspect)}em`;
          }
          img.style.zIndex = i.index
          img.classList.add("plot")
          img.classList.add("stack-item")

          if(s.channels == 1 && s.cmap) {
            img.style.filter = "url('#cmap-"+s.cmap.replace(/[^a-zA-Z]/g,"")+"')"
          }

          stack.appendChild(img)
        }
        const imageOverlay = document.createElementNS(svgNs, "svg");

        imageOverlay.classList.add("image-overlay")
        imageOverlay.classList.add("stack-item")
        imageOverlay.setAttribute("viewBox",`0 0 ${s.width} ${s.height}`)
        imageOverlay.setAttribute("preserveAspectRatio","none")
        imageOverlay.setAttribute("width", s.width)
        imageOverlay.setAttribute("height", s.height)

        for(let m of s.markers) {
          const g = document.createElementNS(svgNs, "g");

          for(let p of m.points) {
            const r = document.createElementNS(svgNs, "rect");

            r.setAttribute("width", 1)
            r.setAttribute("height", 1)
            r.setAttribute("fill", "white")
            r.setAttribute("opacity", "1")
            r.setAttribute("stroke", "magenta")
            r.setAttribute("vector-effect","non-scaling-stroke")
            r.setAttribute("stroke-width", "1")

            for(const [k,v] of Object.entries(m.attrs)) {
                r.setAttribute(k, v)
            }

            r.setAttribute("x", p.x)
            r.setAttribute("y", p.y)

            r.classList.add("image-marker")
            r.style.display = "none"

            g.appendChild(r)
          }

          if(g.firstElementChild) {
            g.firstElementChild.style.display = "initial"
          }
          imageOverlay.appendChild(g)
        }


        imageOverlay.style.zIndex = 2*s.images.length
        stack.appendChild(imageOverlay)

        if(s.channels === 1) {
          const scale = document.createElement("div");
          scale.classList.add("stack-scale")
          const scaleLabels = document.createElement("div");
          scaleLabels.classList.add("scale-labels")

          const scaleGradient = document.createElement("div");
          scaleGradient.classList.add("scale-gradient")
          if(s.cmap) {
            scaleGradient.style.filter = "url('#cmap-"+s.cmap.replace(/[^a-zA-Z]/g,"")+"')"
          }

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
            scaleMarkerRange.setAttribute("y1", numf.format(100 - minY))
            scaleMarkerRange.setAttribute("y2", numf.format(100 - minY))
            scaleMarkerRange.setAttribute("stroke", c)
            scaleMarkerRange.setAttribute("opacity", 0.5)
            scaleMarkerRange.setAttribute("stroke-width", "4")
            scaleMarkerRange.setAttribute("vector-effect", "non-scaling-stroke")

            scaleMarkers.appendChild(scaleMarkerRange)
          }
          scaleGradient.appendChild(scaleMarkers)

          const scaleTop = document.createElement("div");
          scaleTop.classList.add("scale-label")
          scaleTop.appendChild(document.createTextNode(fmt.format(s.out_max)))

          const scaleBottom = document.createElement("div");
          scaleBottom.classList.add("scale-label")
          scaleBottom.appendChild(document.createTextNode(fmt.format(s.out_min)))

          scaleLabels.appendChild(scaleTop)
          scaleLabels.appendChild(scaleBottom)

          scale.append(scaleGradient)
          scale.append(scaleLabels)

          stack.append(scale)

        }

        stackContainer.appendChild(stack)
        stackContainer.appendChild(metaFrag)
        stacks.appendChild(stackContainer)
      }
      figure.appendChild(stacks)
      ctx.root.appendChild(figure);


      slider.addEventListener('input', sliderListener(figure, slider, sliderOutput))

      {
        const svgns = "http://www.w3.org/2000/svg";
        const svg = document.createElementNS(svgns, "svg");
        svg.setAttribute("width", "0");
        svg.setAttribute("height", "0");
        const defs = document.createElementNS(svgns, "defs");
        svg.appendChild(defs);
        document.body.appendChild(svg);
        const cmap = new Image();
        cmap.src = "#{@cmapData}";
        const mapNames = #{JSON.encode!(@cmapNames)};

        cmap.onload = (evt) => {
          evt.currentTarget.style.display = "none";
          const canvas = document.createElement("canvas");
          canvas.width = 256;
          canvas.height = evt.currentTarget.height;
          const ctx = canvas.getContext("2d");

          ctx.drawImage(
            evt.currentTarget,
            0,
            0,
            evt.currentTarget.width,
            evt.currentTarget.height,
            0,
            0,
            256,
            evt.currentTarget.height,
          );
          let j = 0;
          for (const n of mapNames) {
            const filter = document.createElementNS(svgns, "filter");
            filter.setAttribute("id", 'cmap-'+ n);
            filter.setAttribute("color-interpolation-filters", "sRGB");
            defs.appendChild(filter);

            const feComponentTransfer = document.createElementNS(
              svgns,
              "feComponentTransfer",
            );
            filter.appendChild(feComponentTransfer);
            const data = ctx.getImageData(0, 1 * j, canvas.width, 1).data;

            const r = [],
              g = [],
              b = [];

            for (let i = 0; i < canvas.width; i++) {
              r.push((data[i * 4] / 255).toFixed(6));
              g.push((data[i * 4 + 1] / 255).toFixed(6));
              b.push((data[i * 4 + 2] / 255).toFixed(6));
            }
            for (const [c, t] of Object.entries({
              R: r,
              G: g,
              B: b,
            })) {
              const feFunc = document.createElementNS(svgns, "feFunc" + c);
              feFunc.setAttribute("type", "table");
              feFunc.setAttribute("tableValues", t.slice(0, -3).join(" "));
              feComponentTransfer.appendChild(feFunc);
            }
            j += 1;
          }
          cmapLoaded?.(mapNames);
        };
      }

    }
    """
  end

  asset "main.css" do
    """
    .stacks {
      display: flex;
      flex-direction: row;
      justify-content: start;
      gap: 1em;
      width: 100%;
      overflow: auto;
      flex-wrap: wrap;
    }

    .stack-label {
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
      gap: 1ex;
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
    }

    .plot {
      image-rendering: pixelated;
      object-fit: contain;
      object-position: center;
      width: 100%;
      height: 100%;
      max-width: 20em;
      width: 10em;
      height: auto;
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
      margin: 1em 0 0;
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

    .slider-output {
      min-width: 7em;
      text-align: center;
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

    .image-overlay {
      display: block;
      width: 100%;
      height: 100%;
    }

    .slider-list {
      display: flex;
      padding: 0 1em;
      background: #eee;
      margin: 1ex 0;
    }

    .slider-body {
      flex-grow: 1;
      display: flex;
    }

    .slider-input {
    accent-color: #48205D;
    flex-grow: 1;
    padding: 1ex 0;
    margin: 0;
    }
    """
  end
end
