import { describe, expect, it } from "vitest";
import { normalizeName } from "../src/name";

describe("normalizeName", () => {
  it("trims whitespace and title-cases the input", () => {
    expect(normalizeName("  aLIce  ")).toBe("Alice");
  });
});
