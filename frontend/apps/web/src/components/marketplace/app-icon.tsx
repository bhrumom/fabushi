import type { MarketplaceIconTone } from "../../lib/marketplace";
import styles from "./marketplace.module.css";

type AppIconProps = {
  label: string;
  tone: MarketplaceIconTone;
  size?: "small" | "medium" | "large";
};

export function AppIcon({ label, tone, size = "medium" }: AppIconProps) {
  return (
    <span
      className={`${styles.appIcon} ${styles[`tone${tone[0].toUpperCase()}${tone.slice(1)}`]} ${
        size === "small" ? styles.appIconSmall : size === "large" ? styles.appIconLarge : ""
      }`}
      aria-hidden="true"
    >
      <span>{label}</span>
    </span>
  );
}
