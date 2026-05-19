FROM ghcr.io/anomalyco/opencode:latest

WORKDIR /workspace

ENV OPENCODE_HOST=0.0.0.0
ENV OPENCODE_PORT=4096

EXPOSE 4096

ENTRYPOINT ["opencode"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]
