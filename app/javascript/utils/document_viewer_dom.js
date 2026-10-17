export const PANEL_SELECTOR = "[data-document-viewer-panel]";
export const SLOT_SELECTOR = "[data-document-viewer-slot]";

export function viewerPanelElement(doc = document) {
  return doc.querySelector(PANEL_SELECTOR);
}

export function removeViewerFromDom(doc = document) {
  doc.querySelectorAll(PANEL_SELECTOR).forEach((panel) => panel.remove());
  doc.querySelectorAll(SLOT_SELECTOR).forEach((slot) => slot.remove());
}

export function drawerContentFocusTarget(dialog) {
  if (!dialog) return null;

  return (
    dialog.querySelector("[data-DS--dialog-target='content']") ||
    dialog.querySelector("[data-ds--dialog-target='content']")
  );
}

export function focusDrawerForViewerEscape(dialog) {
  const target = drawerContentFocusTarget(dialog);
  if (!target) return false;

  if (!target.hasAttribute("tabindex")) {
    target.setAttribute("tabindex", "-1");
  }

  target.focus({ preventScroll: true });
  return true;
}
