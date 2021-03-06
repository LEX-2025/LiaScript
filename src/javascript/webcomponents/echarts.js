import echarts from 'echarts'

var style = "width: 100%; height: 400px;"

customElements.define('e-charts', class extends HTMLElement {
  static get observedAttributes() {
    return ["style", "option", "mode"];
  }

  constructor () {
    super()
    const shadowRoot = this.attachShadow({ mode: 'open' })

    let div = document.createElement('div')
    div.style = style
    div.id = "container"

    shadowRoot.appendChild(div)

    let self = this
    window.addEventListener("resize", function() {
      self.resizeChart();
    });
  }

  connectedCallback () {
    if (!this.chart) {
      let container = this.shadowRoot.querySelector("#container")
      this.chart = echarts.init(container, this.mode)
      this.updateChart()
    }
  }

  disconnectedCallback () {
    if (super.disconnectedCallback) {
      super.disconnectedCallback()
    }
    echarts.dispose(this.chart);
    let container = this.shadowRoot.querySelector("#container")
  }

  attributeChangedCallback(name, oldValue, newValue) {
    if (name === "option") {
      this.updateChart();
    } else if (name === "style") {
      let container = this.shadowRoot.querySelector("#container");
      if (container) {
        container.style = style + newValue;
      }
      this.resizeChart();
    } else if (name === "mode") {
        if (!this.chart)
          return;

        echarts.dispose(this.chart);
        let container = this.shadowRoot.querySelector("#container")
        this.chart = echarts.init(container, newValue)
        this.updateChart();
    }
  }

  updateChart() {
    if (!this.chart) return;

    //this.chart.clear();

    let option = JSON.parse(this.option || "{}");

    console.warn(option);

    //this.chart.setOption({},true);
    this.chart.setOption(option, true);
    //this.resizeChart()
  }

  resizeChart() {
    if (!this.chart) return;

    this.chart.resize()
  }

  get option() {
    if (this.hasAttribute("option")) {
      return this.getAttribute("option");
    } else {
      return "{}";
    }
  }

  set option(val) {
    if (val) {
      this.setAttribute("option", val);
    } else {
      this.setAttribute("option", "{}");
    }
    this.updateChart();
  }

  get mode() {
    if (this.hasAttribute("mode")) {
      return this.getAttribute("mode");
    } else {
      return "";
    }
  }

  set mode(val) {
    alert (val)
    if (val) {
      this.setAttribute("mode", val);
    } else {
      this.setAttribute("mode", "");
    }
    this.updateChart();
  }
})
