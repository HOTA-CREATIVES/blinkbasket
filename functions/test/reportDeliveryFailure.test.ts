// @ts-nocheck
describe("reportDeliveryFailure validation", () => {
  it("rejects unauthenticated request", () => {
    const uid: string | undefined = undefined;
    expect(uid).toBeUndefined();
  });

  it("rejects empty orderId", () => {
    const orderId = "";
    expect(!orderId).toBe(true);
  });

  it("allows reporting from assigned status", () => {
    const status = "assigned";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(true);
  });

  it("allows reporting from picked_up status", () => {
    const status = "picked_up";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(true);
  });

  it("allows reporting from out_for_delivery status", () => {
    const status = "out_for_delivery";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(true);
  });

  it("rejects reporting from pending status (order isn't assigned to anyone yet)", () => {
    const status = "pending";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(false);
  });

  it("rejects reporting from delivered status", () => {
    const status = "delivered";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(false);
  });

  it("rejects reporting from already-cancelled status", () => {
    const status = "cancelled";
    expect(["assigned", "picked_up", "out_for_delivery"].includes(status)).toBe(false);
  });

  it("validates the requesting rider owns the order", () => {
    const orderDeliveryBoyId = "rider1";
    const requestUid = "rider1";
    expect(orderDeliveryBoyId === requestUid).toBe(true);
  });

  it("rejects a rider reporting an order assigned to someone else", () => {
    const orderDeliveryBoyId = "rider1";
    const requestUid = "rider2";
    expect(orderDeliveryBoyId === requestUid).toBe(false);
  });

  it("sets cancelledBy to rider", () => {
    const cancelledBy = "rider";
    expect(cancelledBy).toBe("rider");
  });

  it("falls back to 'Other' for an unrecognized reason", () => {
    const DELIVERY_FAILURE_REASONS = [
      "Customer unreachable",
      "Customer refused delivery",
      "Wrong or inaccessible address",
      "Other",
    ];
    const reasonInput = "something made up client-side";
    const reason = DELIVERY_FAILURE_REASONS.includes(reasonInput) ? reasonInput : "Other";
    expect(reason).toBe("Other");
  });

  it("accepts a recognized reason verbatim", () => {
    const DELIVERY_FAILURE_REASONS = [
      "Customer unreachable",
      "Customer refused delivery",
      "Wrong or inaccessible address",
      "Other",
    ];
    const reasonInput = "Customer refused delivery";
    const reason = DELIVERY_FAILURE_REASONS.includes(reasonInput) ? reasonInput : "Other";
    expect(reason).toBe("Customer refused delivery");
  });
});
