import { Group } from "three";
import { Position } from "geojson";
type RGB = `rgb(${number}, ${number}, ${number})`;
type RGBA = `rgba(${number}, ${number}, ${number}, ${number})`;
type HEX = `#${string}`;
type Color = RGB | RGBA | HEX | string;
export declare const InitConfig: {
    R: number;
    enableZoom: boolean;
    zoom: number;
    earth: {
        color: string;
        material: string;
        dragConfig: {
            rotationSpeed: number;
            inertiaFactor: number;
            disableX: boolean;
            disableY: boolean;
        };
    };
    map: string;
    stopRotateByHover: boolean;
    texture: {
        path: string;
        mixed: boolean;
    };
    bgStyle: {
        color: string;
        opacity: number;
    };
    mapStyle: {
        areaColor: string;
        lineColor: string;
        opacity: number;
    };
    spriteStyle: {
        color: string;
        show: boolean;
    };
    pathStyle: {
        color: string;
        show: boolean;
    };
    flyLineStyle: {
        color: string;
    };
    roadStyle: {
        flyLineStyle: {
            color: string;
        };
        pathStyle: {
            color: string;
        };
    };
    barStyle: {
        color: string;
        width: number;
        height: number;
    };
    hoverRegionStyle: {
        areaColor: string;
        opacity: number;
        show: boolean;
    };
    scatterStyle: {
        color: string;
    };
    wallStyle: {
        color: string;
        opacity: number;
        height: number;
        width: number;
    };
    mapStreamStyle: {
        color: string;
        opacity: number;
        speed: number;
        splitLine: number;
    };
    textMark: {
        style: {
            fontSize: number;
            color: string;
        };
        data: never[];
    };
};
export interface Options {
    dom: HTMLElement;
    map: string;
    cameraType?: string;
    mode?: "2d" | "3d";
    helper?: boolean;
    limitFps?: boolean;
    autoRotate?: boolean;
    rotateSpeed?: number;
    controls?: "custom" | "builtIn";
    light?: "AmbientLight" | "PointLight" | "DirectionalLight" | "RectAreaLight";
    config: Partial<configType>;
}
export type StoreConfig = typeof InitConfig & configType;
export interface TweenParams {
    from: {
        size?: number;
        color?: Color;
        opacity?: number;
    };
    to: {
        size?: number | number[];
        color?: Color | Color[];
        opacity?: number | number[];
    };
}
export interface TweenConfig {
    duration?: number;
    delay?: number;
    repeat?: number;
    onComplete?: (data: any) => void;
    customFigure?: {
        texture: string;
        animate?: false | TweenParams;
        rotate?: false | number;
    };
}
export interface PathStyle {
    color: Color;
    size: number;
    show: boolean;
}
export interface FlyLineStyle extends TweenConfig {
    color: Color;
    size: number;
    img?: string;
}
export interface ScatterStyle extends TweenConfig {
    color: Color;
    size?: number;
}
export interface LessCoordinate {
    lon: number;
    lat: number;
}
export interface Coordinates extends LessCoordinate {
    id?: string | number;
    style?: ScatterStyle;
    [key: string]: any;
}
export interface LineStyle {
    flyLineStyle: Partial<FlyLineStyle>;
    pathStyle: Partial<PathStyle>;
}
export interface RoadStyle {
    flyLineStyle: Partial<FlyLineStyle>;
    pathStyle: Partial<PathStyle>;
}
export interface SpriteStyle {
    color: Color;
    show?: boolean;
    size?: number;
}
export interface BarStyle {
    color: Color;
    width?: number;
    height?: number;
}
export interface DragConfig {
    rotationSpeed: number;
    inertiaFactor: number;
    disableX: boolean;
    disableY: boolean;
}
export interface Earth {
    color: Color;
    material?: "MeshPhongMaterial" | "MeshBasicMaterial" | "MeshLambertMaterial" | "MeshMatcapMaterial" | "MeshNormalMaterial";
    dragConfig?: Partial<DragConfig>;
}
interface MapStyle {
    areaColor?: Color;
    lineColor?: Color;
    opacity?: number | undefined;
}
export interface RegionBaseStyle {
    areaColor?: Color;
    opacity?: number | undefined;
    show?: boolean;
}
export interface TextStyle {
    fontSize: number;
    color: Color;
}
export type TextMark = {
    style?: TextStyle;
    data: {
        text: string;
        position: LessCoordinate;
        style?: Partial<TextStyle>;
    }[];
};
type RegionsStyle = Record<string, RegionBaseStyle>;
export interface configType {
    R: number;
    map: string;
    texture?: {
        path: string;
        mixed: boolean;
    };
    enableZoom?: boolean;
    zoom?: number;
    stopRotateByHover: boolean;
    bgStyle: {
        color: Color;
        opacity?: number;
    };
    earth: Earth;
    mapStyle: MapStyle;
    spriteStyle: SpriteStyle;
    pathStyle: Partial<PathStyle>;
    flyLineStyle: Partial<FlyLineStyle>;
    scatterStyle: Partial<ScatterStyle>;
    roadStyle: Partial<RoadStyle>;
    barStyle: Partial<BarStyle>;
    regions?: RegionsStyle;
    hoverRegionStyle?: RegionBaseStyle;
    wallStyle: Partial<WallStyle>;
    mapStreamStyle: Partial<MapStreamStyle>;
    textMark?: Partial<TextMark>;
}
export interface Coordinates3D {
    x: number;
    y: number;
    z: number;
}
export interface FlyLineData {
    from: Coordinates;
    to: Coordinates;
    style?: Partial<LineStyle>;
    [key: string]: any;
}
export interface RoadData {
    path: LessCoordinate[];
    style?: Partial<RoadStyle>;
    id: string | number;
}
export interface BarData {
    position: LessCoordinate;
    value: number;
    style?: Partial<BarStyle>;
    id?: string | number;
}
export interface WallStyle {
    color: Color;
    opacity: number;
    height: number;
    width: number;
}
export interface MapStreamStyle {
    color: Color;
    opacity: number;
    speed: number;
    splitLine: number;
}
export interface SetData {
    flyLine: FlyLineData[];
    point: Coordinates[];
    road: RoadData[];
    wall: {
        data: Position[][];
        style?: Partial<WallStyle>;
    };
    mapStreamLine: {
        data: Position[][];
        style?: Partial<MapStreamStyle>;
    };
    bar: BarData[];
}
export type OptDataFunc = (type: keyof SetData, data: any, mainContainer?: Group) => Promise<Group[]>;
export {};
