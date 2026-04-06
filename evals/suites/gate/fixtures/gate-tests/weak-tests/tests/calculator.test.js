// DELIBERATELY WEAK TESTS — for gate-tests evaluation

const { add, multiply } = require("../src/calculator");

// WEAKNESS 1: Truthiness-only assertion — does not verify the actual value
test("add returns a result", () => {
  expect(add(1, 2)).toBeDefined();
});

// WEAKNESS 2: No test for division by zero (AC-02 completely untested)

// WEAKNESS 3: Over-mocking — mocks the module under test
jest.mock("../src/calculator", () => ({
  multiply: jest.fn(() => 6),
}));

test("multiply returns expected value", () => {
  const { multiply: mockMultiply } = require("../src/calculator");
  expect(mockMultiply(2, 3)).toBe(6);
});
