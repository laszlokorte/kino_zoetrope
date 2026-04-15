function hsvToRgb(h, s, v) {
  let r = 0,
    g = 0,
    b = 0;
  let i = Math.floor(h * 6);
  let f = h * 6 - i;
  let p = v * (1 - s);
  let q = v * (1 - f * s);
  let t = v * (1 - (1 - f) * s);
  switch (i % 6) {
    case 0:
      r = v;
      g = t;
      b = p;
      break;
    case 1:
      r = q;
      g = v;
      b = p;
      break;
    case 2:
      r = p;
      g = v;
      b = t;
      break;
    case 3:
      r = p;
      g = q;
      b = v;
      break;
    case 4:
      r = t;
      g = p;
      b = v;
      break;
    case 5:
      r = v;
      g = p;
      b = q;
      break;
  }
  return [r, g, b];
}

function sliderListener(figure, slider, sliderOutput) {
  return (evt) => {
    const imgs = figure.querySelectorAll(".stack img");
    const activeImgs = figure.querySelectorAll(
      ".stack img:nth-of-type(" + (slider.valueAsNumber + 1) + ")",
    );
    Array.prototype.forEach.call(imgs, (c, i) => {
      c.style.zIndex = 0;
    });
    Array.prototype.forEach.call(activeImgs, (c, i) => {
      c.style.zIndex = 1;
    });

    const markers = figure.querySelectorAll(".stack .image-marker");
    const activeMarkers = figure.querySelectorAll(
      ".stack .image-marker:nth-of-type(" + (slider.valueAsNumber + 1) + ")",
    );
    Array.prototype.forEach.call(markers, (c, i) => {
      c.classList.add("image-marker-hidden");
    });
    Array.prototype.forEach.call(activeMarkers, (c, i) => {
      c.classList.remove("image-marker-hidden");
    });
    sliderOutput.value = `${slider.valueAsNumber} / ${slider.max}`;
  };
}

function pointerListener(svg, slider, s) {
  const pt = svg.createSVGPoint();
  return (evt) => {
    if (evt.buttons === 1) {
      console.log(evt.target, evt.target.hasAttribute("marker-frame-id"));
      pt.x = evt.clientX;
      pt.y = evt.clientY;
      const { x, y } = pt.matrixTransform(svg.getScreenCTM().inverse());
      const intx = Math.floor(x);
      const inty = Math.floor(y);

      let frame = null;
      outer: for (let m of s.markers) {
        let pi = 0;
        for (let p of m.points) {
          if (
            p.x <= intx &&
            p.y <= inty &&
            p.x + (m.attrs?.width ?? 1) > intx &&
            p.y + (m.attrs?.height ?? 1) > inty
          ) {
            if (frame !== null && pi > slider.value) {
              break outer;
            }
            frame = pi;
          }
          pi++;
        }
      }

      if (frame !== null) {
        slider.value = frame;
        slider.dispatchEvent(new Event("input", { bubbles: true }));
      }
    }
  };
}

export function init(ctx, args) {
  const svgNs = "http://www.w3.org/2000/svg";

  ctx.importCSS("main.css");

  const numf = new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  });
  const numd = new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 0,
    minimumFractionDigits: 0,
  });

  const figure = document.createElement("figure");
  figure.classList.add("plot-figure");
  const figCaption = document.createElement("figCaption");
  const figCaptionTitle = document.createElement("strong");
  figCaptionTitle.appendChild(document.createTextNode(args.titel));

  const sliderList = document.createElement("dl");
  const sliderHead = document.createElement("dt");
  const sliderBody = document.createElement("dd");
  const slider = document.createElement("input");
  const sliderOutput = document.createElement("output");

  const maxPoints = (args.stacks ?? [])
    .flatMap((s) => (s.markers ?? []).map((m) => m.points?.length ?? 0))
    .reduce((a, b) => Math.max(a, b), 0);
  const maxFrame =
    args.stacks
      .map((f) => f.frames)
      .reduce((a, b) => Math.max(a, b), maxPoints) - 1;
  slider.setAttribute("type", "range");
  slider.setAttribute("min", "0");
  slider.setAttribute("max", maxFrame);
  slider.classList.add("slider-input");

  slider.value = 0;
  sliderOutput.value = `0 / ${maxFrame}`;
  sliderOutput.classList.add("slider-output");

  sliderHead.appendChild(document.createTextNode(args.frame_label));

  sliderBody.classList.add("slider-body");
  sliderBody.appendChild(slider);
  sliderBody.appendChild(sliderOutput);

  sliderList.classList.add("slider-list");
  sliderList.appendChild(sliderHead);
  sliderList.appendChild(sliderBody);

  figCaption.appendChild(figCaptionTitle);
  if (maxFrame > 0) {
    figCaption.appendChild(sliderList);
  }
  figure.appendChild(figCaption);

  const stacks = document.createElement("div");
  stacks.classList.add("stacks");
  const images = new DocumentFragment();

  const hasLegend = Array.prototype.some.call(
    args.stacks,
    (s) => s.channels === 1 && s.legend,
  );

  for (let s of args.stacks) {
    const fmt = s.float ? numf : numd;
    const stackContainer = document.createElement("div");
    stackContainer.classList.add("image-with-desc");

    const stackOuter = document.createElement("div");
    stackOuter.classList.add("stack-outer");
    const stack = document.createElement("div");
    stack.classList.add("stack");

    if (hasLegend) {
      stack.classList.add("has-legend");
    }
    if (s.resize) {
      stack.classList.add("resize");
    }
    if (s.size && s.size.x) {
      stack.style.width = parseFloat(s.size.x) + "px";
    }
    if (s.size && s.size.y) {
      stack.style.height = parseFloat(s.size.y) + "px";
    }
    stack.classList.add("image-with-desc-image");

    if (s.show_label) {
      const stackLabel = document.createElement("div");
      stackLabel.classList.add("stack-label");

      stackLabel.appendChild(document.createTextNode(s.label));
      stackContainer.appendChild(stackLabel);
    }

    const metaFrag = new DocumentFragment();
    if (args.show_meta) {
      const meta_args =
        args.show_meta === true
          ? { type: "Type", real_min: "Min", real_max: "Max" }
          : args.show_meta;
      const metaList = document.createElement("dl");
      const metaListSizeKey = document.createElement("dt");
      metaListSizeKey.appendChild(document.createTextNode("Size"));
      const metaListSizeValue = document.createElement("dd");
      metaListSizeValue.appendChild(
        document.createTextNode(`${s.width} × ${s.height} × ${s.channels}`),
      );
      metaList.appendChild(metaListSizeKey);
      metaList.appendChild(metaListSizeValue);

      for (let [k, v] of Object.entries(meta_args)) {
        const metaListKey = document.createElement("dt");
        metaListKey.appendChild(document.createTextNode(v));
        const metaListValue = document.createElement("dd");
        const formatted = typeof s[k] == "number" ? fmt.format(s[k]) : s[k];
        metaListValue.appendChild(document.createTextNode(`${formatted}`));
        metaList.appendChild(metaListKey);
        metaList.appendChild(metaListValue);
      }

      metaFrag.appendChild(metaList);
    }

    for (let i of s.images) {
      const img = document.createElement("img");
      img.src = i.data;
      img.style.zIndex = i.index;
      img.setAttribute("width", i.width);
      img.setAttribute("height", i.height);
      const aspect = i.width / i.height;
      const maxSize = 20;

      img.style.zIndex = i.index;
      img.classList.add("plot");
      if (s.sharp) {
        img.classList.add("sharp");
      }
      img.classList.add("stack-item");

      if (s.channels == 1 && s.cmap) {
        img.style.filter =
          "url('#cmap-" + s.cmap.replace(/[^a-zA-Z0-9_]/g, "") + "')";
      }

      stack.appendChild(img);
    }
    const imageOverlay = document.createElementNS(svgNs, "svg");

    imageOverlay.classList.add("image-overlay");
    imageOverlay.classList.add("stack-item");
    imageOverlay.setAttribute("viewBox", `0 0 ${s.width} ${s.height}`);
    imageOverlay.setAttribute("preserveAspectRatio", "xMidYMid meet");
    imageOverlay.setAttribute("width", s.width);
    imageOverlay.setAttribute("height", s.height);

    for (let m of s.markers) {
      const g = document.createElementNS(svgNs, "g");

      let pp = 0;
      for (let p of m.points) {
        const r = document.createElementNS(svgNs, "rect");

        r.setAttribute("width", 1);
        r.setAttribute("height", 1);
        r.setAttribute("fill", "white");
        r.setAttribute("opacity", "1");
        r.setAttribute("stroke", "magenta");
        r.setAttribute("vector-effect", "non-scaling-stroke");
        r.setAttribute("stroke-width", "1");

        for (const [k, v] of Object.entries(m.attrs)) {
          r.setAttribute(k, v);
        }

        r.setAttribute("x", p.x);
        r.setAttribute("y", p.y);
        r.setAttribute("marker-frame-id", pp);

        r.classList.add("image-marker");
        r.classList.add("image-marker-hidden");
        if (m.faded) {
          r.classList.add("image-marker-faded");
        }

        g.appendChild(r);
        pp++;
      }

      if (g.firstElementChild) {
        g.firstElementChild.classList.remove("image-marker-hidden");
      }
      imageOverlay.appendChild(g);
    }

    imageOverlay.style.zIndex = 2 * s.images.length;
    stack.appendChild(imageOverlay);
    if (s.x_axis) {
      const xaxis = document.createElement("div");
      xaxis.appendChild(document.createTextNode(s.x_axis));
      xaxis.classList.add("axis-x");
      stackOuter.appendChild(xaxis);
    }

    if (s.y_axis) {
      const yaxis = document.createElement("div");
      yaxis.appendChild(document.createTextNode(s.y_axis));
      yaxis.classList.add("axis-y");
      stackOuter.appendChild(yaxis);
    }

    if (s.channels === 1 && s.legend) {
      const scale = document.createElement("div");
      scale.classList.add("stack-scale");
      const scaleLabels = document.createElement("div");
      scaleLabels.classList.add("scale-labels");

      const scaleGradient = document.createElement("div");
      scaleGradient.classList.add("scale-gradient");
      if (s.cmap) {
        scaleGradient.style.filter =
          "url('#cmap-" + s.cmap.replace(/[^a-zA-Z0-9_]/g, "") + "')";
      }

      const scaleMarkers = document.createElementNS(svgNs, "svg");
      scaleMarkers.classList.add("scale-markers");
      scaleMarkers.setAttribute("viewBox", "0 0 100 100");
      scaleMarkers.setAttribute("preserveAspectRatio", "none");
      scaleMarkers.setAttribute("width", 100);
      scaleMarkers.setAttribute("height", 100);

      if (s.legend_markers) {
        for (const [l, c] of Object.entries({
          real_min: "red",
          real_max: "cyan",
        })) {
          const scaleMarkerRange = document.createElementNS(svgNs, "line");
          const minY = 100 * ((s[l] - s.out_min) / (s.out_max - s.out_min));
          scaleMarkerRange.setAttribute("x1", -100);
          scaleMarkerRange.setAttribute("x2", 200);
          scaleMarkerRange.setAttribute("y1", numf.format(100 - minY));
          scaleMarkerRange.setAttribute("y2", numf.format(100 - minY));
          scaleMarkerRange.setAttribute("stroke", c);
          scaleMarkerRange.setAttribute("opacity", 0.5);
          scaleMarkerRange.setAttribute("stroke-width", "4");
          scaleMarkerRange.setAttribute("vector-effect", "non-scaling-stroke");

          scaleMarkers.appendChild(scaleMarkerRange);
        }
        scaleGradient.appendChild(scaleMarkers);
      }

      scale.append(scaleGradient);

      if (s.legend_labels) {
        const scaleTop = document.createElement("div");
        scaleTop.classList.add("scale-label");
        scaleTop.appendChild(document.createTextNode(fmt.format(s.out_max)));

        const scaleBottom = document.createElement("div");
        scaleBottom.classList.add("scale-label");
        scaleBottom.appendChild(document.createTextNode(fmt.format(s.out_min)));

        scaleLabels.appendChild(scaleTop);
        scaleLabels.appendChild(scaleBottom);
        scale.append(scaleLabels);
      }

      stackOuter.append(scale);
    }

    stackOuter.appendChild(stack);
    stackContainer.appendChild(stackOuter);
    stackContainer.appendChild(metaFrag);
    stacks.appendChild(stackContainer);

    const pl = pointerListener(imageOverlay, slider, s);
    imageOverlay.addEventListener("pointerdown", (evt) => {
      evt.currentTarget.setPointerCapture(evt.pointerId);
      pl(evt);
    });
    imageOverlay.addEventListener("pointermove", pl);
  }
  figure.appendChild(stacks);
  ctx.root.appendChild(figure);

  slider.addEventListener(
    "input",
    sliderListener(figure, slider, sliderOutput),
  );

  function loadColorMap(evt) {
    const svgns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgns, "svg");
    svg.setAttribute("width", "0");
    svg.setAttribute("height", "0");
    const defs = document.createElementNS(svgns, "defs");
    svg.appendChild(defs);
    document.body.appendChild(svg);
    const mapNames = JSON.parse(cmap.getAttribute("data-colornames"));
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
      filter.setAttribute("id", "cmap-" + n);
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
        feFunc.setAttribute("tableValues", t.join(" "));
        feComponentTransfer.appendChild(feFunc);
      }
      j += 1;
    }
  }
  const cmap = new Image();
  cmap.addEventListener("load", loadColorMap);

  cmap.setAttribute("data-colornames", args.cmap_names);
  cmap.src = args.cmap_data;
}
