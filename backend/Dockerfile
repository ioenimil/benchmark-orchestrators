# syntax=docker/dockerfile:1

FROM python:3.12-slim

# Bring in uv — tiny single binary from the official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Pre-compile .pyc files at install time for faster container startup.
# UV_LINK_MODE=copy: Docker layers live on separate filesystems so
# hardlinks (the default) don't work across layers.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PATH="/app/.venv/bin:$PATH"

# Install dependencies first — this layer is only rebuilt when the
# lockfile or project metadata changes, not when app source changes.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# Copy application source after deps so the fat dep layer stays cached.
COPY app/ ./app/

RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
