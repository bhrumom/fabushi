import { OptDataFunc } from "./interface";
import { Group, Object3D } from "three";
import Store from '../lib/store/store';
export default class OperateView {
    private readonly _store;
    constructor(store: Store);
    addData: OptDataFunc;
    setData: OptDataFunc;
    remove(mainContainer: Object3D, type: string, ids: string[] | "removeAll"): void;
    disposeGroup(group: Group): void;
}
