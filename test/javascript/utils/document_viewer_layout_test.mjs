import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { computePanelStyles, MARGIN_PX } from "../../../app/javascript/utils/document_viewer_layout.js";

describe("computePanelStyles", () => {
  it("fills the gap left of the drawer on large screens", () => {
    const viewportWidth = 1440;
    const drawerLeft = 880;
    const leftInset = 12;

    const styles = computePanelStyles({
      viewportWidth,
      drawerLeft,
      leftInset,
      isLarge: true,
      hasDrawer: true,
    });

    assert.equal(styles.left, `${leftInset}px`);
    assert.equal(styles.right, `${viewportWidth - drawerLeft + MARGIN_PX}px`);
  });

  it("centres a wide panel when no drawer is open", () => {
    const styles = computePanelStyles({
      viewportWidth: 1440,
      drawerLeft: 0,
      leftInset: 12,
      isLarge: true,
      hasDrawer: false,
    });

    assert.equal(styles.width, "960px");
    assert.equal(styles.right, "auto");
  });
});
