import ChartScene from "./chartScene";
import { Options } from '../lib/interface';
import { FeatureCollection } from "geojson";
declare function init(params: Partial<Options>): ChartScene;
declare function registerMap(name: string, map: FeatureCollection): void;
declare const _default: {
    init: typeof init;
    registerMap: typeof registerMap;
};
export default _default;
