import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";
import { computePanelStyles, LG_BREAKPOINT_PX } from "utils/document_viewer_layout";
import {
  PANEL_SELECTOR,
  SLOT_SELECTOR,
  focusDrawerForViewerEscape,
  removeViewerFromDom,
  viewerPanelElement,
} from "utils/document_viewer_dom";

// Tax document preview: mounts inside the open drawer <dialog> so controls stay
// interactive above the modal backdrop; clears when the drawer closes.
export default class extends Controller {
  static values = {
    clearUrl: String,
  };

  connect() {
    this.boundLayout = this.layout.bind(this);
    this.boundOnFrameLoad = this.onFrameLoad.bind(this);
    this.boundOnTransitionEnd = this.onTransitionEnd.bind(this);
    this.boundOnDrawerClose = this.onDrawerClose.bind(this);
    this.boundBeforeFrameRender = this.onBeforeFrameRender.bind(this);
    this.boundOnCloseClick = this.onCloseClick.bind(this);
    this.boundOnDialogCancel = this.onDialogCancel.bind(this);

    window.addEventListener("resize", this.boundLayout);
    document.addEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.addEventListener("turbo:frame-render", this.boundOnFrameLoad);
    document.addEventListener("click", this.boundOnCloseClick);
    document.addEventListener("turbo:before-frame-render", this.boundBeforeFrameRender);

    this.observeDrawer();
    this.scheduleLayout();
  }

  disconnect() {
    window.removeEventListener("resize", this.boundLayout);
    document.removeEventListener("turbo:frame-load", this.boundOnFrameLoad);
    document.removeEventListener("turbo:frame-render", this.boundOnFrameLoad);
    document.removeEventListener("click", this.boundOnCloseClick);
    document.removeEventListener("turbo:before-frame-render", this.boundBeforeFrameRender);
    this.resizeObserver?.disconnect();
    this.drawerObserver?.disconnect();
    this.detachTransitionListeners();
    this.unbindDrawerDialogClose();
  }

  close(event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.clearViewer();
  }

  onCloseClick(event) {
    if (!event.target.closest("[data-document-viewer-close]")) return;

    this.close(event);
  }

  onDialogCancel(event) {
    if (!viewerPanelElement()) return;

    event.preventDefault();
    this.clearViewer();
  }

  clearViewer() {
    removeViewerFromDom();
    this.syncHostPointerEvents();

    if (this.clearUrlValue) {
      Turbo.visit(this.clearUrlValue, { frame: "document_viewer" });
    }
  }

  onFrameLoad(event) {
    const frame = event.target;

    if (frame.id === "drawer") {
      this.bindDrawerDialogClose();
      this.maybeAutoOpenDrawerAttachment(frame);
      this.scheduleLayout();
      return;
    }

    if (frame.id !== "document_viewer") return;

    this.scheduleLayout();
    this.focusDrawerAfterViewerOpen();
  }

  onBeforeFrameRender(event) {
    const frame = event.target;
    if (frame.id !== "drawer") return;

    const newFrame = event.detail?.newFrame;
    const hasDialog = Boolean(newFrame?.querySelector?.("dialog"));
    const emptyFrame = !newFrame?.innerHTML?.trim();

    if (emptyFrame || !hasDialog) this.clearViewer();
  }

  onDrawerClose() {
    this.clearViewer();
  }

  focusDrawerAfterViewerOpen() {
    requestAnimationFrame(() => {
      const dialog = this.openDrawerDialog();
      if (!dialog || !viewerPanelElement()) return;

      focusDrawerForViewerEscape(dialog);
    });
  }

  maybeAutoOpenDrawerAttachment(drawerFrame) {
    const marker = drawerFrame.querySelector("[data-auto-document-preview-url]");
    const url = marker?.getAttribute("data-auto-document-preview-url");
    if (!url) return;

    Turbo.visit(url, { frame: "document_viewer" });
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

    this.drawerObserver = new MutationObserver(() => {
      this.bindDrawerDialogClose();
      this.scheduleLayout();
    });
    this.drawerObserver.observe(drawer, { childList: true, subtree: true, attributes: true });

    this.attachTransitionListeners(drawer);
    this.bindDrawerDialogClose();
  }

  bindDrawerDialogClose() {
    const dialog = this.openDrawerDialog();
    if (!dialog || dialog === this.boundDialog) return;

    this.unbindDrawerDialogClose();
    this.boundDialog = dialog;
    dialog.addEventListener("close", this.boundOnDrawerClose);
    dialog.addEventListener("cancel", this.boundOnDialogCancel);
  }

  unbindDrawerDialogClose() {
    if (!this.boundDialog) return;

    this.boundDialog.removeEventListener("close", this.boundOnDrawerClose);
    this.boundDialog.removeEventListener("cancel", this.boundOnDialogCancel);
    this.boundDialog = null;
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
    const panel = viewerPanelElement();
    if (!panel) {
      this.syncHostPointerEvents();
      return;
    }

    this.mountPanel(panel);
    this.syncHostPointerEvents();

    const viewportWidth = window.innerWidth;
    const isLarge = viewportWidth >= LG_BREAKPOINT_PX;
    const drawerPanel = this.drawerPanelElement();
    const drawerDialog = this.openDrawerDialog();
    const drawerLeft = drawerPanel?.getBoundingClientRect().left ?? 0;
    const styles = computePanelStyles({
      viewportWidth,
      drawerLeft,
      leftInset: this.contentAreaLeft(),
      isLarge,
      hasDrawer: Boolean(drawerDialog),
    });

    Object.assign(panel.style, styles);
    panel.style.pointerEvents = "auto";
    panel.style.zIndex = drawerDialog ? "1" : "45";
  }

  mountPanel(panel) {
    const dialog = this.openDrawerDialog();
    const frame = document.getElementById("document_viewer");

    if (dialog) {
      const slot = this.ensureDialogSlot(dialog);
      if (panel.parentElement !== slot) slot.appendChild(panel);
      return;
    }

    if (frame && panel.parentElement !== frame) frame.appendChild(panel);
  }

  ensureDialogSlot(dialog) {
    let slot = dialog.querySelector(SLOT_SELECTOR);
    if (slot) return slot;

    slot = document.createElement("div");
    slot.dataset.documentViewerSlot = "";
    slot.className = "fixed inset-0 pointer-events-none";
    slot.style.zIndex = "0";
    dialog.insertBefore(slot, dialog.firstChild);
    return slot;
  }

  drawerPanelElement() {
    const dialog = this.openDrawerDialog();
    if (!dialog) return null;

    return (
      dialog.querySelector("[data-DS--dialog-target='content']") ||
      dialog.querySelector("[data-ds--dialog-target='content']") ||
      dialog
    );
  }

  openDrawerDialog() {
    const drawer = document.querySelector("turbo-frame#drawer");
    if (!drawer) return null;

    const dialog = drawer.querySelector("dialog[open]");
    return dialog?.matches(":modal, [open]") ? dialog : null;
  }

  contentAreaLeft() {
    const sidebar = document.querySelector("[data-app-layout-target='leftSidebar']");
    if (!sidebar) return 12;

    const rect = sidebar.getBoundingClientRect();
    if (rect.width < 8 || sidebar.classList.contains("w-0")) return 12;

    return Math.round(rect.right + 12);
  }

  isDrawerTransition(target) {
    const drawer = document.querySelector("turbo-frame#drawer");
    return Boolean(drawer && drawer.contains(target));
  }

  syncHostPointerEvents() {
    if (viewerPanelElement()) {
      this.element.classList.remove("pointer-events-none");
    } else {
      this.element.classList.add("pointer-events-none");
    }
  }
}
