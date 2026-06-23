import type { FaliuMeritBenefit } from "./faliu-merit-benefits";
import { T0273_JUAN_1_MERIT_BENEFITS as T0273_JUAN_1_BASE_MERIT_BENEFITS } from "./faliu-merit-benefits-t0273-base";
import { T0273_JUAN_1_RULAIZANG_MERIT_BENEFITS } from "./faliu-merit-benefits-t0273-rulaizang";

export const T0273_JUAN_1_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...T0273_JUAN_1_BASE_MERIT_BENEFITS,
  ...T0273_JUAN_1_RULAIZANG_MERIT_BENEFITS,
];
