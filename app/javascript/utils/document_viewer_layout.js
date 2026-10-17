export const MARGIN_PX = 12;
export const LG_BREAKPOINT_PX = 1024;
export const NO_DRAWER_MAX_WIDTH_PX = 960;
export const DRAWER_FALLBACK_RIGHT = "calc(min(525px, 40vw) + 24px)";

export function computePanelStyles({
  viewportWidth,
  drawerLeft,
  leftInset,
  isLarge,
  hasDrawer,
}) {
  const top = `calc(${MARGIN_PX}px + env(safe-area-inset-top, 0px))`;
  const bottom = `calc(${MARGIN_PX}px + env(safe-area-inset-bottom, 0px))`;
  const base = {
    position: "fixed",
    top,
    bottom,
    height: "",
    maxWidth: "",
    marginLeft: "",
    marginRight: "",
  };

  if (hasDrawer && isLarge) {
    const usableWidth = drawerLeft - leftInset - MARGIN_PX * 2;
    const styles = {
      ...base,
      left: `${leftInset}px`,
      width: "auto",
    };

    if (usableWidth > 80) {
      styles.right = `${viewportWidth - drawerLeft + MARGIN_PX}px`;
    } else {
      styles.right = DRAWER_FALLBACK_RIGHT;
    }

    return styles;
  }

  if (hasDrawer && !isLarge) {
    return {
      ...base,
      left: `${leftInset}px`,
      right: `${MARGIN_PX}px`,
      width: "auto",
      bottom: "auto",
      height: `min(45vh, calc(100vh - ${MARGIN_PX * 2}px))`,
    };
  }

  const width = Math.min(NO_DRAWER_MAX_WIDTH_PX, viewportWidth - leftInset - MARGIN_PX);
  const left = Math.max(leftInset, Math.floor((viewportWidth - width) / 2));

  return {
    ...base,
    left: `${left}px`,
    width: `${width}px`,
    right: "auto",
  };
}
