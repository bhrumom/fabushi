import { ExtrudeGeometry, Mesh, MeshBasicMaterial, Vector3 } from "three";
import Store from '../../lib/store/store';
import { WallStyle } from '../../lib/interface';
import { Position } from "geojson";
export declare class Wall {
    private readonly _config;
    private readonly _store;
    private _currentStyle;
    constructor(store: Store);
    createShape(points: Vector3[]): Mesh<ExtrudeGeometry, MeshBasicMaterial>;
    create(data: {
        data: Position[][];
        style: WallStyle;
    }): undefined;
    getCurrentStyle(style: WallStyle): void;
}
