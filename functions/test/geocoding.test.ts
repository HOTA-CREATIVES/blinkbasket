import { reverseGeocode, searchAddress } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

const NOMINATIM_REVERSE = {
  display_name: "Main Road, Bhimavaram, Andhra Pradesh, India",
  address: {
    road: "Main Road",
    county: "Bhimavaram Mandal",
    state_district: "West Godavari",
    postcode: "534201",
  },
};

let fetchMock: jest.Mock;

function respond(body: unknown, ok = true, status = 200) {
  fetchMock.mockResolvedValueOnce({ ok, status, json: async () => body });
}

// clearFirestore() talks to the emulator with the global fetch, so the real one
// is put back for that call and only then replaced with the geocoder mock.
const realFetch = global.fetch;

beforeEach(async () => {
  (global as any).fetch = realFetch;
  await clearFirestore();
  fetchMock = jest.fn();
  (global as any).fetch = fetchMock;
});

afterAll(() => {
  (global as any).fetch = realFetch;
});

describe("reverseGeocode", () => {
  const req = (data: unknown, uid: string | null = "cust1") => callableRequest(data, uid);

  it("rejects an unauthenticated caller", async () => {
    await expect(reverseGeocode.run(req({ lat: 16.5, lng: 81.5 }, null))).rejects.toThrow(/Sign in/);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([
    [{ lat: "16.5", lng: 81.5 }],
    [{ lat: 16.5 }],
    [{ lat: 95, lng: 81.5 }],
    [{ lat: 16.5, lng: 200 }],
    [{ lat: NaN, lng: 81.5 }],
    [undefined],
  ])("rejects invalid coordinates %p without calling the geocoder", async (data) => {
    await expect(reverseGeocode.run(req(data))).rejects.toThrow(/valid location/);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("returns address details, identifying the app to the geocoder", async () => {
    respond(NOMINATIM_REVERSE);

    const result = await reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }));

    expect(result).toEqual({
      road: "Main Road",
      mandal: "Bhimavaram Mandal",
      district: "West Godavari",
      pincode: "534201",
      label: "Main Road, Bhimavaram, Andhra Pradesh, India",
    });
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toContain("/reverse?");
    expect(String(url)).toContain("lat=16.5449");
    expect(init.headers["User-Agent"]).toMatch(/^JCMart\/1\.0 \(.+\)$/);
  });

  it("serves a nearby repeat from the cache instead of calling the geocoder again", async () => {
    respond(NOMINATIM_REVERSE);

    const first = await reverseGeocode.run(req({ lat: 16.54491, lng: 81.52121 }));
    // ~1 m away: same cache cell.
    const second = await reverseGeocode.run(req({ lat: 16.54493, lng: 81.52124 }, "cust2"));

    expect(second).toEqual(first);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("reports an unavailable geocoder as such, not as a bad request, and caches nothing", async () => {
    respond({}, false, 503);

    await expect(reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }))).rejects.toMatchObject({
      code: "unavailable",
    });
    expect((await db.collection("geocodeCache").get()).size).toBe(0);
  });

  it("treats a network failure the same way", async () => {
    fetchMock.mockRejectedValueOnce(new Error("ECONNRESET"));
    await expect(reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }))).rejects.toMatchObject({
      code: "unavailable",
    });
  });

  it("returns empty strings, not undefined, when the geocoder has no address parts", async () => {
    respond({ address: {} });
    const result = await reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }));
    expect(result).toEqual({ road: "", mandal: "", district: "", pincode: "", label: "" });
  });

  it("rate limits a single user", async () => {
    respond(NOMINATIM_REVERSE);
    // Same cell, so only the first call reaches the geocoder; the limiter still counts each call.
    for (let i = 0; i < 20; i++) {
      await reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }));
    }
    await expect(
      reverseGeocode.run(req({ lat: 16.5449, lng: 81.5212 }))
    ).rejects.toThrow(/Too many requests/);
  });
});

describe("searchAddress", () => {
  const req = (data: unknown, uid: string | null = "cust1") => callableRequest(data, uid);
  const hit = (name: string, lat: number, lon: number) => ({ display_name: name, lat: String(lat), lon: String(lon) });

  it("rejects too-short and too-long queries without calling the geocoder", async () => {
    await expect(searchAddress.run(req({ query: "ab" }))).rejects.toThrow(/at least 3/);
    await expect(searchAddress.run(req({ query: "x".repeat(101) }))).rejects.toThrow(/at least 3/);
    await expect(searchAddress.run(req({}))).rejects.toThrow(/at least 3/);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(searchAddress.run(req({ query: "temple" }, null))).rejects.toThrow(/Sign in/);
  });

  it("searches inside the delivery area and flags which zone each result is in", async () => {
    respond([
      hit("Sri Rama Temple, Bhimavaram", 16.546, 81.5225),
      hit("Far Away Temple, Elsewhere", 17.5, 82.5),
    ]);

    const { places } = await searchAddress.run(req({ query: "  temple  " }));

    const [url] = fetchMock.mock.calls[0];
    const params = new URL(String(url)).searchParams;
    expect(params.get("q")).toBe("temple");
    expect(params.get("bounded")).toBe("1");
    expect(params.get("countrycodes")).toBe("in");
    expect(params.get("viewbox")).toMatch(/^[\d.,-]+$/);

    expect(places).toEqual([
      { label: "Sri Rama Temple, Bhimavaram", lat: 16.546, lng: 81.5225, zone: "Bhimavaram" },
      { label: "Far Away Temple, Elsewhere", lat: 17.5, lng: 82.5, zone: null },
    ]);
  });

  it("uses the admin-configured zones for the bounding box and the zone flag", async () => {
    await db.collection("config").doc("app").set({
      serviceZones: [{ name: "Palakollu", lat: 16.52, lng: 81.73, radiusKm: 4 }],
    });
    respond([hit("Market, Palakollu", 16.5205, 81.7305)]);

    const { places } = await searchAddress.run(req({ query: "market" }));

    const viewbox = new URL(String(fetchMock.mock.calls[0][0])).searchParams.get("viewbox")!;
    const [west, north, east, south] = viewbox.split(",").map(Number);
    expect(west).toBeLessThan(81.73);
    expect(east).toBeGreaterThan(81.73);
    expect(south).toBeLessThan(16.52);
    expect(north).toBeGreaterThan(16.52);
    expect(places[0].zone).toBe("Palakollu");
  });

  it("drops malformed results and caps the list", async () => {
    respond([
      { display_name: "", lat: "16.5", lon: "81.5" },
      { display_name: "No coords" },
      { display_name: "Bad lat", lat: "999", lon: "81.5" },
      ...Array.from({ length: 10 }, (_, i) => hit(`Place ${i}`, 16.546, 81.5225)),
    ]);

    const { places } = await searchAddress.run(req({ query: "place" }));

    expect(places).toHaveLength(6);
    expect(places.every((p: any) => p.label.startsWith("Place"))).toBe(true);
  });

  it("caches repeated searches and doesn't call the geocoder twice", async () => {
    respond([hit("Sri Rama Temple, Bhimavaram", 16.546, 81.5225)]);

    const first = await searchAddress.run(req({ query: "Temple" }));
    const second = await searchAddress.run(req({ query: "temple" }, "cust2"));

    expect(second).toEqual(first);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("reports an unavailable geocoder without caching the failure", async () => {
    respond({}, false, 429);
    await expect(searchAddress.run(req({ query: "temple" }))).rejects.toMatchObject({
      code: "unavailable",
    });
    expect((await db.collection("geocodeCache").get()).size).toBe(0);
  });
});
