import { Options, StoreConfig } from '../../lib/interface';
declare class Store {
    mode: "2d" | "3d";
    config: {
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
    flyLineMap: Record<any, true>;
    setConfig(options: Partial<Options>): void;
    getConfig(): StoreConfig;
}
export default Store;
