package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// UnicornRecord is one item in the "unicorn" table: id (partition key),
// sentiment (sort key, the Comprehend result), and message (the original
// text received from the IoT devices) - the exact shape documented in
// the spec's Database section.
type UnicornRecord struct {
	ID        string `json:"id"`
	Sentiment string `json:"sentiment"`
	Message   string `json:"message"`
}

// DB wraps the DynamoDB client and the fixed "unicorn" table name.
type DB struct {
	client *dynamodb.Client
	table  string
}

// NewDB builds a DynamoDB client. cfg.DynamoEndpoint, when set, overrides
// the endpoint URL - a local-development convenience for DynamoDB Local,
// not something a real competition deployment would set.
func NewDB(ctx context.Context, cfg *Config) (*DB, error) {
	opts := []func(*awsconfig.LoadOptions) error{}
	if cfg.Region != "" {
		opts = append(opts, awsconfig.WithRegion(cfg.Region))
	}
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("loading AWS config: %w", err)
	}

	client := dynamodb.NewFromConfig(awsCfg, func(o *dynamodb.Options) {
		if cfg.DynamoEndpoint != "" {
			o.BaseEndpoint = aws.String(cfg.DynamoEndpoint)
		}
	})

	return &DB{client: client, table: cfg.Table}, nil
}

// QueryByID returns every item in the unicorn table for the given
// partition key. The sort key (sentiment) is not filtered on, so a
// message that was reprocessed (unlikely, but not disallowed) would
// return multiple items - callers get the full set and decide.
func (d *DB) QueryByID(ctx context.Context, id string) ([]UnicornRecord, error) {
	out, err := d.client.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(d.table),
		KeyConditionExpression: aws.String("id = :id"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":id": &types.AttributeValueMemberS{Value: id},
		},
	})
	if err != nil {
		return nil, fmt.Errorf("querying table %q: %w", d.table, err)
	}

	records := make([]UnicornRecord, 0, len(out.Items))
	for _, item := range out.Items {
		rec := UnicornRecord{}
		if v, ok := item["id"].(*types.AttributeValueMemberS); ok {
			rec.ID = v.Value
		}
		if v, ok := item["sentiment"].(*types.AttributeValueMemberS); ok {
			rec.Sentiment = v.Value
		}
		if v, ok := item["message"].(*types.AttributeValueMemberS); ok {
			rec.Message = v.Value
		}
		records = append(records, rec)
	}
	return records, nil
}
