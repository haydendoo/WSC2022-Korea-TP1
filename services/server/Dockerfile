# Practice-compatible "server" (server-stub) service image.
# Multi-stage build: compile a linux/amd64 binary, then ship it in a
# minimal base image. Configuration comes from flags/environment
# variables, with an optional JSON file mounted at /app/config.json for
# local testing (see config/server.example.json and
# docker/docker-compose.yaml).

FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/server .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=build /out/server ./server

EXPOSE 80
ENTRYPOINT ["./server"]
CMD ["--config", "/app/config.json"]
