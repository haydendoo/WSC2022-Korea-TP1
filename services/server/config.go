package main

import (
	"encoding/json"
	"fmt"
	"os"
)

// Config mirrors the settings the Day 1 practice server needs. Unlike Day
// 2's root/stub services, the Day 1 spec never mentions AWS AppConfig, so
// this binary resolves configuration purely from flags/environment
// variables, with an optional local JSON file supplying defaults - handy
// for local testing (see docker/docker-compose.yaml), not a documented
// competition path.
type Config struct {
	Table  string `json:"Table"`
	Region string `json:"Region"`
	Port   int    `json:"Port"`
	// DynamoEndpoint overrides the DynamoDB endpoint URL. Only meant for
	// pointing at DynamoDB Local during local development - leave unset
	// against real AWS.
	DynamoEndpoint string `json:"DynamoEndpoint"`
}

const (
	defaultPort   = 80
	defaultTable  = "unicorn"
	defaultRegion = "ap-southeast-1"
)

func normalize(cfg *Config) *Config {
	if cfg.Port == 0 {
		cfg.Port = defaultPort
	}
	if cfg.Table == "" {
		cfg.Table = defaultTable
	}
	if cfg.Region == "" {
		cfg.Region = defaultRegion
	}
	return cfg
}

// LoadConfig reads a JSON config file from disk, if present. Missing
// files are not an error - the binary still runs from flags/env/defaults
// alone, matching how a real deployment would set --table/--region as
// flags rather than shipping a config file.
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading config file %q: %w", path, err)
	}
	cfg := &Config{}
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parsing config file %q: %w", path, err)
	}
	return cfg, nil
}
