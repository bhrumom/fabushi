"use client";

import { useLayoutEffect } from "react";

type JuanSlicePatchState = {
  count: number;
  originalSlice: typeof Array.prototype.slice;
  patchedSlice: typeof Array.prototype.slice;
};

const PATCH_KEY = "__fabushiFaliuJuanSlicePatch" as const;

type PatchedArrayConstructor = ArrayConstructor & {
  [PATCH_KEY]?: JuanSlicePatchState;
};

function isSequentialJuanArray(value: unknown[]): value is string[] {
  if (value.length <= 12) {
    return false;
  }

  return value.every((item, index) => typeof item === "string" && item === String(index + 1));
}

export function FaliuFullJuanEnhancer() {
  useLayoutEffect(() => {
    const arrayConstructor = Array as PatchedArrayConstructor;
    const existingPatch = arrayConstructor[PATCH_KEY];

    if (existingPatch) {
      existingPatch.count += 1;

      return () => {
        const currentPatch = arrayConstructor[PATCH_KEY];

        if (!currentPatch) {
          return;
        }

        currentPatch.count -= 1;

        if (currentPatch.count <= 0) {
          if (Array.prototype.slice === currentPatch.patchedSlice) {
            Array.prototype.slice = currentPatch.originalSlice;
          }

          delete arrayConstructor[PATCH_KEY];
        }
      };
    }

    const originalSlice = Array.prototype.slice;
    const patchedSlice = function patchedSlice(this: unknown[], start?: number, end?: number) {
      if (start === 0 && end === 12 && Array.isArray(this) && isSequentialJuanArray(this)) {
        return originalSlice.call(this);
      }

      return originalSlice.call(this, start, end);
    } as typeof Array.prototype.slice;

    arrayConstructor[PATCH_KEY] = {
      count: 1,
      originalSlice,
      patchedSlice,
    };
    Array.prototype.slice = patchedSlice;

    return () => {
      const currentPatch = arrayConstructor[PATCH_KEY];

      if (!currentPatch) {
        return;
      }

      currentPatch.count -= 1;

      if (currentPatch.count <= 0) {
        if (Array.prototype.slice === currentPatch.patchedSlice) {
          Array.prototype.slice = currentPatch.originalSlice;
        }

        delete arrayConstructor[PATCH_KEY];
      }
    };
  }, []);

  return null;
}
