import ChartScene from '../../lib/chartScene';
import { Color, Group, Mesh, Object3D } from "three";
declare class EventStore {
    eventMap: Record<string, (event: Event, mesh: Object3D | Group | Mesh | undefined) => void>;
    buildInEventMap: Record<string, (event: Event, mesh: Object3D | Group | Mesh | undefined) => void>;
    _chartScene: ChartScene;
    currentMesh: Mesh | null;
    currentColor: Color;
    areaColorNeedChange: boolean | undefined;
    constructor(chartScene: ChartScene);
    registerEventMap(eventName: string, cb: (event: Event, mesh: Object3D | Group | Mesh | undefined) => void): void;
    registerBuildInEventMap(eventName: string, cb: () => void): void;
    notification(event: MouseEvent): void;
    getMousePosition(event: MouseEvent): {
        clientX: number;
        clientY: number;
    };
    handleRaycaster(event: MouseEvent): Mesh<import("three").BufferGeometry<import("three").NormalBufferAttributes>, import("three").Material | import("three").Material[]> | undefined;
}
export default EventStore;
