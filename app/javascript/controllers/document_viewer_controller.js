import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

const MARGIN_PX = 12;
const LG_BREAKPOINT_PX = 1024;
const NO_DRAWER_MAX_WIDTH_PX = 960;
const DRAWER_FALLBACK_RIGHT = "calc(min(525px, 40vw) + 24px)";

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
    this.boundOnTransitionEnd = this.onTransitionEnd.bind(this);

    window.addEventListener("resize", this.boundLayout);
    document.addEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.addEventListener("turbo:frame-render", this.boundOnFrameLoad);

    this.observeDrawer();
    this.scheduleLayout();
  }

  disconnect() {
    window.removeEventListener("resize", this.boundLayout);
    document.removeEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.removeEventListener("turbo:frame-render", this.boundOnFrameLoad);
    this.resizeObserver?.disconnect();
    this.drawerObserver?.disconnect();
    this.detachTransitionListeners();
  }

  close() {
    if (!this.hasPanelTarget || !this.clearUrlValue) return;

    Turbo.visit(this.clearUrlValue, { frame: "document_viewer" });
  }

  onFrameLoad(event) {
    const frame = event.target;
    if (frame.id !== "document_viewer" && !frame.querySelector?.("#document_viewer")) return;

    this.scheduleLayout();
  }

  onTransitionEnd(event) {
    if (!this.isDrawerTransition(event.target)) return;

    this.layout();
  }

  observeDrawer() {
    const drawer = document.querySelector("turbo-frame#drawer");
    if (!drawer) return;

    this.resizeObserver = new ResizeObserver(this.boundLayout);
    this.resizeObserver.observe(drawer);

    const sidebar = document.querySelector("[data-app-layout-target='leftSidebar']");
    if (sidebar) this.resizeObserver.observe(sidebar);

    this.drawerObserver = new MutationObserver(() => this.scheduleLayout());
    this.drawerObserver.observe(drawer, { childList: true, subtree: true, attributes: true });

    this.attachTransitionListeners(drawer);
  }

  attachTransitionListeners(drawer) {
    this.detachTransitionListeners();

    this.transitionElements = drawer.querySelectorAll(
      "dialog, dialog [data-DS--dialog-target='content'], dialog [data-ds--dialog-target='content']",
    );
    this.transitionElements.forEach((element) => {
      element.addEventListener("transitionend", this.boundOnTransitionEnd);
      element.addEventListener("animationend", this.boundOnTransitionEnd);
    });
  }

  detachTransitionListeners() {
    this.transitionElements?.forEach((element) => {
      element.removeEventListener("transitionend", this.boundOnTransitionEnd);
      element.removeEventListener("animationend", this.boundOnTransitionEnd);
    });
    this.transitionElements = null;
  }

  scheduleLayout() {
    this.layout();
    requestAnimationFrame(() => {
      this.layout();
      requestAnimationFrame(() => this.layout());
    });
    window.setTimeout(() => this.layout(), 50);
    window.setTimeout(() => this.layout(), 320);
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
    const drawerPanel = this.drawerPanelElement();
    const top = `calc(${MARGIN_PX}px + env(safe-area-inset-top, 0px))`;
    const bottom = `calc(${MARGIN_PX}px + env(safe-area-inset-bottom, 0px))`;
    const leftInset = this.contentAreaLeft();

    panel.style.position = "fixed";
    panel.style.top = top;
    panel.style.bottom = bottom;
    panel.style.height = "";
    panel.style.maxWidth = "";
    panel.style.marginLeft = "";
    panel.style.marginRight = "";

    if (drawerPanel && isLarge) {
      this.attachTransitionListeners(document.querySelector("turbo-frame#drawer"));

      const drawerLeft = drawerPanel.getBoundingClientRect().left;
      const gap = MARGIN_PX * 2;
      const usableWidth = drawerLeft - leftInset - gap;

      panel.style.left = `${leftInset}px`;

      if (usableWidth > 80) {
        panel.style.right = `${viewportWidth - drawerLeft + MARGIN_PX}px`;
        panel.style.width = "auto";
      } else {
        panel.style.right = DRAWER_FALLBACK_RIGHT;
        panel.style.width = "auto";
      }
    } else if (drawerPanel && !isLarge) {
      panel.style.left = `${leftInset}px`;
      panel.style.right = `${MARGIN_PX}px`;
      panel.style.width = "auto";
      panel.style.bottom = "auto";
      panel.style.height = `min(45vh, calc(100vh - ${MARGIN_PX * 2}px))`;
    } else {
      const width = Math.min(NO_DRAWER_MAX_WIDTH_PX, viewportWidth - leftInset - MARGIN_PX);
      const left = Math.max(leftInset, Math.floor((viewportWidth - width) / 2));

      panel.style.left = `${left}px`;
      panel.style.width = `${width}px`;
      panel.style.right = "auto";
    }
  }

  drawerPanelElement() {
    const dialog = this.openDrawerDialog();
    if (!dialog) return null;

    const content =
      dialog.querySelector("[data-DS--dialog-target='content']") ||
      dialog.querySelector("[data-ds--dialog-target='content']");

    return content || dialog;
  }

  openDrawerDialog() {
    const drawer = document.querySelector("turbo-frame#drawer");
    if (!drawer) return null;

    const dialog = drawer.querySelector("dialog[open]");
    return dialog?.matches(":modal, [open]") ? dialog : null;
  }

  contentAreaLeft() {
    const sidebar = document.querySelector("[data-app-layout-target='leftSidebar']");
    if (!sidebar) return MARGIN_PX;

    const rect = sidebar.getBoundingClientRect();
    if (rect.width < 8 || sidebar.classList.contains("w-0")) return MARGIN_PX;

    return Math.round(rect.right + MARGIN_PX);
  }

  isDrawerTransition(target) {
    const drawer = document.querySelector("turbo-frame#drawer");
    return Boolean(drawer && drawer.contains(target));
  }
}
