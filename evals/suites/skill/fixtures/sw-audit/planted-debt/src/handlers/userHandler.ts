import { activeHelper } from "../utils";

export function handleUserRequest(name: string) {
  return activeHelper(name);
}
