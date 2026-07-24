package db

import "errors"

type DB struct{}

func New(path string) (*DB, error) {
	if path == "" {
		return nil, errors.New("db path required")
	}
	return &DB{}, nil
}

func (db *DB) Close() error {
	return nil
}
