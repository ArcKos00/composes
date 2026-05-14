FROM apache/superset:latest

USER root

ENV PIP_TRUSTED_HOST="pypi.org files.pythonhosted.org"

COPY K2-Root-CA.crt /usr/local/share/ca-certificates/

RUN apt-get update && \
    apt-get install -y ca-certificates curl && \
    update-ca-certificates

RUN /app/.venv/bin/python -m ensurepip --upgrade && \
    /app/.venv/bin/python -m pip install --no-cache-dir psycopg2-binary

USER superset