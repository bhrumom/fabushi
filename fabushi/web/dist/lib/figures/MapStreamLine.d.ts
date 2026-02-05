import { BufferGeometry, Color, Line, ShaderMaterial, Vector3 } from "three";
import { MapStreamStyle } from '../../lib/interface';
import Store from '../../lib/store/store';
import { Position } from "geojson";
export default class MapStreamLine {
    private readonly _config;
    private readonly _store;
    private _currentStyle;
    singleUniforms: {
        u_time: {
            value: number;
        };
        number: {
            type: string;
            value: number;
        };
        speed: {
            type: string;
            value: number;
        };
        length: {
            type: string;
            value: number;
        };
        size: {
            type: string;
            value: number;
        };
        color: {
            type: string;
            value: Color;
        };
    };
    constructor(store: Store);
    createFlowingLight(points: Vector3[]): Line<BufferGeometry<import("three").NormalBufferAttributes>, ShaderMaterial>;
    create(data: {
        data: Position[][];
        style: MapStreamStyle;
    }): undefined;
    getCurrentStyle(style: MapStreamStyle): void;
    startAnimation(): void;
}
