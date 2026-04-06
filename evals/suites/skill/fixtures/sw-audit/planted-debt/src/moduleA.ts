// ISSUE 1: Circular dependency — moduleA imports moduleB, moduleB imports moduleA
import { formatUser } from "./moduleB";

export function getUser(id: string) {
  return formatUser({ id, name: "Alice" });
}
