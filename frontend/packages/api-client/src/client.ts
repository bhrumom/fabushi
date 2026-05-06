import { API_BASE_URL } from "./endpoints";

export class FabushiApiClient {
  constructor(private readonly baseUrl = API_BASE_URL) {}

  async get<T>(path: string, init?: RequestInit): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        Accept: "application/json",
        ...(init?.headers ?? {}),
      },
      cache: "no-store",
    });

    if (!response.ok) {
      throw new Error(`Request failed with ${response.status}`);
    }

    return (await response.json()) as T;
  }
}

export const fabushiApiClient = new FabushiApiClient();
