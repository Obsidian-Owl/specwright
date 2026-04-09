import { describe, expect, it } from "vitest";
import { add } from "./math";

describe("add", () => {
  it("adds two positive numbers", () => {
    expect(add(2, 3)).toBe(5);
  });

  it("handles negative numbers", () => {
    expect(add(-2, 3)).toBe(1);
  });

  it("handles zeros", () => {
    expect(add(0, 0)).toBe(0);
  });
});
