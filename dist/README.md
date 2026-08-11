# Unicorn Service - Day 1 Distribution Package

This is what you were given at the start of the competition: the
`server` binary, its example configuration, the DynamoDB table
definition, and the three IoT certificate/key files. See the Day 1 Test
Project PDF for the full task description.

## Contents

- `server` - x86-64 Linux binary. Run with `--help` for usage. Reads
  `--table` / `--region` / `--port` from flags or environment variables,
  optionally defaulted from a local JSON file (`--config`) shaped like
  `config/server.example.json`.
- `config/server.example.json` - the configuration shape the service
  expects.
- `database/table.json` - the DynamoDB `CreateTable` request for the
  `unicorn` table (partition key `id`, sort key `sentiment`). Apply it
  yourself, e.g.:

  ```
  aws dynamodb create-table --cli-input-json file://database/table.json
  ```

- `certs/root-CA.crt`, `certs/GameDayThing.cert.pem`,
  `certs/GameDayThing.private.key` - upload these three files, with
  these exact names, to the S3 bucket you create (Re-platform schedule
  Phase I). Then register `GameDayThing.cert.pem` with AWS IoT Core
  (`aws iot register-certificate-without-ca --certificate-pem
  file://certs/GameDayThing.cert.pem --status ACTIVE` is the simplest
  path), create an IoT Thing, attach the certificate, and attach an IoT
  policy that allows `iot:Connect`, `iot:Publish`, `iot:Subscribe`, and
  `iot:Receive`. The practice IoT devices publish to topic
  `sdk/test/Python` using this exact certificate/key pair, shared across
  every participant.
