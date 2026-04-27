#!/usr/bin/env python3

import json
import struct
from pathlib import Path

import numpy as np
import trimesh


ROOT = Path(__file__).resolve().parents[1]
SRC_GLB = ROOT / "temp_models" / "佛像模型.glb"
FIXED_GLB = ROOT / "temp_models" / "佛像模型_fixed_normals_pbr.glb"


def build_fixed_glb() -> None:
    scene = trimesh.load(SRC_GLB, force="scene", skip_materials=False)
    new_scene = trimesh.Scene()

    for name, geom in scene.geometry.items():
        vertices = np.asarray(geom.vertices, dtype=np.float64)
        faces = np.asarray(geom.faces, dtype=np.int64)

        normals = np.zeros_like(vertices)
        triangles = vertices[faces]
        face_normals = np.cross(
            triangles[:, 1] - triangles[:, 0],
            triangles[:, 2] - triangles[:, 0],
        )
        for i in range(3):
            np.add.at(normals, faces[:, i], face_normals)

        lengths = np.linalg.norm(normals, axis=1)
        valid = lengths > 1e-12
        normals[valid] /= lengths[valid][:, None]
        normals[~valid] = np.array([0.0, 1.0, 0.0])

        new_geom = trimesh.Trimesh(
            vertices=vertices,
            faces=faces,
            process=False,
            validate=False,
        )
        new_geom.visual = geom.visual.copy()
        # The source GLB only carries vertex colors. They contain dark speckled
        # scan/detail data that looks noisy once we render with generated
        # normals. Normalize them to plain white so the material controls the
        # visible color instead of the baked vertex paint.
        new_geom.visual.vertex_colors = np.full(
            (len(vertices), 4),
            255,
            dtype=np.uint8,
        )
        new_geom._cache["vertex_normals"] = normals.astype(np.float64)
        new_scene.add_geometry(new_geom, node_name=name, geom_name=name)

    for node_name in scene.graph.nodes_geometry:
        transform, geom_name = scene.graph[node_name]
        if geom_name in new_scene.geometry:
            new_scene.graph.update(
                frame_to=node_name,
                frame_from=new_scene.graph.base_frame,
                matrix=transform,
                geometry=geom_name,
            )

    raw_glb = trimesh.exchange.gltf.export_glb(new_scene, include_normals=True)
    FIXED_GLB.write_bytes(raw_glb)
    inject_pbr_material(FIXED_GLB)


def inject_pbr_material(path: Path) -> None:
    with path.open("rb") as f:
        magic, version, _ = struct.unpack("<III", f.read(12))
        json_len, json_type = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(json_len).decode("utf-8").rstrip(" \t\r\n\x00"))
        bin_len, bin_type = struct.unpack("<II", f.read(8))
        bin_bytes = f.read(bin_len)

    gltf["materials"] = [
        {
            "name": "BuddhaVertexColorPBR",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.88, 0.80, 0.67, 1.0],
                "metallicFactor": 0.02,
                "roughnessFactor": 0.96,
            },
            "doubleSided": False,
        }
    ]
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive["material"] = 0

    json_bytes = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - (len(json_bytes) % 4)) % 4)
    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)

    with path.open("wb") as f:
        f.write(struct.pack("<III", magic, version, total_len))
        f.write(struct.pack("<II", len(json_bytes), json_type))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_bytes), bin_type))
        f.write(bin_bytes)


if __name__ == "__main__":
    build_fixed_glb()
    print(FIXED_GLB)
