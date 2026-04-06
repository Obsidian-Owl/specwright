// ISSUE 2: Unused exported function — never imported by any module

export function unusedHelper(input: string): string {
  return input.trim().toLowerCase();
}

export function activeHelper(input: string): string {
  return input.toUpperCase();
}
