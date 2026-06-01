import React, { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { addName, deleteName, getNames } from "../api";

export default function NamesPage() {
  const queryClient = useQueryClient();
  const [input, setInput] = useState("");

  const {
    data: names,
    isLoading,
    error,
  } = useQuery({ queryKey: ["names"], queryFn: getNames });

  const mutation = useMutation({
    mutationFn: (name: string) => addName(name),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["names"] });
      setInput("");
    },
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = input.trim();
    if (!trimmed) return;
    mutation.mutate(trimmed);
  }

  function handleDelete(id: number) {
    deleteName(id).then(() =>
      queryClient.invalidateQueries({ queryKey: ["names"] })
    );
  }

  return (
    <main
      style={{
        maxWidth: 600,
        margin: "0 auto",
        padding: "2rem",
        fontFamily: "system-ui, sans-serif",
      }}
    >
      <h1 style={{ marginBottom: "1.5rem" }}>Poly-Orchestrator Names</h1>

      <form onSubmit={handleSubmit} style={{ marginBottom: "2rem" }}>
        <label
          htmlFor="name-input"
          style={{ display: "block", marginBottom: 6, fontWeight: 600 }}
        >
          Add a name
        </label>
        <div style={{ display: "flex", gap: 8 }}>
          <input
            id="name-input"
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Enter a name"
            style={{
              flex: 1,
              padding: "0.5rem 0.75rem",
              fontSize: "1rem",
              borderRadius: 4,
              border: "1px solid #ccc",
            }}
          />
          <button
            type="submit"
            disabled={mutation.isPending}
            style={{
              padding: "0.5rem 1.25rem",
              fontSize: "1rem",
              cursor: mutation.isPending ? "not-allowed" : "pointer",
              borderRadius: 4,
              background: mutation.isPending ? "#aaa" : "#0070f3",
              color: "#fff",
              border: "none",
            }}
          >
            {mutation.isPending ? "Adding…" : "Add"}
          </button>
        </div>
        {mutation.isError && (
          <p style={{ color: "#cc0000", marginTop: 6, fontSize: "0.9rem" }}>
            Error: {(mutation.error as Error).message}
          </p>
        )}
      </form>

      {isLoading && <p style={{ color: "#555" }}>Loading names…</p>}
      {error && (
        <p style={{ color: "#cc0000" }}>
          Error: {(error as Error).message}
        </p>
      )}
      {names && names.length === 0 && (
        <p style={{ color: "#777" }}>No names yet. Add one above!</p>
      )}
      {names && names.length > 0 && (
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {names.map((n) => (
            <li
              key={n.id}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                padding: "0.6rem 0",
                borderBottom: "1px solid #eee",
              }}
            >
              <span>{n.name}</span>
              <button
                onClick={() => handleDelete(n.id)}
                aria-label={`Delete ${n.name}`}
                style={{
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  color: "#cc0000",
                  fontSize: "1rem",
                  lineHeight: 1,
                  padding: "0 4px",
                }}
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
