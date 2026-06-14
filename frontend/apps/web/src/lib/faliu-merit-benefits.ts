export * from "./faliu-merit-benefits-original";
export { T0263_JUAN_10_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10";

import { getFaliuMeritBenefits as getBaseFaliuMeritBenefits } from "./faliu-merit-benefits-original";
import { T0263_JUAN_10_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10";

export function getFaliuMeritBenefits(work: string | null | undefined, juan: string | number | null | undefined) {
  const normalizedWork = work?.trim().toUpperCase();
  const normalizedJuan = String(juan ?? "1").replace(/^0+(?=\d)/, "") || "1";

  if (normalizedWork === "T0263" && normalizedJuan === "10") return T0263_JUAN_10_MERIT_BENEFITS;

  return getBaseFaliuMeritBenefits(work, juan);
}
