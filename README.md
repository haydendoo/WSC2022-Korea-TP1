# Unicorn GameDay - WSC2022 TP53 Day 1 Practice Starter Kit

This repository recreates the **starting state** participants received for
WorldSkills 2022 Test Project 53, Day 1 ("IoT + AI + Web service") - see
[`WSC2022SE_TP53_Day1_actual_en.pdf`](./WSC2022SE_TP53_Day1_actual_en.pdf)
for the original specification.

It is a practice environment generator, not a solution. Running the
Terraform here reproduces what a competitor's AWS account looked like
before requests started - baseline IAM only - and nothing more.
Everything from "connect the IoT devices" onward is the actual Day 1
challenge and is intentionally left undone.

## What this repository answers - and what it doesn't

> "What did the participant receive when the competition started?"

It does **not** answer "how should the participant solve Day 1?" The
architecture diagram in the spec (IoT Core -> Lambda -> DynamoDB, served
by an EC2 web tier) is one possible design, not a prescription - keep
your own architecture decisions open.

## Repository layout

```
├── terraform/          baseline IAM only (see scope below)
├── services/
│   └── server/           practice-compatible "server-stub" binary (Go source + Dockerfile)
├── database/
│   └── table.json         DynamoDB CreateTable request for the "unicorn" table, per the spec
├── certs/                 shared practice IoT device identity (see below)
├── config/                example + local-dev config JSON for the server
├── scripts/
│   ├── gen-certs.sh          regenerates the shared IoT device cert/key (see below)
│   ├── build.sh                compile server for linux/amd64
│   ├── package.sh               assemble dist/ (see below) + optional Docker image
│   └── verify.sh                 smoke-test the built binary (--help, GET /)
├── docker/
│   └── docker-compose.yaml     local practice stack (NOT the competition architecture)
└── dist/                  generated: the package handed to participants
    (run `./scripts/package.sh` to (re)build it - binary, example
    config, table.json, certs/, and dist/README.md)
```

## Terraform scope

### Provisioned (the baseline participants start with)

| Resource | Spec basis |
|---|---|
| `TeamRole` (+ `TeamRoleDay1Policy`) | "Please attach TeamRole to your lambda function as the execution role" (Gentle reminder #4) |
| `EC2Role` + `ec2-prole` instance profile (+ `EC2RoleDay1Policy`) | "Please attach EC2Role as ec2-prole for your EC2 instance" (Gentle reminder #5) |

Both roles are documented, non-admin permission sets (Comprehend
detection, `dynamodb:*Item`/`Query` scoped to the `unicorn` table,
`s3:GetObject`/`ListBucket` scoped to a `unicorn-*` bucket pattern for
TeamRole; `dynamodb:GetItem`/`Query` plus SSM + CloudWatch Agent for
EC2Role) - not `AdministratorAccess`. Tune them via `variables.tf` or the
`*_extra_managed_policy_arns` variables.

No bastion, VPC, or network baseline is provisioned - unlike Day 2, the
spec never mentions a pre-existing instance for Day 1; participants
launch their own EC2 instance directly (t2.micro per the spec's cost
guidance) into their account's default VPC.

### NOT provisioned (the participant's Day 1 solution)

The IoT Core Thing/certificate/policy, the S3 bucket for
keys/certificates, the Lambda function, the Comprehend integration, the
DynamoDB table itself, and the EC2 instance running the web service.
Building these is the competition task - see the Tasks section of the
spec PDF.

## Deploying the baseline

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Requires AWS credentials with permission to create IAM roles/policies.
Review `variables.tf` first, especially `aws_region` (defaults to
`ap-southeast-1`).

## The server binary

`services/server` is a **from-scratch practice replacement** for the
proprietary "server-stub" Go binary described in the spec ("Web SeRver"
section: "The development team has built a binary file server-stub for
you to host the web service") - not the original binary, and not a
reverse-engineering of it. It exists so you have something real to point
your infrastructure at while practicing, matching the documented
interface:

- `--help`, `--table` (default `unicorn`), `--region`, `--port` (default `80`)
- `GET /` and `GET /healthz` return HTTP 200 (the health check)
- `GET /unicorn/{id}` queries the `unicorn` DynamoDB table by partition
  key `id` and returns every `{id, sentiment, message}` item found -
  this is what a "result searching request" (Gentle reminder #2) hits
- Configuration comes from flags/environment variables, optionally
  defaulted from a local JSON file (`--config`) - see
  `config/server.example.json`. Unlike Day 2, the Day 1 spec never
  mentions AppConfig, so there's no AppConfig dependency here.

Build and smoke-test:

```bash
./scripts/build.sh     # -> dist/server (linux/amd64)
./scripts/verify.sh     # --help + GET / checks
./scripts/package.sh     # tarball-equivalent dist/ + (if Docker is available) a local image
```

Try it locally, without touching AWS, via Docker Compose (DynamoDB
Local, table auto-created):

```bash
docker compose -f docker/docker-compose.yaml up --build
curl localhost:8080/
curl localhost:8080/unicorn/some-id   # 404 until you PutItem a record yourself
```

## The shared practice IoT device identity

Per the spec's Service Details / IoT core section, you need to generate
and upload three files to your S3 bucket, with these exact names:

1. `GameDayThing.cert.pem`
2. `GameDayThing.private.key`
3. `root-CA.crt`

In the real competition these are handed out from the GameDay dashboard
- every competitor registers the **same** device identity into their own
AWS IoT Core account, because the vendor's simulated IoT devices are one
shared fleet that gets pointed at whichever account's endpoint a given
competitor configures. This starter kit reproduces that: `certs/`
contains one self-signed CA (`root-CA.crt`) and one device
certificate/private key signed by it (`GameDayThing.cert.pem` /
`GameDayThing.private.key`), generated by `scripts/gen-certs.sh`. These
are intentionally **shared, non-sensitive practice artifacts** - not a
real secret - since the entire point is that every practice participant
and the companion `gameday-simulator` project's `wsc2022-korea-day1`
scenario use the identical key pair. Do not reuse this pattern for
anything that isn't a shared practice identity.

To wire this into your own AWS IoT Core account:

```bash
aws iot register-certificate-without-ca \
  --certificate-pem file://certs/GameDayThing.cert.pem \
  --status ACTIVE
aws iot create-thing --thing-name GameDayThing
aws iot attach-thing-principal --thing-name GameDayThing --principal <certificate-arn-from-above>
# then attach an IoT policy permitting iot:Connect / iot:Publish / iot:Subscribe / iot:Receive
# on topic "sdk/test/Python", and upload all three files under certs/ to your S3 bucket.
```

Regenerate the identity with `./scripts/gen-certs.sh` if needed - and if
you do, re-copy `certs/` into the companion gameday-simulator scenario's
embedded `dist/certs/` so the simulator's "IoT device" keeps using the
matching key.

## Participant workflow

```
Starter Terraform (this repo)
  ├── TeamRole (Lambda execution role)
  └── EC2Role / ec2-prole instance profile
        │
        ▼
  PARTICIPANT STARTS HERE
        │
        ▼
  Create S3 bucket -> upload certs/ -> register cert with AWS IoT Core
  -> create IoT Thing + policy -> create DynamoDB "unicorn" table
  -> build Lambda (Comprehend sentiment -> DynamoDB) -> wire IoT Rule -> Lambda
  -> launch EC2 (t2.micro, ec2-prole profile) -> deploy server binary
  -> report Bucket-Name / HTTP-URI / IoT-Core-EP to the GameDay Dashboard
```

Everything below the line is your Day 1 architecture to design - this
starter kit stops at the line on purpose.
