import { OrbitControls } from "three/examples/jsm/controls/OrbitControls";
import { Options, SetData } from '../lib/interface';
import OperateView from '../lib/operateView';
import { AmbientLight, Camera, DirectionalLight, Group, Light, Mesh, Object3D, OrthographicCamera, PerspectiveCamera, PointLight, Renderer, Scene, WebGLRenderer } from "three";
import Store from '../lib/store/store';
import EventStore from '../lib/store/eventStore';
import CustomOrbitControls from '../lib/utils/controls';
/**
 * ChartScene class is used to create a 3D scene using Three.js.
 * It provides methods to initialize the scene, create camera, light, helper, figures, and renderer.
 * It also provides methods to control the animation and transformation of the scene.
 */
export default class ChartScene {
    options: Options;
    initOptions: Pick<Options, "helper" | "autoRotate" | "rotateSpeed" | "mode" | "controls">;
    style: {
        width: number;
        height: number;
    };
    light: Light;
    earthHovered: boolean;
    camera: Camera;
    notLockFps: Function;
    mainContainer: Object3D;
    scene: Scene;
    renderer: Renderer;
    controls: CustomOrbitControls | OrbitControls;
    _store: Store;
    _eventStore: EventStore;
    _OperateView: OperateView;
    /**
     * Constructor for the ChartScene class.
     * @param {Partial<Options>} params - The initial options for the scene.
     */
    constructor(params: Partial<Options>);
    /**
     * Method to register an event.
     * @param {string} eventName - The name of the event.
     * @param {(event: Event, mesh: Object3D | Group | Mesh | undefined) => void} cb - The callback function to be executed when the event is triggered.
     */
    on(eventName: string, cb: (event: Event, mesh: Object3D | Group | Mesh | undefined) => void): void;
    /**
     * Method to clear Three.js objects.
     * @param {any} obj - The Three.js object to be cleared.
     */
    clearThree(obj: any): void;
    /**
     * Method to destroy the scene.
     */
    destroy(): void;
    /**
     * Method to initialize the scene.
     */
    init(): void;
    /**
     * Method to create an orthographic camera.
     * @returns {OrthographicCamera} The created orthographic camera.
     */
    createOrthographicCamera(): OrthographicCamera;
    /**
     * Method to create a scene.
     * @returns {Scene} The created scene.
     */
    createScene(): Scene;
    /**
     * Method to create a perspective camera.
     * @returns {PerspectiveCamera} The created perspective camera.
     */
    createCamera(): PerspectiveCamera;
    /**
     * Method to create a light.
     * @param {string} lightType - The type of the light.
     */
    createLight(lightType: string): DirectionalLight | AmbientLight | PointLight;
    /**
     * Method to create a helper.
     */
    createHelper(): void;
    /**
     * Method to add 3D figures to the scene.
     */
    addFigures3d(): void;
    /**
     * Method to add 2D figures to the scene.
     */
    addFigures2d(): void;
    /**
     * Method to create a cube.
     * @returns {Group} The created cube.
     */
    createCube(): Group;
    addWall(): Group;
    /**
     * Method to create a renderer.
     * @returns {WebGLRenderer} The created renderer.
     */
    createRender(): WebGLRenderer;
    /**
     * Method to limit the frames per second.
     * @param {boolean | undefined} isLimit - Whether to limit the frames per second.
     * @returns {Function} The function to check whether to render the next frame.
     */
    lockFps(isLimit?: boolean): Function;
    /**
     * Method to check whether to rotate the scene.
     * @returns {boolean} Whether to rotate the scene.
     */
    shouldRotate(): boolean | undefined;
    /**
     * Method to create a group for country names.
     */
    createCountryNamesText(): null | undefined;
    /**
     * Method to animate the scene.
     */
    animate(): void;
    /**
     * Method to set data to the scene.
     * @param {K} type - The type of the data.
     * @param {SetData[K]} data - The data to be set.
     */
    setData: <K extends keyof SetData>(type: K, data: SetData[K]) => Promise<void>;
    /**
     * Method to add data to the scene.
     * @param {K} type - The type of the data.
     * @param {SetData[K]} data - The data to be added.
     */
    addData: <K extends keyof SetData>(type: K, data: SetData[K]) => Promise<void>;
    /**
     * Method to remove data from the scene.
     * @param {string} type - The type of the data.
     * @param {string[] | "removeAll"} ids - The ids of the data to be removed.
     */
    remove(type: string, ids?: string[] | "removeAll"): void;
}
