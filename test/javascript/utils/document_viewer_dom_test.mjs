import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  PANEL_SELECTOR,
  SLOT_SELECTOR,
  focusDrawerForViewerEscape,
  removeViewerFromDom,
  viewerPanelElement,
} from "../../../app/javascript/utils/document_viewer_dom.js";

function mockDocument({ panel = true, slot = true } = {}) {
  const panelNode = panel ? { removed: false, remove() { this.removed = true; } } : null;
  const slotNode = slot ? { removed: false, remove() { this.removed = true; } } : null;

  return {
    panelNode,
    slotNode,
    querySelectorAll(selector) {
      if (selector === PANEL_SELECTOR && panelNode && !panelNode.removed) return [panelNode];
      if (selector === SLOT_SELECTOR && slotNode && !slotNode.removed) return [slotNode];
      return [];
    },
    querySelector(selector) {
      return this.querySelectorAll(selector)[0] ?? null;
    },
  };
}

describe("document_viewer_dom", () => {
  it("removeViewerFromDom removes the panel and dialog slot", () => {
    const doc = mockDocument();

    assert.ok(viewerPanelElement(doc));
    removeViewerFromDom(doc);

    assert.equal(doc.panelNode.removed, true);
    assert.equal(doc.slotNode.removed, true);
    assert.equal(viewerPanelElement(doc), null);
  });

  it("focusDrawerForViewerEscape focuses dialog content", () => {
    const content = {
      attributes: {},
      hasAttribute(name) {
        return Object.hasOwn(this.attributes, name);
      },
      setAttribute(name, value) {
        this.attributes[name] = value;
      },
      focused: false,
      focus() {
        this.focused = true;
      },
    };
    const dialog = {
      querySelector(selector) {
        if (selector.includes("dialog-target")) return content;
        return null;
      },
    };

    assert.equal(focusDrawerForViewerEscape(dialog), true);
    assert.equal(content.attributes.tabindex, "-1");
    assert.equal(content.focused, true);
  });
});
