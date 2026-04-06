// Circular dependency: moduleB imports moduleA
import { getUser } from "./moduleA";

export function formatUser(user: { id: string; name: string }) {
  return `User ${user.name} (${user.id})`;
}

export function getUserDisplay(id: string) {
  const user = getUser(id);
  return `Display: ${user}`;
}
