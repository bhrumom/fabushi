import { Feature } from "geojson";
declare class MapStore {
    hashMap: Record<any, Feature[]>;
    registerMap(name: string, json: Feature[]): void;
}
declare const _default: MapStore;
export default _default;
