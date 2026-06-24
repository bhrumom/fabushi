import type { FaliuMeritBenefit } from "./faliu-merit-benefits";
import { T0276_JUAN_1_OPENING_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-opening";
import { T0276_JUAN_1_SHUOFAPIN_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shuofapin";
import { T0276_JUAN_1_SHIGONGDE_OPENING_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shigongde-opening";

export const T0276_JUAN_1_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...T0276_JUAN_1_OPENING_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHUOFAPIN_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHIGONGDE_OPENING_MERIT_BENEFITS,
];
