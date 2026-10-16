import { requireOptionalNativeModule } from 'expo-modules-core';
import type { ScannerAPI } from './types.ts';

const module = requireOptionalNativeModule<ScannerAPI>('PocketScanner');
export const scanner: ScannerAPI = new Proxy({} as ScannerAPI, {
  get(_target, property: keyof ScannerAPI) {
    return (...args: unknown[]) => {
      if (!module) return Promise.reject(new Error('This app needs its signed iPhone build. The scanner module is unavailable in Expo Go.'));
      const method = module[property] as (...values: unknown[]) => Promise<unknown>;
      return method.apply(module, args);
    };
  },
});
