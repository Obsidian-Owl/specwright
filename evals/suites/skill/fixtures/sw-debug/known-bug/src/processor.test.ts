import { describe, it, expect } from "vitest";
import { processAll } from "./processor";

describe("processAll", () => {
  it("processes all elements", () => {
    expect(processAll([1, 2, 3, 4, 5])).toEqual([2, 4, 6, 8, 10]);
  });

  it("handles empty array", () => {
    expect(processAll([])).toEqual([]);
  });

  it("handles single element", () => {
    expect(processAll([7])).toEqual([14]);
  });
});
