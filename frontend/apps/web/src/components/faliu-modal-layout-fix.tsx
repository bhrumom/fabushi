export function FaliuModalLayoutFix() {
  return (
    <style
      suppressHydrationWarning
      dangerouslySetInnerHTML={{
        __html: `
section[aria-label="法流"] [role="dialog"][aria-modal="true"] {
  display: flex !important;
  flex-direction: column !important;
  height: calc(100svh - 36px) !important;
  max-height: calc(100svh - 36px) !important;
}

section[aria-label="法流"] [role="dialog"][aria-modal="true"] [class*="modalHeader"],
section[aria-label="法流"] [role="dialog"][aria-modal="true"] [class*="modalMeta"] {
  flex: 0 0 auto !important;
}

section[aria-label="法流"] [role="dialog"][aria-modal="true"] [class*="modalTabs"] {
  flex: 0 1 auto !important;
  max-height: min(18svh, 126px) !important;
  overflow-y: auto !important;
  overscroll-behavior: contain !important;
  align-content: flex-start !important;
  padding-bottom: 12px !important;
  scrollbar-width: thin;
}

section[aria-label="法流"] [role="dialog"][aria-modal="true"] [class*="modalBody"] {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  height: auto !important;
  max-height: none !important;
  overflow: hidden !important;
}

@media (max-width: 760px) {
  section[aria-label="法流"] [role="dialog"][aria-modal="true"] {
    height: 100svh !important;
    max-height: 100svh !important;
  }

  section[aria-label="法流"] [role="dialog"][aria-modal="true"] [class*="modalTabs"] {
    max-height: 104px !important;
  }
}
        `,
      }}
    />
  );
}
