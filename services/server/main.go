// Command server is a practice-compatible stand-in for the "server-stub"
// web service binary described in the WorldSkills WSC2022 TP53 Day 1
// test project ("Web SeRver" section: "The development team has built a
// binary file server-stub for you to host the web service, the binary
// file will serve the data which you stored in the DynamoDB to
// customer.").
//
// It is NOT the original competition binary: it is a from-scratch Go
// implementation that reproduces the documented interface (flags, config
// source, health check, port behaviour, DynamoDB dependency) closely
// enough to exercise the infrastructure participants build (IoT Core,
// S3, Lambda, Comprehend, DynamoDB, EC2). Business logic and exact
// response bodies are illustrative, not a reverse-engineering of the
// proprietary original.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
)

const usage = `server - Unicorn Service Day 1 "server-stub" practice web service

USAGE:
  server [flags]

FLAGS:
  --table string   DynamoDB table name (default "unicorn", per the spec -
                    "The table name should be unicorn" - and cannot be changed)
  --region string   AWS region the DynamoDB table lives in
  --dynamo-endpoint string
                    Override DynamoDB endpoint URL (local-development
                    convenience for DynamoDB Local, see
                    docker/docker-compose.yaml; leave unset for real AWS)
  --config string   Local JSON config file, used only to supply defaults for
                    the flags above when they are not set (see
                    config/server.example.json)
  --port int        TCP port to listen on, overrides the resolved config
                    (default 80)
  --help            Show this help message and exit

ENVIRONMENT VARIABLES (equivalent to the flags above):
  TABLE, AWS_REGION, DYNAMO_ENDPOINT, CONFIG_FILE, PORT

CONFIGURATION:
  Per the Day 1 spec there is no AppConfig dependency (unlike Day 2) - this
  binary reads its settings from flags/environment variables, falling back
  to a local JSON file (--config, default "config.json") shaped like
  config/server.example.json:
  {
    "Table": "unicorn",
    "Region": "ap-southeast-1",
    "Port": 80
  }

DEPENDENCIES:
  - DynamoDB table named "unicorn" with partition key "id" and sort key
    "sentiment" (see database/table.json), populated by the Lambda +
    Comprehend pipeline you build for Phase II.

ENDPOINTS:
  GET  /               health check, returns HTTP 200 when the process is up
  GET  /healthz          alias for /
  GET  /unicorn/{id}     Query the unicorn table by partition key "id",
                          returns a JSON array of {id, sentiment, message}.
                          404 when no items exist for that id yet.
`

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	tableFlag := flag.String("table", envOrDefault("TABLE", ""), "DynamoDB table name")
	regionFlag := flag.String("region", envOrDefault("AWS_REGION", ""), "AWS region")
	endpointFlag := flag.String("dynamo-endpoint", envOrDefault("DYNAMO_ENDPOINT", ""), "override DynamoDB endpoint URL (local testing only)")
	configPath := flag.String("config", envOrDefault("CONFIG_FILE", "config.json"), "local JSON config file (supplies defaults for unset flags)")
	portOverride := flag.Int("port", 0, "TCP port to listen on (overrides resolved config)")
	help := flag.Bool("help", false, "show help")
	flag.Usage = func() { fmt.Fprint(os.Stderr, usage) }
	flag.Parse()

	if *help {
		fmt.Print(usage)
		return
	}

	cfg, err := LoadConfig(*configPath)
	if err != nil {
		log.Printf("server: %v, using flag/env values and defaults", err)
		cfg = &Config{}
	}
	normalize(cfg)

	if *tableFlag != "" {
		cfg.Table = *tableFlag
	}
	if *regionFlag != "" {
		cfg.Region = *regionFlag
	}
	if *endpointFlag != "" {
		cfg.DynamoEndpoint = *endpointFlag
	}
	if *portOverride != 0 {
		cfg.Port = *portOverride
	} else if p := os.Getenv("PORT"); p != "" {
		fmt.Sscanf(p, "%d", &cfg.Port)
	}

	db, err := NewDB(context.Background(), cfg)
	if err != nil {
		log.Fatalf("dynamodb client error: %v", err)
	}

	server := NewServer(cfg, db)

	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Printf("server: listening on %s (table=%s region=%s)", addr, cfg.Table, cfg.Region)

	if err := http.ListenAndServe(addr, server.Routes()); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
