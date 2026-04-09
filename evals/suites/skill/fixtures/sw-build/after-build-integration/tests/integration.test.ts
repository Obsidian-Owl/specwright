import { describe, expect, it } from "vitest";
import { renderGreeting } from "../src/greeting";

describe("integration", () => {
  it("produces the final greeting only after both tasks are complete", () => {
    expect(renderGreeting("  aLIce  ")).toBe("Hello, Alice!");
  });
});
