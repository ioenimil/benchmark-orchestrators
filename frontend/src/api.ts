export interface Name {
  id: number;
  name: string;
  created_at: string;
}

const BASE = "/api";

export async function getNames(): Promise<Name[]> {
  const res = await fetch(`${BASE}/names`);
  if (!res.ok) throw new Error(`Failed to fetch names: ${res.status}`);
  return res.json();
}

export async function addName(name: string): Promise<Name> {
  const res = await fetch(`${BASE}/names`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(
      typeof err.detail === "string"
        ? err.detail
        : `Failed to add name: ${res.status}`
    );
  }
  return res.json();
}

export async function deleteName(id: number): Promise<void> {
  const res = await fetch(`${BASE}/names/${id}`, { method: "DELETE" });
  if (!res.ok) throw new Error(`Failed to delete name: ${res.status}`);
}
