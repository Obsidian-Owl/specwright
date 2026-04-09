import { describe, expect, it } from "vitest";
import { renderGreeting } from "../src/greeting";

describe("renderGreeting", () => {
  it("renders the final greeting from the normalized name", () => {
    expect(renderGreeting("  aLIce  ")).toBe("Hello, Alice!");
  });
});
