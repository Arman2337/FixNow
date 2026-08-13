import type { LoginState } from "./actions";

export function validateLoginInput(email: string, password: string): LoginState {
  const errors: { email?: string; password?: string } = {};
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    errors.email = "Enter a valid work email.";
  }
  if (password.length < 12 || password.length > 128) {
    errors.password = "Password must be 12 to 128 characters.";
  }
  return Object.keys(errors).length ? { errors } : {};
}
