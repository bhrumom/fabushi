export * from "./faliu-merit-benefits-original";
export { T0263_JUAN_10_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10";
export { T0263_JUAN_10_ZONGCHI_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-zongchi";
export { T0263_JUAN_10_JINGFU_JINGWANG_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-jingfu-jingwang";
export { T0263_JUAN_10_LEPUXIAN_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-lepuxian";
export { T0263_JUAN_10_ZHULEI_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-zhulei";

import { getFaliuMeritBenefits as getBaseFaliuMeritBenefits } from "./faliu-merit-benefits-original";
import { T0263_JUAN_10_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10";
import { T0263_JUAN_10_ZONGCHI_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-zongchi";
import { T0263_JUAN_10_JINGFU_JINGWANG_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-jingfu-jingwang";
import { T0263_JUAN_10_LEPUXIAN_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-lepuxian";
import { T0263_JUAN_10_ZHULEI_MERIT_BENEFITS } from "./faliu-merit-benefits-t0263-juan10-zhulei";

export function getFaliuMeritBenefits(work: string | null | undefined, juan: string | number | null | undefined) {
  const normalizedWork = work?.trim().toUpperCase();
  const normalizedJuan = String(juan ?? "1").replace(/^0+(?=\d)/, "") || "1";

  if (normalizedWork === "T0263" && normalizedJuan === "10") {
    return [
      ...T0263_JUAN_10_MERIT_BENEFITS,
      ...T0263_JUAN_10_ZONGCHI_MERIT_BENEFITS,
      ...T0263_JUAN_10_JINGFU_JINGWANG_MERIT_BENEFITS,
      ...T0263_JUAN_10_LEPUXIAN_MERIT_BENEFITS,
      ...T0263_JUAN_10_ZHULEI_MERIT_BENEFITS,
    ];
  }

  return getBaseFaliuMeritBenefits(work, juan);
}
