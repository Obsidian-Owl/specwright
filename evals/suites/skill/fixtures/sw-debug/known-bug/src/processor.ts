/**
 * Processes an array of numbers by doubling each element.
 * Returns a new array with all elements doubled.
 */
export function processAll(numbers: number[]): number[] {
  const result: number[] = [];
  for (let i = 0; i < numbers.length - 1; i++) {
    result.push(numbers[i] * 2);
  }
  return result;
}
