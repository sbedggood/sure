import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

const MARGIN_PX = 12;
const LG_BREAKPOINT_PX = 1024;
const NO_DRAWER_MAX_WIDTH_PX = 960;

// Positions the tax document preview card in the viewport: beside an open
// drawer on large screens, or as a large left/centre panel when alone.
export default class extends Controller {
  static targets = ["panel"];

  static values = {
    clearUrl: String,
  };

  connect() {
    this.boundLayout = this.layout.bind(this);
    this.boundOnFrameLoad = this.onFrameLoad.bind(this);

    window.addEventListener("resize", this.boundLayout);
    document.addEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.addEventListener("turbo:frame-render", this.boundOnFrameLoad);

    this.observeDrawer();
    this.layout();
  }

  disconnect() {
    window.removeEventListener("resize", this.boundLayout);
    document.removeEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.removeEventListener("turbo:frame-render", this.boundOnFrameLoad);
    this.resizeObserver?.disconnect();
  }

  close() {
    if (!this.hasPanelTarget || !this.clearUrlValue) return;

    Turbo.visit(this.clearUrlValue, { frame: "document_viewer" });
  }

  onFrameLoad(event) {
    const frame = event.target;
    if (frame.id !== "document_viewer" && !frame.querySelector?.("#document_viewer")) return;

    queueMicrotask(() => this.layout());
  }

  observeDrawer() {
    const drawer = document.querySelector("turbo-frame#drawer");
    if (!drawer) return;

    this.resizeObserver = new ResizeObserver(this.boundLayout);
    this.resizeObserver.observe(drawer);

    this.drawerObserver = new MutationObserver(this.boundLayout);
    this.drawerObserver.observe(drawer, { childList: true, subtree: true, attributes: true });
  }

  layout() {
    const host = this.element;
    if (!this.hasPanelTarget) {
      host.classList.add("pointer-events-none");
      return;
    }

    host.classList.remove("pointer-events-none");

    const panel = this.panelTarget;
    const viewportWidth = window.innerWidth;
    const isLarge = viewportWidth >= LG_BREAKPOINT_PX;
    const dialog = this.openDrawerDialog();
    const top = `calc(${MARGIN_PX}px + env(safe-area-inset-top, 0px))`;
    const bottom = `calc(${MARGIN_PX}px + env(safe-area-inset-bottom, 0px))`;

    panel.style.position = "fixed";
    panel.style.top = top;
    panel.style.bottom = bottom;
    panel.style.height = "";
    panel.style.maxWidth = "";

    if (dialog && isLarge) {
      const drawerLeft = dialog.getBoundingClientRect().left;
      const width = Math.max(240, drawerLeft - MARGIN_PX * 2);

      panel.style.left = `${MARGIN_PX}px`;
      panel.style.width = `${width}px`;
      panel.style.right = "auto";
      panel.style.marginLeft = "";
      panel.style.marginRight = "";
    } else if (dialog && !isLarge) {
      panel.style.left = `${MARGIN_PX}px`;
      panel.style.right = `${MARGIN_PX}px`;
      panel.style.width = "auto";
      panel.style.bottom = "auto";
      panel.style.height = `min(45vh, calc(100vh - ${MARGIN_PX * 2}px))`;
    } else {
      const width = Math.min(NO_DRAWER_MAX_WIDTH_PX, viewportWidth - MARGIN_PX * 2);
      const left = Math.max(MARGIN_PX, Math.floor((viewportWidth - width) / 2));

      panel.style.left = `${left}px`;
      panel.style.width = `${width}px`;
      panel.style.right = "auto";
      panel.style.marginLeft = "";
      panel.style.marginRight = "";
    }
  }

  openDrawerDialog() {
    const drawer = document.querySelector("turbo-frame#drawer");
    if (!drawer) return null;

    const dialog = drawer.querySelector("dialog[open]");
    return dialog?.matches(":modal, [open]") ? dialog : null;
  }
}
